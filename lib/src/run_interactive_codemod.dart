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

import 'dart:async';
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
import 'terminal_output.dart';
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
}) => runInteractiveCodemodSequence(
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
      final terminal = TerminalOutput(
        ansiEnabled: stderr.supportsAnsiEscapes,
        stdout: stdout,
        stderr: stderr,
      );
      terminal.error('Invalid arguments: ${e.message}');
      stdout.writeln('');
      terminal.section('Usage');
      stdout.writeln(codemodArgParser.usage);
      return ExitCode.usage.code;
    }

    if (parsedArgs['help'] == true) {
      final terminal = TerminalOutput(
        ansiEnabled: stdout.supportsAnsiEscapes,
        stdout: stdout,
        stderr: stderr,
      );
      if (stdout.supportsAnsiEscapes) {
        stdout.writeln('');
        stdout.writeln(
          '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
        );
        stdout.writeln('${cyan.wrap('📖')} ${styleBold.wrap('Codemod Help')}');
        stdout.writeln(
          '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
        );
        stdout.writeln('');
      } else {
        stdout.writeln('');
        stdout.writeln(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
        stdout.writeln('📖 Codemod Help');
        stdout.writeln(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
        stdout.writeln('');
      }
      terminal.section('Global Codemod Options');
      stdout.writeln(codemodArgParser.usage);

      additionalHelpOutput ??= '';
      if (additionalHelpOutput.isNotEmpty) {
        stdout.writeln('');
        terminal.section('Additional Options');
        stdout.writeln(additionalHelpOutput);
      }
      if (stdout.supportsAnsiEscapes) {
        stdout.writeln('');
        stdout.writeln(
          '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
        );
      } else {
        stdout.writeln('');
        stdout.writeln(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
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
        changesRequiredOutput: changesRequiredOutput,
      ),
    );
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
    help:
        'Forces all patches accepted without prompting the user. '
        'Useful for scripts.',
  )
  ..addFlag(
    'fail-on-changes',
    negatable: false,
    help:
        'Returns a non-zero exit code if there are changes to be made. '
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
  bool? defaultYes,
  String? changesRequiredOutput,
}) async {
  final failOnChanges = (parsedArgs['fail-on-changes'] as bool?) ?? false;
  final stderrAssumeTty = (parsedArgs['stderr-assume-tty'] as bool?) ?? false;
  final verbose = (parsedArgs['verbose'] as bool?) ?? false;
  var yesToAll = (parsedArgs['yes-to-all'] as bool?) ?? false;
  defaultYes ??= false;
  var numChanges = 0;

  // Pipe logs to stderr.
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  StreamSubscription<LogRecord>? logSubscription;
  try {
    logSubscription = Logger.root.onRecord.listen(
      logListener(
        stderr,
        ansiOutputEnabled:
            stderr.supportsAnsiEscapes || stderrAssumeTty == true,
        verbose: verbose,
      ),
    );

    final terminal = TerminalOutput(
      ansiEnabled: stdout.supportsAnsiEscapes,
      stdout: stdout,
      stderr: stderr,
    );

    // Warn and exit early if there are no inputs.
    if (filePaths.isEmpty) {
      terminal.warning('No files found to process');
      return ExitCode.success.code;
    }

    // Setup analysis for any suggestors that may need it.
    terminal.progress('Setting up analysis contexts');
    final canonicalizedPaths = filePaths
        .map((path) => p.canonicalize(path))
        .toList();
    final collection = AnalysisContextCollection(
      includedPaths: canonicalizedPaths,
    );
    final fileContexts = canonicalizedPaths.map(
      (path) => FileContext(path, collection),
    );
    terminal.clearProgress();
    terminal.success(
      'Analysis contexts ready (${canonicalizedPaths.length} file${canonicalizedPaths.length == 1 ? '' : 's'})',
    );

    final skippedPatches = <Patch>[];
    final stats = CodemodStats();
    stats.startTime = DateTime.now();
    terminal.info('Searching for changes...');

    for (final suggestor in suggestors) {
      for (final context in fileContexts) {
        logger.fine('file: ${context.relativePath}');
        stats.filesProcessed++;
        final appliedPatches = <Patch>[];
        try {
          final patches = await suggestor(
            context,
          ).map((p) => SourcePatch.from(p, context.sourceFile)).toList();

          stats.patchesSuggested += patches.length;

          // Filter out patches that should be ignored
          final filteredPatches = filterIgnoredPatches(
            patches,
            context.sourceText,
          );
          stats.patchesIgnored += patches.length - filteredPatches.length;

          for (final patch in filteredPatches) {
            if (patch.isNoop) {
              // Patch suggested, but without any changes. This is probably an
              // error in the suggestor implementation.
              terminal.error('Empty patch suggested: $patch');
              terminal.error(
                'This is likely a bug in the suggestor implementation.',
              );
              return ExitCode.software.code;
            }

            if (failOnChanges) {
              // In this mode, we only count the number of changes that would have
              // been suggested instead of actually suggesting them.
              numChanges++;
              continue;
            }

            stdout.write(terminalClear());

            // Display file location with formatting
            if (stdout.supportsAnsiEscapes) {
              stdout.writeln('');
              stdout.writeln(
                '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
              );
              stdout.writeln(
                '${cyan.wrap('📄')} ${styleBold.wrap(patch.renderRange())}',
              );
              stdout.writeln(
                '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
              );
              stdout.writeln('');
            } else {
              stdout.writeln('');
              stdout.writeln(
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
              );
              stdout.writeln('📄 ${patch.renderRange()}');
              stdout.writeln(
                '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
              );
              stdout.writeln('');
            }

            final diffSize = calculateDiffSize(stdout);
            logger.fine('diff size: $diffSize');
            stdout.write(
              patch.renderDiff(
                diffSize,
                ansiEnabled: stdout.supportsAnsiEscapes,
              ),
            );
            stdout.writeln();

            final defaultChoice = defaultYes ? 'y' : 'n';
            String choice;
            if (!yesToAll) {
              stdout.writeln('');
              if (stdout.supportsAnsiEscapes) {
                stdout.writeln(
                  '${styleDim.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
                );
              } else {
                stdout.writeln(
                  '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
                );
              }
              stdout.writeln('');
              if (defaultYes) {
                terminal.prompt('Accept this change?', defaultChoice: 'y');
                if (stdout.supportsAnsiEscapes) {
                  stdout.writeln('');
                  stdout.writeln('  ${styleDim.wrap('Options:')}');
                  stdout.writeln(
                    '    ${green.wrap('y')} ${styleDim.wrap('= yes')} ${styleBold.wrap('[default]')}',
                  );
                  stdout.writeln(
                    '    ${red.wrap('n')} ${styleDim.wrap('= no')}',
                  );
                  stdout.writeln(
                    '    ${cyan.wrap('A')} ${styleDim.wrap('= yes to all')}',
                  );
                  stdout.writeln(
                    '    ${yellow.wrap('q')} ${styleDim.wrap('= quit')}',
                  );
                } else {
                  stdout.writeln('  (y)es [default]  (n)o  (A)ll  (q)uit');
                }
              } else {
                terminal.prompt('Accept this change?', defaultChoice: 'n');
                if (stdout.supportsAnsiEscapes) {
                  stdout.writeln('');
                  stdout.writeln('  ${styleDim.wrap('Options:')}');
                  stdout.writeln(
                    '    ${green.wrap('y')} ${styleDim.wrap('= yes')}',
                  );
                  stdout.writeln(
                    '    ${red.wrap('n')} ${styleDim.wrap('= no')} ${styleBold.wrap('[default]')}',
                  );
                  stdout.writeln(
                    '    ${cyan.wrap('A')} ${styleDim.wrap('= yes to all')}',
                  );
                  stdout.writeln(
                    '    ${yellow.wrap('q')} ${styleDim.wrap('= quit')}',
                  );
                } else {
                  stdout.writeln('  (y)es  (n)o [default]  (A)ll  (q)uit');
                }
              }
              stdout.writeln('');

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
              stats.patchesApplied++;
              if (stdout.supportsAnsiEscapes) {
                stdout.writeln('');
                terminal.success('✓ Change accepted');
                stdout.writeln('');
              }
            } else {
              stats.patchesSkipped++;
              if (stdout.supportsAnsiEscapes) {
                stdout.writeln('');
                stdout.writeln('${styleDim.wrap('⊘ Change skipped')}');
                stdout.writeln('');
              }
            }
            if (choice == 'q') {
              logger.fine('applying patches');
              var userSkipped = promptToHandleOverlappingPatches(
                appliedPatches,
              );
              // Store patch(es) to print info about skipped patches after codemodding.
              skippedPatches.addAll(userSkipped);

              // Don't apply the patches the user skipped.
              for (var patch in userSkipped) {
                appliedPatches.remove(patch);
                logger.fine('skipping patch $patch');
              }

              applyPatchesAndSave(context.sourceFile, appliedPatches);
              logger.fine('quitting');
              return ExitCode.success.code;
            }
          }

          if (!failOnChanges) {
            logger.fine('applying patches');

            var userSkipped = promptToHandleOverlappingPatches(appliedPatches);
            // Store patch(es) to print info about skipped patches after codemodding.
            skippedPatches.addAll(userSkipped);

            // Don't apply the patches the user skipped.
            for (var patch in userSkipped) {
              appliedPatches.remove(patch);
              logger.fine('skipping patch $patch');
            }

            if (appliedPatches.isNotEmpty) {
              applyPatchesAndSave(context.sourceFile, appliedPatches);
              stats.filesModified++;
            }
          }
        } catch (e, stackTrace) {
          stats.errors++;
          terminal.error('Error processing file: ${context.relativePath}');
          logger.severe(
            'Error processing file ${context.relativePath}: $e',
            e,
            stackTrace,
          );
          // Continue with next file instead of failing completely
        }
      }
    }
    stats.endTime = DateTime.now();
    logger.fine('done');

    // Display summary
    stdout.writeln('');
    stdout.writeln('');
    if (stdout.supportsAnsiEscapes) {
      stdout.writeln(
        '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
      );
    } else {
      stdout.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      );
    }
    terminal.section('Summary');

    terminal.keyValue(
      'Files processed',
      '${stats.filesProcessed}',
      highlightValue: true,
    );
    terminal.keyValue(
      'Files modified',
      '${stats.filesModified}',
      highlightValue: true,
    );
    terminal.keyValue('Patches suggested', '${stats.patchesSuggested}');
    terminal.keyValue(
      'Patches applied',
      '${stats.patchesApplied}',
      highlightValue: true,
    );
    terminal.keyValue('Patches skipped', '${stats.patchesSkipped}');
    if (stats.patchesIgnored > 0) {
      terminal.keyValue('Patches ignored', '${stats.patchesIgnored}');
    }
    if (stats.errors > 0) {
      terminal.keyValue('Errors', '${stats.errors}', highlightValue: true);
    }
    if (stats.duration != null) {
      final duration = stats.duration!;
      final durationStr = duration.inSeconds < 60
          ? '${duration.inSeconds}s'
          : '${duration.inMinutes}m ${duration.inSeconds % 60}s';
      terminal.keyValue('Duration', durationStr);
    }
    if (stdout.supportsAnsiEscapes) {
      stdout.writeln('');
      stdout.writeln(
        '${cyan.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
      );
    } else {
      stdout.writeln('');
      stdout.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      );
    }

    if (verbose) {
      stdout.writeln('');
      terminal.section('Detailed Statistics');
      stdout.writeln(stats.getSummary());
    }

    if (skippedPatches.isNotEmpty) {
      stdout.writeln('');
      terminal.note(
        'Overlapping patches were skipped and may require manual modification:',
      );
      for (var patch in skippedPatches) {
        terminal.listItem(patch.toString(), isError: false);
        terminal.helpText('Updated text: ${patch.updatedText}');
      }
    }

    if (failOnChanges) {
      if (numChanges > 0) {
        stdout.writeln('');
        if (stdout.supportsAnsiEscapes) {
          stdout.writeln(
            '${red.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
          );
        } else {
          stdout.writeln(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );
        }
        terminal.error('$numChanges change(s) needed.');

        changesRequiredOutput ??= '';
        if (changesRequiredOutput.isNotEmpty) {
          stdout.writeln('');
          terminal.info(changesRequiredOutput);
        }
        if (stdout.supportsAnsiEscapes) {
          stdout.writeln(
            '${red.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
          );
        } else {
          stdout.writeln(
            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
          );
        }
        return 1;
      }
      stdout.writeln('');
      terminal.success('✓ No changes needed.');
    }

    if (stats.errors > 0) {
      stdout.writeln('');
      if (stdout.supportsAnsiEscapes) {
        stdout.writeln(
          '${yellow.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
        );
      } else {
        stdout.writeln(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
      }
      terminal.error('Completed with ${stats.errors} error(s)');
      if (stdout.supportsAnsiEscapes) {
        stdout.writeln(
          '${yellow.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
        );
      } else {
        stdout.writeln(
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        );
      }
      return ExitCode.software.code;
    }

    stdout.writeln('');
    if (stdout.supportsAnsiEscapes) {
      stdout.writeln(
        '${green.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
      );
    } else {
      stdout.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      );
    }
    terminal.success('✓ Codemod completed successfully!');
    if (stdout.supportsAnsiEscapes) {
      stdout.writeln(
        '${green.wrap('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')}',
      );
    } else {
      stdout.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      );
    }
    return ExitCode.success.code;
  } finally {
    // Cancel subscription to prevent memory leak
    await logSubscription?.cancel();
  }
}
