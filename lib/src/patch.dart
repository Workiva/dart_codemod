import 'dart:math' as math;

import 'package:io/ansi.dart';
import 'package:source_span/source_span.dart';

import 'logging.dart';

class Patch implements Comparable<Patch> {
  final SourceFile sourceFile;
  final SourceSpan sourceSpan;
  final String updatedText;

  Patch(this.sourceFile, this.sourceSpan, this.updatedText);

  // TODO: human-friendly toString()

  bool get isNoop => sourceSpan.text == updatedText;

  int get startLine => sourceSpan.start.line;

  int get startLineOffset => sourceFile.getOffset(startLine);

  int get startOffset => sourceSpan.start.offset;

  int get endLine => sourceSpan.end.line + 1;

  int get endLineOffset {
    if (endLine >= sourceFile.lines) {
      // When passed to SourceFile.span(), null as the end offset implies the
      // end of the file, which is what we want here.
      return null;
    }
    return sourceFile.getOffset(endLine) - 1;
  }

  int get endOffset => sourceSpan.end.offset;

  @override
  int compareTo(Patch other) => sourceSpan.compareTo(other.sourceSpan);

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
        var line = lines[i];
        if (i == 0) {
          line = patchPreContext + line;
        }
        if (i == lines.length - 1) {
          line = line + patchPostContext;
        }
        buffer.writeln(color.wrap(linePrefix + line));
      }
    }

    for (var i = startContextLineNumber; i < startLine; i++) {
      writeFileLine(i);
    }
    writeDiffLines(sourceSpan.text.split('\n'), '- ', red);
    writeDiffLines(updatedText.split('\n'), '+ ', green);
    for (var i = endLine; i < endContextLineNumber; i++) {
      writeFileLine(i);
    }

    return buffer.toString();
  }

  String renderRange() {
    if (sourceSpan.start.line == sourceSpan.end.line - 1) {
      return '${sourceSpan.sourceUrl}:${sourceSpan.start.line}';
    }
    return '${sourceSpan.sourceUrl}:${sourceSpan.start.line}-${sourceSpan.end.line}';
  }
}
