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
import 'dart:io';

import 'package:codemod_core/codemod_core.dart';
import 'package:mockito/annotations.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

@GenerateMocks([Stdout])
void main() {
  group('Utils', () {
    group('applyPatches()', () {
      final sourceContents = '''
line 1;
line 2;
line 3;
line 4;
line 5;''';
      final sourceFile = SourceFile.fromString(sourceContents);

      // >>>
      // line 1;
      // <<<
      // li<INS>ne 1;
      final insertion = Patch('<INS>', 2, 2);

      // >>>
      // line 2;
      // line 3;
      // <<<
      // l<REP>ine 3;
      final replacement = Patch('<REP>', 9, 17);

      // >>>
      // line 4;
      // <<<
      // l4;
      final deletion = Patch('', 25, 29);

      // >>>
      // line 4;
      // line 5;
      // <<<
      // line 4;
      //
      final eofDeletion = Patch('', sourceFile.length - 'line 5;'.length);

      // Patch that overlaps with [replacement].
      final overlapsReplacement = Patch('NOPE', 11, 12);

      test('returns original source if patches is empty', () {
        expect(ChangeSet(sourceFile, []).apply(), sourceContents);
      });

      test('applies an insertion', () {
        expect(ChangeSet.fromPatchs(sourceFile, [insertion]).apply(), '''
li<INS>ne 1;
line 2;
line 3;
line 4;
line 5;''');
      });

      test('applies a replacement', () {
        expect(ChangeSet.fromPatchs(sourceFile, [replacement]).apply(), '''
line 1;
l<REP>ine 3;
line 4;
line 5;''');
      });

      test('applies a deletion', () {
        expect(ChangeSet.fromPatchs(sourceFile, [deletion]).apply(), '''
line 1;
line 2;
line 3;
l4;
line 5;''');
      });

      test('applies a deletion at end of file', () {
        expect(ChangeSet.fromPatchs(sourceFile, [eofDeletion]).apply(), '''
line 1;
line 2;
line 3;
line 4;
''');
      });

      test('applies multiple patches', () {
        expect(
            ChangeSet.fromPatchs(sourceFile, [insertion, replacement, deletion])
                .apply(),
            '''
li<INS>ne 1;
l<REP>ine 3;
l4;
line 5;''');
      });

      test('applies patches in order from beginning to end', () {
        expect(
            ChangeSet.fromPatchs(sourceFile, [deletion, insertion, replacement])
                .apply(),
            '''
li<INS>ne 1;
l<REP>ine 3;
l4;
line 5;''');
      });

      test('throws if any two patches overlap', () {
        expect(
            () => ChangeSet.fromPatchs(
                sourceFile, [replacement, overlapsReplacement]).apply(),
            throwsException);
      });
    });
  });
}
