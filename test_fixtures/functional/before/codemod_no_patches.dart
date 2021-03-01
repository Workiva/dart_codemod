import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
      filePathsFromGlob(Glob('**')), NoopSuggestor(),
      args: args);
}

class NoopSuggestor implements Suggestor {
  @override
  Stream<Patch> generatePatches(_) => Stream.empty();
}
