import 'dart:io';

import 'package:codemod/codemod.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(FileQuery.dir(), NoopSuggestor(), args: args);
}

class NoopSuggestor implements Suggestor {
  @override
  bool shouldSkip(_) => true;

  @override
  Iterable<Patch> generatePatches(_) => [];
}