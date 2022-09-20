// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'patch.dart';
import 'util.dart';

/// Interactively runs a "codemod" by using `stdout` to display a diff for each
/// potential patch and `stdin` to accept input from the user on what to do with
/// said patch; returns an appropriate exit code when complete.
///
/// [suggestor] will generate patches for each file in [files]. Each patch will
/// be shown to the user to be accepted or skipped.
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
///
///     import 'package:codemod/codemod.dart';
///
///     void main(List<String> args) {
///       exitCode = runInteractiveCodemod(
///         [...], // input files,
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
Future<int> runInteractiveCodemod(
  Iterable<String> filePaths,
  Suggestor suggestor, {
  Iterable<String> args = const [],
  bool defaultYes = false,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
}) =>
    runInteractiveCodemodSequence(
      filePaths,
      [suggestor],
      args: args,
      defaultYes: defaultYes,
      additionalHelpOutput: additionalHelpOutput,
      changesRequiredOutput: changesRequiredOutput,
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
Future<int> runInteractiveCodemodSequence(
  Iterable<String> filePaths,
  Iterable<Suggestor> suggestors, {
  Iterable<String> args = const [],
  bool defaultYes = false,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
}) async {
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
      stderr.writeln('Global codemod options:');
      stderr.writeln();
      stderr.writeln(codemodArgParser.usage);

      additionalHelpOutput ??= '';
      if (additionalHelpOutput.isNotEmpty) {
        stderr.writeln();
        stderr.writeln('Additional options for this codemod:');
        stderr.writeln(additionalHelpOutput);
      }
      return ExitCode.success.code;
    }
    return overrideAnsiOutput<Future<int>>(
        stdout.supportsAnsiEscapes,
        () => _runInteractiveCodemod(filePaths, suggestors, parsedArgs,
            defaultYes: defaultYes,
            changesRequiredOutput: changesRequiredOutput));
  } catch (error, stackTrace) {
    stderr
      ..writeln('Uncaught exception:')
      ..writeln(error)
      ..writeln(stackTrace);
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
    'fail-on-changes',
    negatable: false,
    help: 'Returns a non-zero exit code if there are changes to be made. '
        'Will not make any changes (i.e. this is a dry-run).',
  )
  ..addFlag(
    'stderr-assume-tty',
    negatable: false,
    help: 'Forces ansi color highlighting of stderr. Useful for debugging.',
  );

Future<int> _runInteractiveCodemod(Iterable<String> filePaths,
    Iterable<Suggestor> suggestors, ArgResults parsedArgs,
    {bool? defaultYes, String? changesRequiredOutput}) async {
  final failOnChanges = (parsedArgs['fail-on-changes'] as bool?) ?? false;
  final stderrAssumeTty = (parsedArgs['stderr-assume-tty'] as bool?) ?? false;
  final verbose = (parsedArgs['verbose'] as bool?) ?? false;
  var yesToAll = (parsedArgs['yes-to-all'] as bool?) ?? false;
  defaultYes ??= false;
  var numChanges = 0;

  // Pipe logs to stderr.
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen(logListener(
    stderr,
    ansiOutputEnabled: stderr.supportsAnsiEscapes || stderrAssumeTty == true,
    verbose: verbose,
  ));

  // Warn and exit early if there are no inputs.
  if (filePaths.isEmpty) {
    logger.warning('codemod found no files');
    return ExitCode.success.code;
  }

  // Setup analysis for any suggestors that may need it.
  logger.info('Setting up analysis contexts...');
  final canonicalizedPaths =
      filePaths.map((path) => p.canonicalize(path)).toList();
  final collection =
      AnalysisContextCollection(includedPaths: canonicalizedPaths);
  final fileContexts =
      canonicalizedPaths.map((path) => FileContext(path, collection));
  logger.info('done');

  final skippedPatches = <Patch>[];
  stdout.writeln('searching...');

  for (final suggestor in suggestors) {
    for (final context in fileContexts) {
      logger.fine('file: ${context.relativePath}');
      final appliedPatches = <Patch>[];
      try {
        final patches = await suggestor(context)
            .map((p) => SourcePatch.from(p, context.sourceFile))
            .toList();
        for (final patch in patches) {
          if (patch.isNoop) {
            // Patch suggested, but without any changes. This is probably an
            // error in the suggestor implementation.
            logger.severe('Empty patch suggested: $patch');
            return ExitCode.software.code;
          }

          if (failOnChanges) {
            // In this mode, we only count the number of changes that would have
            // been suggested instead of actually suggesting them.
            numChanges++;
            continue;
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
            var userSkipped = promptToHandleOverlappingPatches(appliedPatches);
            // Store patch(es) to print info about skipped patches after codemodding.
            skippedPatches.addAll(userSkipped);

            // Don't apply the patches the user skipped.
            for (var patch in userSkipped) {
              appliedPatches.remove(patch);
              logger.fine('skipping patch ${patch}');
            }

            applyPatchesAndSave(context.sourceFile, appliedPatches);
            logger.fine('quitting');
            return ExitCode.success.code;
          }
        }
      } catch (e, stackTrace) {
        logger.severe(
            'Suggestor.generatePatches() threw unexpectedly.', e, stackTrace);
        return ExitCode.software.code;
      }

      if (!failOnChanges) {
        logger.fine('applying patches');

        var userSkipped = promptToHandleOverlappingPatches(appliedPatches);
        // Store patch(es) to print info about skipped patches after codemodding.
        skippedPatches.addAll(userSkipped);

        // Don't apply the patches the user skipped.
        for (var patch in userSkipped) {
          appliedPatches.remove(patch);
          logger.fine('skipping patch ${patch}');
        }

        applyPatchesAndSave(context.sourceFile, appliedPatches);
      }
    }
  }
  logger.fine('done');

  for (var patch in skippedPatches) {
    stdout.writeln(
        'NOTE: Overlapping patch was skipped. May require manual modification.');
    stdout.writeln('      ${patch.toString()}');
    stdout.writeln('      Updated text:');
    stdout.writeln('      ${patch.updatedText}');
    stdout.writeln('');
  }

  if (failOnChanges) {
    if (numChanges > 0) {
      stderr.writeln('$numChanges change(s) needed.');

      changesRequiredOutput ??= '';
      if (changesRequiredOutput.isNotEmpty) {
        stderr.writeln();
        stderr.writeln(changesRequiredOutput);
      }
      return 1;
    }
    stdout.writeln('No changes needed.');
  }

  return ExitCode.success.code;
}
