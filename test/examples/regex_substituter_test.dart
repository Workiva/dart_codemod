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
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

final RegExp pattern = RegExp(
  r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
  multiLine: true,
);

const String targetConstraint = '^1.0.0';

class RegexSubstituter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) => false;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    for (final match in pattern.allMatches(contents)) {
      final line = match.group(0);
      final constraint = match.group(1);
      final updated = line.replaceFirst(constraint, targetConstraint) + '\n';

      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        updated,
      );
    }
  }
}

void main() {
  group('Examples: RegexSubstituter', () {
    test('updates `codemod` version', () {
      final sourceFile = SourceFile.fromString('''
dependencies:
  codemod: ^0.2.0
''');
      final expectedOutput = '''
dependencies:
  codemod: ^1.0.0
''';
      final patches = RegexSubstituter().generatePatches(sourceFile);
      expect(patches, hasLength(1));
      expect(applyPatches(sourceFile, patches), expectedOutput);
    });
  });
}
