import 'dart:math' as math;
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;
import 'package:source_span/source_span.dart';

import 'constants.dart';
import 'file_query.dart';
import 'patch.dart';

/// Returns the result of applying all of the [patches]
/// (insertions/deletions/replacements) to the contents of [sourceFile].
///
/// Throws an [Exception] if any two of the given [patches] overlap.
String applyPatches(SourceFile sourceFile, Iterable<Patch> patches) {
  final buffer = StringBuffer();
  final sortedPatches = patches.toList()..sort();

  var lastEdgeOffset = 0;
  for (final patch in sortedPatches) {
    if (patch.startOffset < lastEdgeOffset) {
      throw new Exception('Overlapping patch is not allowed.');
    }

    // Write unmodified text from end of last patch to beginning of this patch
    buffer.write(sourceFile.getText(lastEdgeOffset, patch.startOffset));
    // Write the patched text (and do nothing with the original text, which is
    // effectively the same as replacing it)
    buffer.write(patch.updatedText);

    lastEdgeOffset = patch.endOffset;
  }

  final lastUnmodifiedText = sourceFile.getText(lastEdgeOffset);
  if (lastUnmodifiedText != null) {
    buffer.write(lastUnmodifiedText);
  }

  return buffer.toString();
}

/// Applies all of the [patches] (insertions/deletions/replacements) to the
/// contents of [sourceFile] and writes the result to disk.
///
/// Throws an [ArgumentError] if [sourceFile] has a null value for
/// [SourceFile.url], as it is required to open the file and write the new
/// contents.
void applyPatchesAndSave(SourceFile sourceFile, Iterable<Patch> patches) {
  if (patches.isEmpty) {
    return;
  }
  if (sourceFile.url == null) {
    throw new ArgumentError('sourceFile.url cannot be null');
  }
  final updatedContents = applyPatches(sourceFile, patches);
  File(sourceFile.url.path).writeAsStringSync(updatedContents);
}

/// Returns the number of lines that a patch diff should be constrained to.
/// Based on the stdout terminal size if available, or a sane default if not.
int calculateDiffSize(Stdout stdout) {
  return stdout.hasTerminal
      // Try to leave some room at the bottom of the terminal for user prompts.
      ? math.max(10, stdout.terminalLines - 10)
      // Sane default when there is no terminal.
      : 10;
}

/// Returns a path filter function that will return true for any file path with
/// an extension in [extensions], and false otherwise.
///
///     final filter = createPathFilter(['.yaml', '.yml']);
///     filter('./lib/foo.yaml') // true
///     filter('./lib/foo.yml')  // true
///     filter('./lib/foo.dart') // false
bool Function(String path) createPathFilter(Iterable<String> extensions) {
  return (filePath) =>
      extensions.any((extension) => extension == path.extension(filePath));
}

/// Returns true if [filePath] is a Dart file (meaning that its extension is
/// `.dart`), and false otherwise.
///
/// Use this with [FileQuery] to query for Dart files in a directory:
///     FileQuery.dir(
///       path: './lib/',
///       pathFilter: isDartFile
///     );
///     // Will find all `.dart` files in `./lib/`
bool isDartFile(String filePath) => path.extension(filePath) == '.dart';

/// Returns `true` if the given file path looks like it is actual code, and
/// `false` otherwise. Attempts to filter out common/known non-code paths like
/// the dotfile directories.
///
///     pathLooksLikeCode('lib/codemod.dart')
///     // true
///     pathLooksLikeCode('.packages')
///     // False
///     pathLooksLikeCode('.dart_tool/pub/bin/sdk-version')
///     // False
bool pathLooksLikeCode(String filePath) =>
    !filePath.contains('/.') &&
    !(filePath.startsWith('.') && !filePath.startsWith('./'));

/// Prompts the user to select an action via stdin.
///
/// [letters] is the string of valid one-letter responses. In other words, if
/// [letters] is `yn` then the two valid responses are `y` and `n`.
///
/// [defaultChoice] will be returned if non-null and the user returns without
/// entering anything.
String prompt([String letters = 'yn', String defaultChoice]) {
  while (true) {
    final response = stdin.readLineSync();
    if (response.length > 1) {
      stdout.writeln('Come again? (only enter a single character)');
      continue;
    }
    if (response.isNotEmpty && letters.contains(response)) {
      return response;
    }
    if (defaultChoice != null && response.isEmpty) {
      return defaultChoice;
    }
    stdout.writeln('Come again?');
  }
}

/// Returns a character sequence that "clears" the terminal.
///
/// If ansi output is enabled, the ansi escape code for clearing the terminal
/// will be returned. Otherwise, several newlines will be returned to achieve
/// roughly the same effect.
String terminalClear() {
  return ansiOutputEnabled ? '$ansiClearScreen$ansiCursorHome' : '\n' * 8;
}
