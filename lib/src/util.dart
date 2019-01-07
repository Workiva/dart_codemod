import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;
import 'package:source_span/source_span.dart';

import 'constants.dart';
import 'logging.dart';
import 'patch.dart';

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

void applyPatchesAndSave(SourceFile sourceFile, Iterable<Patch> patches) {
  if (patches.isEmpty) {
    logger.fine('no patches to apply');
    return;
  }
  logger.fine('applying patches and writing to disk');
  final updatedContents = applyPatches(sourceFile, patches);
  File(sourceFile.url.path).writeAsStringSync(updatedContents);
}

void clearTerminal() {
  stdout
      .write(ansiOutputEnabled ? '$ansiClearScreen$ansiCursorHome' : '\n' * 8);
}

bool Function(String path) createPathFilter(Iterable<String> extensions,
    {Iterable<String> excludePaths}) {
  return (filePath) {
    if (!extensions.any((extension) => extension == path.extension(filePath))) {
      return false;
    }
    // TODO: implement excluded path filtering with support for globs
    return true;
  };
}

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
