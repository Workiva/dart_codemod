import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
import 'package:source_span/source_span.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
      Glob('**.txt').listSync().whereType<File>().where(isNotHiddenFile),
      OverlappingPatchSuggestor(),
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
