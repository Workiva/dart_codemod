// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:test/test.dart';

final RegExp pattern = RegExp(
  r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
  multiLine: true,
);

const String targetConstraint = '^1.0.0';

class RegexSubstituter implements Suggestor {
  @override
  Stream<Patch> generatePatches(FileContext context) async* {
    for (final match in pattern.allMatches(context.sourceText)) {
      final line = match.group(0);
      final constraint = match.group(1);
      final updated = line.replaceFirst(constraint, targetConstraint) + '\n';

      yield context.patch(updated, match.start, match.end);
    }
  }
}

void main() {
  group('Examples: RegexSubstituter', () {
    test('updates `codemod` version', () async {
      final context = await fileContextForTest('pubspec.yaml', '''
dependencies:
  codemod: ^0.2.0
''');
      final expectedOutput = '''
dependencies:
  codemod: ^1.0.0
''';
      expectSuggestorGeneratesPatches(
          RegexSubstituter(), context, expectedOutput);
    });
  });
}
