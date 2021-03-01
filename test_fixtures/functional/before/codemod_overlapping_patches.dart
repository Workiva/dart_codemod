import 'dart:io';

import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
      ['file1.txt', 'file2.txt', 'skip.txt'], OverlappingPatchSuggestor(),
      args: args);
}

class OverlappingPatchSuggestor implements Suggestor {
  @override
  Stream<Patch> generatePatches(FileContext context) async* {
    yield context.patch('overlap', 1, 3);
    yield context.patch('dov', 0, 3);
  }
}
