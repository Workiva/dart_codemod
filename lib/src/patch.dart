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

import 'dart:math' as math;

import 'package:io/ansi.dart';
import 'package:quiver/core.dart';
import 'package:source_span/source_span.dart';

import 'logging.dart';

/// A representation of a change to a source file.
///
/// The change targets a specific span within the file and specifies the text
/// that would be inserted at that span if applied.
///
/// A patch can represent an insertion, a deletion, or a replacement:
///
/// - An insertion has a non-empty [updatedText] value at a "point span",
///   meaning [startOffset] and [endOffset] are the same.
/// - A deletion will have an empty [updatedText] value with an [endOffset] that
///   is greater than [startOffset]. The text across this span will be deleted.
/// - A replacement will have a non-empty [updatedText] value with an
///   [endOffset] that is greater than [startOffset]. The text across this span
///   will be replaced by [updatedText].
///
/// Also note that [endOffset] may be null, in which case it defaults to the end
/// of the file.
class Patch {
  final int startOffset;

  final int? endOffset;

  /// The value that would be written in place of the existing text across the
  /// [sourceSpan].
  ///
  /// An empty value here represents a deletion, whereas a non-empty value may
  /// represent either an insertion or a replacement.
  final String updatedText;

  Patch(this.updatedText, this.startOffset, [this.endOffset]);

  @override
  bool operator ==(other) =>
      other is Patch &&
      startOffset == other.startOffset &&
      endOffset == other.endOffset &&
      updatedText == other.updatedText;

  @override
  int get hashCode => hash3(updatedText, startOffset, endOffset);

  @override
  String toString() => '<Patch: from $startOffset to ${endOffset ?? 'EOF'}>';
}

/// A more specific implementation of [Patch] that is associated with a
/// [sourceFile] in order to enable the application of this patch to that file.
///
/// This class also includes text rendering utilities for use in a CLI.
class SourcePatch implements Patch, Comparable<SourcePatch> {
  /// The original source file upon which this patch represents a change.
  final SourceFile sourceFile;

  /// The span of text within [sourceFile] that this patch is targeting.
  final SourceSpan sourceSpan;

  /// The value that would be written in place of the existing text across the
  /// [sourceSpan].
  ///
  /// An empty value here represents a deletion, whereas a non-empty value may
  /// represent either an insertion or a replacement.
  @override
  final String updatedText;

  SourcePatch(this.sourceFile, this.sourceSpan, this.updatedText);

  SourcePatch.from(Patch patch, SourceFile sourceFile)
      : this(sourceFile, sourceFile.span(patch.startOffset, patch.endOffset),
            patch.updatedText);

  @override
  int compareTo(SourcePatch other) => sourceSpan.compareTo(other.sourceSpan);

  @override
  bool operator ==(other) =>
      other is SourcePatch &&
      sourceSpan == other.sourceSpan &&
      updatedText == other.updatedText;

  @override
  int get hashCode => hash2(sourceSpan, updatedText);

  /// True if this patch is a no-operation, meaning that the updated text is the
  /// same as the existing text at the span. False otherwise.
  bool get isNoop => sourceSpan.text == updatedText;

  /// The 0-based line of the location in the source file of the beginning of
  /// this patch.
  int get startLine => sourceSpan.start.line;

  /// The offset for the beginning (i.e. column 0) of this patch's start line.
  int get startLineOffset => sourceFile.getOffset(startLine);

  /// The offset for the beginning of this patch in the source file.
  @override
  int get startOffset => sourceSpan.start.offset;

  /// The 0-based line of the location in the source file after the end of this
  /// this patch.
  ///
  /// This is always the line immediately following the last line of
  /// [sourceSpan].
  int get endLine => sourceSpan.end.line + 1;

  /// The offset for the end (i.e. last column) of this patch's end line.
  ///
  /// This is equivalent to one less than the offset for [endLine].
  ///
  /// If this patch extends to the very end of the source file, then this will
  /// be null rather than returning an offset that would be out-of-range.
  int? get endLineOffset {
    if (endLine >= sourceFile.lines) {
      // When passed to SourceFile.span(), null as the end offset implies the
      // end of the file, which is what we want here.
      return null;
    }
    return sourceFile.getOffset(endLine) - 1;
  }

