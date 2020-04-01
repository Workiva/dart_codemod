import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
import 'package:source_span/source_span.dart';

void main(List<String> args) {
  run(args);
}

void run(List<String> args,
    {bool defaultYes,
    String additionalHelpOutput,
    String changesRequiredOutput}) {
  exitCode = runInteractiveCodemod(
    ['file1.txt', 'file2.txt', 'skip.txt'],
    TestSuggestor(),
    args: args,
    defaultYes: defaultYes,
    additionalHelpOutput: additionalHelpOutput,
    changesRequiredOutput: changesRequiredOutput,
  );
}

class TestSuggestor implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) =>
      sourceFileContents.startsWith('skip');

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final lineLength = 'line #'.length;

    // Suggestion 1: replace first line
    yield Patch(
      sourceFile,
      sourceFile.span(0, lineLength),
      '<REPLACE>',
    );

    // Suggestion 2: insert a line after first line
    yield Patch(
      sourceFile,
      sourceFile.span(lineLength + 1, lineLength + 1),
      '<INSERT>\n',
    );

    // Suggestion 3: delete third (last) line
    yield Patch(
      sourceFile,
      sourceFile.span(
        sourceFile.length - lineLength,
        // The end offset has to be explicitly included here even though this
        // patch is targeting the end of the file until this bug is fixed:
        // https://github.com/dart-lang/source_span/pull/28
        sourceFile.length,
      ),
      '',
    );
  }
}
