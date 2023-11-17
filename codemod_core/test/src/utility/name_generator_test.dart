// ignore_for_file: avoid_print

import 'package:codemod_core/src/utility/name_generator.dart';
import 'package:test/test.dart';

void main() {
  test('name generator ...', () async {
    final gen = VariableNameGenerator();
    for (var i = 0; i < 1000; i++) {
      print(gen.next());
    }
  });
}
