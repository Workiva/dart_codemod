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

import 'package:args/args.dart';
import 'package:codemod_core/codemod_core.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';

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
  bool interactive = true,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
  List<String>? destPaths,
}) =>
    runInteractiveCodemodSequence(
      filePaths,
      [suggestor],
      args: args,
      defaultYes: defaultYes,
      interactive: interactive,
      additionalHelpOutput: additionalHelpOutput,
      changesRequiredOutput: changesRequiredOutput,
      destPaths: destPaths,
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
  bool interactive = true,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
  List<String>? destPaths,
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
        () => _runInteractiveCodemod(
              filePaths,
              suggestors,
              parsedArgs,
              defaultYes: defaultYes,
              interactive: interactive,
              changesRequiredOutput: changesRequiredOutput,
              destPaths: destPaths,
            ));
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

Future<int> _runInteractiveCodemod(
  Iterable<String> filePaths,
  Iterable<Suggestor> suggestors,
  ArgResults parsedArgs, {
  bool interactive = true,
  bool defaultYes = false,
  String? changesRequiredOutput,
  List<String>? destPaths,
}) async {
  if (destPaths != null) {
    assert(
      filePaths.length == destPaths.length,
      'number of destPaths must be equal to the number of filePaths',
    );
  }

  final failOnChanges = (parsedArgs['fail-on-changes'] as bool?) ?? false;
  final stderrAssumeTty = (parsedArgs['stderr-assume-tty'] as bool?) ?? false;
  final verbose = (parsedArgs['verbose'] as bool?) ?? false;
  var yesToAll = (parsedArgs['yes-to-all'] as bool?) ?? false;
  var numChanges = 0;

  // Pipe logs to stderr.
  _configureLogger(verbose, stderrAssumeTty);

  // Warn and exit early if there are no inputs.
  if (filePaths.isEmpty) {
    logger.warning('codemod found no files');
    return ExitCode.success.code;
  }

  // Setup analysis for any suggestors that may need it.
  logger.info('Setting up analysis contexts...');

  final patchGenerator = PatchGenerator(suggestors);
  logger.info('done');

  final skippedPatches = <Patch>[];
  stdout.writeln('searching...');

  var patchStream = patchGenerator.apply(filePaths, destPaths);

  await for (final changeSet in patchStream) {
    final appliedPatches = <Patch>[];
    try {
      for (var patch in changeSet.patches) {
        if (failOnChanges) {
          // In this mode, we only count the number of changes that would have
          // been suggested instead of actually suggesting them.
          numChanges++;
          continue;
        }

        var choice = acceptPatch(patch, defaultYes, yesToAll, interactive);

        if (choice == Choice.yesToAll) {
          yesToAll = true;
          choice = Choice.yes;
        }
        if (choice == Choice.yes) {
          logger.fine('patch accepted: $patch');
          appliedPatches.add(patch);
        }
        if (choice == Choice.quit) {
          logger.fine('applying patches');
          var userSkipped = promptToHandleOverlappingPatches(appliedPatches);
          // Store patch(es) to print info about skipped patches after codemodding.
          skippedPatches.addAll(userSkipped);

          // Don't apply the patches the user skipped.
          for (var patch in userSkipped) {
            appliedPatches.remove(patch);
            logger.fine('skipping patch ${patch}');
          }

          applyPatchesAndSave(changeSet.context.sourceFile, appliedPatches);
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
      if (interactive) {
        logger.fine('applying patches');

        var userSkipped = promptToHandleOverlappingPatches(appliedPatches);
        // Store patch(es) to print info about skipped patches after codemodding.
        skippedPatches.addAll(userSkipped);

        // Don't apply the patches the user skipped.
        for (var patch in userSkipped) {
          appliedPatches.remove(patch);
          logger.fine('skipping patch ${patch}');
        }
      }

      applyPatchesAndSave(
        changeSet.context.sourceFile,
        appliedPatches,
        changeSet.context.destPath,
      );
    }
  }
  logger.fine('done');

  return _showChanges(
      interactive: interactive,
      failOnChanges: failOnChanges,
      numChanges: numChanges,
      skippedPatches: skippedPatches,
      changesRequiredOutput: changesRequiredOutput);
}

void _configureLogger(bool verbose, bool stderrAssumeTty) {
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen(logListener(
    stderr,
    ansiOutputEnabled: stderr.supportsAnsiEscapes || stderrAssumeTty == true,
    verbose: verbose,
  ));
}

int _showChanges(
    {required bool interactive,
    required bool failOnChanges,
    required int numChanges,
    required List<Patch> skippedPatches,
    required String? changesRequiredOutput}) {
  if (interactive) {
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
  }
  return ExitCode.success.code;
}

enum Choice {
  yes,
  no,
  yesToAll,
  quit;

  static Choice fromString(String response) {
    switch (response) {
      case 'y':
        return Choice.yes;
      case 'A':
        return Choice.yesToAll;
      case 'n':
        return Choice.no;

      case 'q':
        return Choice.quit;
      default:
        throw InputException(
            'Unexpected response provided: expected one of yAnq');
    }
  }
}

Choice acceptPatch(
    SourcePatch patch, bool defaultYes, bool yesToAll, bool interactive) {
  if (!interactive) {
    return Choice.yes;
  }

  final defaultChoice = defaultYes ? 'y' : 'n';

  _showPatch(patch);

  var choice = Choice.no;
  if (!yesToAll) {
    if (defaultYes) {
      stdout.writeln('Accept change (y = yes [default], n = no, '
          'A = yes to all, q = quit)? ');
    } else {
      stdout.writeln('Accept change (y = yes, n = no [default], '
          'A = yes to all, q = quit)? ');
    }

    final response = prompt('ynAq', defaultChoice);
    choice = Choice.fromString(response);
  } else {
    logger.fine('skipped prompt because yesToAll==true');
    choice = Choice.yes;
  }
  return choice;
}

void _showPatch(SourcePatch patch) {
  stdout.write(terminalClear());
  stdout.write(patch.renderRange());
  stdout.writeln();

  final diffSize = calculateDiffSize(stdout);
  logger.fine('diff size: $diffSize');
  stdout.write(patch.renderDiff(diffSize));
  stdout.writeln();
}
