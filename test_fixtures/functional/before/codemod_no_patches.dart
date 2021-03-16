import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
      filePathsFromGlob(Glob('**')), (_) async* {},
      args: args);
}
