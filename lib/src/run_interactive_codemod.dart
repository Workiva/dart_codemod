import 'dart:io';

import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:source_span/source_span.dart';

import 'file_query.dart';
import 'logging.dart';
import 'patch.dart';
import 'suggestors.dart';
import 'util.dart';

/// Interactively runs a "codemod" by using `stdout` to display a diff for each
/// potential patch and `stdin` to accept input from the user on what to do with
/// said patch; returns an appropriate exit code when complete.
///
/// [query] will generate the set of file paths that will then be read and used
/// to generate potential patches.
///
/// [suggestor] will generate patches for each file that will be shown to the
/// user in turn to be accepted or skipped.
///
/// If [defaultYes] is true, then the default option for each patch prompt will
/// be yes (meaning that just hitting "enter" will accept the patch).
/// Otherwise, the default action is no (meaning that just hitting "enter" will
/// skip the patch).
///
/// Additional CLI args are accepted via [args] to make it easy to configure
/// certain options at runtime:
///     -h, --help                 Prints this help output.
///     -v, --verbose              Outputs all logging to stdout/stderr.
///         --yes-to-all           Forces all patches accepted without prompting the user. Useful for scripts.
///         --stderr-assume-tty    Forces ansi color highlighting of stderr. Useful for debugging.
///
/// To run a codemod from the command line, setup a `.dart` file with a `main`
/// block like so:
///     import 'dart:io';
///     import 'package:codemod/codemod.dart';
///
///     void main(List<String> args) {
///       exitCode = runInteractiveCodemod(
///         FileQuery.dir(...),
///         ExampleSuggestor(),
///         args: args,
///       );
///     }
///
/// For debugging purposes, logs will be written to stderr. By default, only
/// severe logs are reported. If verbose mode is enabled, all logs will be
/// reported. It's recommended that if you need to see these logs while running
/// a codemod for debugging purposes that you redirect stderr to a file and
/// monitor it using `tail -f`, otherwise the logs may be overwritten and lost
/// every time this function clears the terminal to render a patch diff.
///     $ touch stderr.txt && tail -f stderr.txt
///     $ dart example_codemod.dart --verbose 2>stderr.txt
///
/// Additionally, you can retain ansi color highlighting of these logs when
/// redirecting to a file by passing the `--stderr-assume-tty` flag:
///     $ dart example_codemod.dart --verbose --stderr-assume-tty 2>stderr.txt
int runInteractiveCodemod(
  FileQuery query,
  Suggestor suggestor, {
  Iterable<String> args,
  bool defaultYes = false,
}) =>
    runInteractiveCodemodSequence(
      query,
      [suggestor],
      args: args,
      defaultYes: defaultYes,
    );

/// Exactly the same as [runInteractiveCodemod] except that it runs all of the
/// given [suggestors] sequentially (meaning that the set of files found by
/// [query] is iterated over for each suggestor).
///
/// This can be useful if a certain modification needs to happen prior to
/// another, or if you need to use a "collector" pattern wherein the first
/// suggestor collects information from the files that a second suggestor will
/// then use to suggest patches.
///
/// If your suggestors don't need to be applied in a particular order, consider
/// combining them into a single "aggregate" suggestor and using
/// [runInteractiveCodemod] instead:
///     final query = ...;
///     runInteractiveCodemod(
///       query,
///       AggregateSuggestor([SuggestorA(), SuggestorB()]),
///     );
int runInteractiveCodemodSequence(
  FileQuery query,
  Iterable<Suggestor> suggestors, {
  Iterable<String> args,
  bool defaultYes = false,
}) {
  try {
    ArgResults parsedArgs;
    try {
      parsedArgs = codemodArgParser.parse(args);
    } on ArgParserException catch (e) {
      stderr
        ..writeln('Invalid codemod arguments: ${e.message}')
        ..writeln()
        ..writeln(codemodArgParser.usage);
      return ExitCode.usage.code;
    }

    if (parsedArgs['help'] == true) {
      stderr.writeln(codemodArgParser.usage);
      return ExitCode.success.code;
    }

    return overrideAnsiOutput<int>(
        stdout.supportsAnsiEscapes,
        () => _runInteractiveCodemod(query, suggestors, parsedArgs,
            defaultYes: defaultYes));
  } catch (error, stackTrace) {
    stderr..writeln('Uncaught exception:')..writeln(error)..writeln(stackTrace);
    return ExitCode.software.code;
  }
}

