import 'dart:io';

import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
      ['file1.txt', 'file2.txt', 'skip.txt'], overlappingPatchSuggestor,
      args: args);
}

@override
Stream<Patch> overlappingPatchSuggestor(FileContext context) async* {
  yield Patch('overlap', 1, 3);
  yield Patch('dov', 0, 3);
}
