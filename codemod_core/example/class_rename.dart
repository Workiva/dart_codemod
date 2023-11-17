// ignore_for_file: avoid_print

import 'package:codemod_core/src/patch_generator.dart';
import 'package:codemod_core/src/suggestors/class_rename.dart';
import 'package:codemod_core/src/suggestors/method_rename.dart';
import 'package:codemod_core/src/suggestors/variable_rename.dart';
import 'package:codemod_core/src/utility/name_generator.dart';
import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

void main(List<String> args) async {
  final pg = PatchGenerator([
    ClassRename((name) => ClassReplacer().replace(name)).call,
    VariableRename('existing', 'different').call,
    MethodRename('aMethod', 'aDifferent').call
  ]);

  final fixtures = join(DartProject.self.pathToExampleDir, 'fixtures');

  const libraryName = 'class_for_rename.dart';
  final testLibrary = join(fixtures, libraryName);

  final changeSetStream = pg.generate(paths: [testLibrary]);
  await for (final changeSet in changeSetStream) {
    print(changeSet.apply());
  }
}

class ClassReplacer {
  factory ClassReplacer() => _self;

  ClassReplacer._internal();
  static final ClassReplacer _self = ClassReplacer._internal();
  VariableNameGenerator gen = VariableNameGenerator();

  Map<String, String> replacementMap = <String, String>{};

  String replace(String existing) {
    var value = replacementMap[existing];
    if (value == null) {
      value = _generateName(existing);
      replacementMap[existing] = value;
    }
    return value;
  }

  String _generateName(String existing) {
    var prefix = '';

    /// retain the private nature of declarations
    if (existing.startsWith('_')) {
      prefix = '_';
    }
    return '$prefix${gen.next()}';
  }
}
