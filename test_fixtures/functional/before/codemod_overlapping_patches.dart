import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
      ['file1.txt', 'file2.txt', 'skip.txt'], OverlappingPatchSuggestor(),
      args: args);
}

class OverlappingPatchSuggestor implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) => false;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    yield Patch(sourceFile, sourceFile.span(0, 3), 'dov');
    yield Patch(sourceFile, sourceFile.span(1, 3), 'overlap');
  }
}
