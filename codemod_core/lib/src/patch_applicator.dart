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

import 'package:source_span/source_span.dart';

import 'patch.dart';

/// Returns the result of applying all of the [patches]
/// (insertions/deletions/replacements) to the contents of [sourceFile].
///
/// Throws an [Exception] if any two of the given [patches] overlap.
String applyPatches(SourceFile sourceFile, Iterable<Patch> patches) {
  final buffer = StringBuffer();
  final sortedPatches =
      patches.map((p) => SourcePatch.from(p, sourceFile)).toList()..sort();

  var lastEdgeOffset = 0;
  late Patch prev;
  for (final patch in sortedPatches) {
    if (patch.startOffset < lastEdgeOffset) {
      throw Exception('Codemod terminated due to overlapping patch.\n'
          'Previous patch:\n'
          '  $prev\n'
          '  Updated text: ${prev.updatedText}\n'
          'Overlapping patch:\n'
          '  $patch\n'
          '  Updated text: ${patch.updatedText}\n');
    }

    // Write unmodified text from end of last patch to beginning of this patch
    buffer.write(sourceFile.getText(lastEdgeOffset, patch.startOffset));
    // Write the patched text (and do nothing with the original text, which is
    // effectively the same as replacing it)
    buffer.write(patch.updatedText);

    lastEdgeOffset = patch.endOffset;
    prev = patch;
  }

  buffer.write(sourceFile.getText(lastEdgeOffset));
  return buffer.toString();
}

/// Applies all of the [patches] (insertions/deletions/replacements) to the
/// contents of [sourceFile] and writes the result to disk.
///
/// Throws an [ArgumentError] if [sourceFile] has a null value for
/// [SourceFile.url], as it is required to open the file and write the new
/// contents.
void applyPatchesAndSave(
  SourceFile sourceFile,
  Iterable<Patch> patches, [
  String? destPath,
]) {
  if (patches.isEmpty) {
    return;
  }
  if (sourceFile.url == null) {
    throw ArgumentError('sourceFile.url cannot be null');
  }
  final updatedContents = applyPatches(sourceFile, patches);

  if (destPath == null) {
    File.fromUri(sourceFile.url!).writeAsStringSync(updatedContents);
  } else {
    File(destPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(updatedContents);
  }
}
