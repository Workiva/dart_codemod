import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
      filePathsFromGlob(Glob('**')), NoopSuggestor(),
      args: args);
}

class NoopSuggestor implements Suggestor {
  @override
  bool shouldSkip(_) => true;

  @override
  Iterable<Patch> generatePatches(_) => [];
}
