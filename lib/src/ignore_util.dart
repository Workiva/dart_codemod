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

import 'patch.dart';

/// Pattern that matches ignore comments in Dart code.
///
/// Supports:
/// - `// codemod_ignore` - ignores the next line
/// - `// codemod_ignore: <reason>` - ignores the next line with reason
/// - `/* codemod_ignore */` - ignores the next line
/// - `/* codemod_ignore: <reason> */` - ignores the next line with reason
final RegExp _ignoreCommentPattern = RegExp(
  r'(?:^|\s)(?://|/\*)\s*codemod_ignore(?::\s*([^\n*/]+))?(?:\*/)?',
  multiLine: true,
);

/// Pattern that matches ignore block comments.
///
/// Supports:
/// - `// codemod_ignore_start` ... `// codemod_ignore_end`
/// - `/* codemod_ignore_start */` ... `/* codemod_ignore_end */`
final RegExp _ignoreStartPattern = RegExp(
  r'(?:^|\s)(?://|/\*)\s*codemod_ignore_start(?:\*/)?',
  multiLine: true,
);

final RegExp _ignoreEndPattern = RegExp(
  r'(?:^|\s)(?://|/\*)\s*codemod_ignore_end(?:\*/)?',
  multiLine: true,
);

/// Checks if a patch should be ignored based on ignore comments in the source.
///
/// Returns `true` if the patch should be ignored, `false` otherwise.
bool shouldIgnorePatch(SourcePatch patch, String sourceText) {
  final sourceFile = patch.sourceFile;
  final startLine = patch.startLine;
  final totalLines = sourceFile.lines;

  // Check for ignore comments on the line before the patch
  if (startLine > 0 && startLine - 1 < totalLines) {
    try {
      final prevLineOffset = sourceFile.getOffset(startLine - 1);
      final prevLineEndOffset = startLine < totalLines
          ? sourceFile.getOffset(startLine)
          : sourceFile.length;
      final prevLineText = sourceFile.getText(prevLineOffset, prevLineEndOffset);

      if (_ignoreCommentPattern.hasMatch(prevLineText)) {
        return true;
      }
    } catch (e) {
      // If we can't get the previous line, continue checking
    }
  }

  // Check for ignore comments on the same line as the patch start
  if (startLine < totalLines) {
    try {
      final startLineOffset = sourceFile.getOffset(startLine);
      final startLineEndOffset = startLine + 1 < totalLines
          ? sourceFile.getOffset(startLine + 1)
          : sourceFile.length;
      final startLineText =
          sourceFile.getText(startLineOffset, startLineEndOffset);

      if (_ignoreCommentPattern.hasMatch(startLineText)) {
        return true;
      }
    } catch (e) {
      // If we can't get the line, continue checking
    }
  }

  // Check for ignore blocks
  final patchStartOffset = patch.startOffset;

  // Find the last ignore_start before the patch
  final beforePatch = sourceText.substring(0, patchStartOffset);
  final ignoreStartMatches = _ignoreStartPattern.allMatches(beforePatch);
  if (ignoreStartMatches.isNotEmpty) {
    final lastIgnoreStart = ignoreStartMatches.last;
    // Check if there's an ignore_end after the ignore_start but before the patch
    final afterIgnoreStart = sourceText.substring(lastIgnoreStart.end);
    final firstIgnoreEnd = _ignoreEndPattern.firstMatch(afterIgnoreStart);

    if (firstIgnoreEnd == null || firstIgnoreEnd.start + lastIgnoreStart.end > patchStartOffset) {
      // The patch is within an ignore block
      return true;
    }
  }

  return false;
}

/// Filters out patches that should be ignored based on ignore comments.
///
/// Returns a new list containing only patches that should not be ignored.
List<SourcePatch> filterIgnoredPatches(
  List<SourcePatch> patches,
  String sourceText,
) {
  return patches.where((patch) => !shouldIgnorePatch(patch, sourceText)).toList();
}