final codemodArgParser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Prints this help output.',
  )
  ..addFlag(
    'verbose',
    abbr: 'v',
    negatable: false,
    help: 'Outputs all logging to stdout/stderr.',
  )
  ..addFlag(
    'yes-to-all',
    negatable: false,
    help: 'Forces all patches accepted without prompting the user. '
        'Useful for scripts.',
  )
  ..addFlag(
    'stderr-assume-tty',
    negatable: false,
    help: 'Forces ansi color highlighting of stderr. Useful for debugging.',
  );

int _runInteractiveCodemod(
    FileQuery query, Iterable<Suggestor> suggestors, ArgResults parsedArgs,
    {bool defaultYes}) {
  // Pipe logs to stderr.
  final verbose = parsedArgs['verbose'];
  final stderrAssumeTty = parsedArgs['stderr-assume-tty'];
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen(logListener(
    stderr,
    ansiOutputEnabled: stderr.supportsAnsiEscapes || stderrAssumeTty == true,
    verbose: verbose,
  ));

  // Fail early if the target of the file query does not exist.
  if (!query.targetExists) {
    logger.severe('codemod target does not exist: ${query.target}');
    return ExitCode.noInput.code;
  }

  defaultYes ??= false;
  // Will be set to true if the user selects the "A = yes to all" option.
  var yesToAll = parsedArgs['yes-to-all'] ?? false;

  stdout.writeln('searching...');
  for (final suggestor in suggestors) {
    for (final filePath in query.generateFilePaths()) {
      logger.fine('file: $filePath');
      String sourceText;
      try {
        sourceText = File(filePath).readAsStringSync();
      } catch (e, stackTrace) {
        logger.severe('Failed to read file: $filePath', e, stackTrace);
        return ExitCode.noInput.code;
      }

      bool shouldSkip;
      try {
        shouldSkip = suggestor.shouldSkip(sourceText);
      } catch (e, stackTrace) {
        logger.severe(
            'Suggestor.shouldSkip() threw unexpectedly.', e, stackTrace);
        return ExitCode.software.code;
      }
      if (shouldSkip == true) {
        logger.fine('skipped');
        continue;
      }

      final sourceFile =
          new SourceFile.fromString(sourceText, url: Uri.file(filePath));
      final appliedPatches = <Patch>[];

      try {
        for (final patch in suggestor.generatePatches(sourceFile)) {
          if (patch.isNoop) {
            // Patch suggested, but without any changes. This is probably an error.
            logger.severe('Empty patch suggested: $patch');
            return ExitCode.software.code;
          }

          stdout.write(terminalClear());
          stdout.write(patch.renderRange());
          stdout.writeln();

          final diffSize = calculateDiffSize(stdout);
          logger.fine('diff size: $diffSize');
          stdout.write(patch.renderDiff(diffSize));
          stdout.writeln();

          final defaultChoice = defaultYes ? 'y' : 'n';
          String choice;
          if (!yesToAll) {
            if (defaultYes) {
              stdout.writeln('Accept change (y = yes [default], n = no, '
                  'A = yes to all, q = quit)? ');
            } else {
              stdout.writeln('Accept change (y = yes, n = no [default], '
                  'A = yes to all, q = quit)? ');
            }

            choice = prompt('ynAq', defaultChoice);
          } else {
            logger.fine('skipped prompt because yesToAll==true');
            choice = 'y';
          }

          if (choice == 'A') {
            yesToAll = true;
            choice = 'y';
          }
          if (choice == 'y') {
            logger.fine('patch accepted: $patch');
            appliedPatches.add(patch);
          }
          if (choice == 'q') {
            logger.fine('applying patches');
            applyPatchesAndSave(sourceFile, appliedPatches);
            logger.fine('quitting');
            return ExitCode.success.code;
          }
        }
      } catch (e, stackTrace) {
        logger.severe(
            'Suggestor.generatePatches() threw unexpectedly.', e, stackTrace);
        return ExitCode.software.code;
      }
      logger.fine('applying patches');
      applyPatchesAndSave(sourceFile, appliedPatches);
    }
  }
  logger.fine('done');
  return ExitCode.success.code;
}
