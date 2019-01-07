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

///
void runInteractiveCodemod(
  FileQuery query,
  Suggestor suggestor, {
  Iterable<String> args,
}) {
  runInteractiveCodemodSequence(query, [suggestor], args: args);
}

void runInteractiveCodemodSequence(
  FileQuery query,
  Iterable<Suggestor> suggestors, {
  Iterable<String> args,
}) {
  try {
    // TODO: instead of overriding, add --assume-tty flag and recommend its usage when debugging with a stderr redirect
    exitCode = overrideAnsiOutput<int>(stdout.supportsAnsiEscapes,
        () => _runInteractiveCodemod(query, suggestors, args: args));
  } catch (error, stackTrace) {
    logger.severe('Uncaught exception.', error, stackTrace);
    exitCode = ExitCode.software.code;
    return;
  }
}

int _runInteractiveCodemod(FileQuery query, Iterable<Suggestor> suggestors,
    {Iterable<String> args}) {
  // TODO: parse args
  final defaultNo = true;
  final verbose = false;

  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen(stderrLogListener(verbose: verbose));

  if (!query.targetExists) {
    logger.severe('codemod target does not exist: ${query.target}');
    return ExitCode.noInput.code;
  }

  // Will be set to true if the user selects the "A = yes to all" option.
  var yesToAll = false;

  for (final suggestor in suggestors) {
    for (final filePath in query.generateFilePaths()) {
      logger.info('file: $filePath');
      String sourceText;
      try {
        sourceText = File(filePath).readAsStringSync();
      } catch (e) {
        // TODO
        continue;
      }

      final sourceFile =
          new SourceFile.fromString(sourceText, url: Uri.file(filePath));
      logger.info('searching');
      final appliedPatches = <Patch>[];
      for (final patch in suggestor.generatePatches(sourceFile)) {
        if (patch.isNoop) {
          // Patch suggested, but without any changes. This is probably an error.
          logger.severe('Empty patch suggested: $patch');
          return ExitCode.software.code;
        }

        clearTerminal();
        stdout.write(patch.renderRange());
        stdout.writeln();

        final diffSize = stdout.hasTerminal ? stdout.terminalLines - 20 : 5;
        stdout.write(patch.renderDiff(diffSize));
        stdout.writeln();

        final defaultChoice = defaultNo ? 'n' : 'y';
        String choice;
        if (!yesToAll) {
          if (defaultNo) {
            stdout.writeln('Accept change (y = yes, n = no [default], '
                'A = yes to all, q = quit)? ');
          } else {
            stdout.writeln('Accept change (y = yes [default], n = no, '
                'A = yes to all, q = quit)? ');
          }

          choice = prompt('ynAq', defaultChoice);
        } else {
          choice = 'y';
        }

        if (choice == 'A') {
          yesToAll = true;
          choice = 'y';
        }
        if (choice == 'y') {
          appliedPatches.add(patch);
        }
        if (choice == 'q') {
          applyPatchesAndSave(sourceFile, appliedPatches);
          return ExitCode.success.code;
        }
      }
      applyPatchesAndSave(sourceFile, appliedPatches);
    }
  }
  return ExitCode.success.code;
}
