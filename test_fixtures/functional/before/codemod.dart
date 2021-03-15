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
    testSuggestor,
    args: args,
    defaultYes: defaultYes,
    additionalHelpOutput: additionalHelpOutput,
    changesRequiredOutput: changesRequiredOutput,
  );
}

@override
Stream<Patch> testSuggestor(FileContext context) async* {
  if (context.sourceText.startsWith('skip')) return;

  final sourceFile = context.sourceFile;
  final lineLength = 'line #'.length;

  // Suggestion 1: replace first line
  yield Patch('<REPLACE>', 0, lineLength);

  // Suggestion 2: insert a line after first line
  yield Patch('<INSERT>\n', lineLength + 1, lineLength + 1);

  // Suggestion 3: delete third (last) line
  yield Patch('', sourceFile.length - lineLength);
}
