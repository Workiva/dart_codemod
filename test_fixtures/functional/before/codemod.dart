import 'dart:io';

import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  await run(args);
}

Future<void> run(List<String> args,
    {bool defaultYes,
    String additionalHelpOutput,
    String changesRequiredOutput}) async {
  exitCode = await runInteractiveCodemod(
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
  Stream<Patch> generatePatches(FileContext context) async* {
    if (context.sourceText.startsWith('skip')) return;

    final sourceFile = context.sourceFile;
    final lineLength = 'line #'.length;

    // Suggestion 1: replace first line
    yield context.patch('<REPLACE>', 0, lineLength);

    // Suggestion 2: insert a line after first line
    yield context.patch('<INSERT>\n', lineLength + 1, lineLength + 1);

    // Suggestion 3: delete third (last) line
    yield context.patch('', sourceFile.length - lineLength);
  }
}