  /// The offset for the end of this patch in the source file.
  @override
  int get endOffset => sourceSpan.end.offset;

  /// Returns a multi-line string diff representation of the change that this
  /// patch would make if applied.
  ///
  /// The returned line will be [numRowsToPrint]-lines long.
  ///
  /// The original line(s) contained within [sourceSpan] will be highlighted in
  /// red and the new line(s) from [updatedText] will be highlighted in green.
  ///
  /// Lines from the source file before and after the lines targeted by this
  /// patch will be included for context. The number of these lines that are
  /// included for context will be based on the number of lines left (using
  /// [numRowsToPrint] as the maximum) after rendering the patch diff.
  String renderDiff(int numRowsToPrint) {
    final sizeOfOld = endLine - startLine;
    final sizeOfNew =
        updatedText.isNotEmpty ? updatedText.split('\n').length : 0;
    final sizeOfDiff = sizeOfOld + sizeOfNew;
    final sizeOfContext = math.max(0, numRowsToPrint - sizeOfDiff);
    final sizeOfUpContext = (sizeOfContext / 2).floor();
    final sizeOfDownContext = (sizeOfContext / 2).ceil();
    final startContextLineNumber = startLine - sizeOfUpContext;
    final endContextLineNumber = endLine + sizeOfDownContext;

    final diffSizingDebug = {
      'numRowsToPrint': numRowsToPrint,
      'sizeOfOld': sizeOfOld,
      'sizeOfNew': sizeOfNew,
      'sizeOfDiff': sizeOfDiff,
      'sizeOfContext': sizeOfContext,
      'sizeOfUpContext': sizeOfUpContext,
      'sizeOfDownContext': sizeOfDownContext,
      'startContextLineNumber': startContextLineNumber,
      'endContextLineNumber': endContextLineNumber,
    };
    logger.fine('diff sizing:\n' +
        diffSizingDebug.keys
            .map((k) => '\t$k: ${diffSizingDebug[k]}')
            .join('\n'));
    logger.fine('old text:\n${sourceSpan.text}');
    logger.fine('new text:\n$updatedText');

    final buffer = StringBuffer();
    final sourceFileLines = sourceFile.getText(0).split('\n');
    final patchPreContext = sourceFile.span(startLineOffset, startOffset).text;
    final patchPostContext = endLineOffset != null
        ? sourceFile.span(endOffset, endLineOffset).text
        : '';

    void writeFileLine(int lineNumber) {
      buffer.writeln(lineNumber >= 0 && lineNumber < sourceFileLines.length
          ? '  ${sourceFileLines[lineNumber]}'
          : '~');
    }

    void writeDiffLines(List<String> lines, String linePrefix, AnsiCode color) {
      for (var i = 0; i < lines.length; i++) {
        var line = color.wrap(lines[i])!;
        if (i == 0) {
          line = patchPreContext + line;
        }
        if (i == lines.length - 1) {
          line = line + patchPostContext;
        }
        buffer.writeln(color.wrap(linePrefix)! + line);
      }
    }

    for (var i = startContextLineNumber; i < startLine; i++) {
      writeFileLine(i);
    }
    writeDiffLines(sourceSpan.text.split('\n'), '- ', red);
    if (updatedText.isNotEmpty) {
      writeDiffLines(updatedText.split('\n'), '+ ', green);
    }
    for (var i = endLine; i < endContextLineNumber; i++) {
      writeFileLine(i);
    }

    return buffer.toString();
  }

  /// Returns the line range within the source file of this patch.
  ///
  ///     "./lib/foo.dart:10-12"
  ///     "./lib/bar.dart:25"
  String renderRange() {
    if (startLine == endLine - 1) {
      return '${sourceSpan.sourceUrl}:${startLine + 1}';
    }
    return '${sourceSpan.sourceUrl}:${startLine + 1}-${endLine}';
  }

  @override
  String toString() => '<SourcePatch:'
      ' on ${sourceFile.url?.path ?? '<unknown>'}'
      ' from ${sourceSpan.start.line + 1}:${sourceSpan.start.column + 1}'
      ' to ${sourceSpan.end.line + 1}:${sourceSpan.end.column + 1}'
      '>';
}
