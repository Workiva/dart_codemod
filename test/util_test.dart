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

import 'package:mocktail/mocktail.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:codemod/src/patch.dart';
import 'package:codemod/src/util.dart';

class MockStdout extends Mock implements Stdout {}

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
        expect(applyPatches(sourceFile, []), sourceContents);
      });

      test('applies an insertion', () {
        expect(applyPatches(sourceFile, [insertion]), '''
li<INS>ne 1;
line 2;
line 3;
line 4;
line 5;''');
      });

      test('applies a replacement', () {
        expect(applyPatches(sourceFile, [replacement]), '''
line 1;
l<REP>ine 3;
line 4;
line 5;''');
      });

      test('applies a deletion', () {
        expect(applyPatches(sourceFile, [deletion]), '''
line 1;
line 2;
line 3;
l4;
line 5;''');
      });

      test('applies a deletion at end of file', () {
        expect(applyPatches(sourceFile, [eofDeletion]), '''
line 1;
line 2;
line 3;
line 4;
''');
      });

      test('applies multiple patches', () {
        expect(applyPatches(sourceFile, [insertion, replacement, deletion]), '''
li<INS>ne 1;
l<REP>ine 3;
l4;
line 5;''');
      });

      test('applies patches in order from beginning to end', () {
        expect(applyPatches(sourceFile, [deletion, insertion, replacement]), '''
li<INS>ne 1;
l<REP>ine 3;
l4;
line 5;''');
      });

      test('throws if any two patches overlap', () {
        expect(
            () => applyPatches(sourceFile, [replacement, overlapsReplacement]),
            throwsException);
      });
    });

    group('calculateDiffSize()', () {
      test('returns 10 if stdout does not have a terminal', () {
        final mockStdout = MockStdout();
        when(() => mockStdout.hasTerminal).thenReturn(false);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 if # of terminal lines is too small', () {
        final mockStdout = MockStdout();
        when(() => mockStdout.hasTerminal).thenReturn(true);
        when(() => mockStdout.terminalLines).thenReturn(15);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 less than available # of terminal lines', () {
        final mockStdout = MockStdout();
        when(() => mockStdout.hasTerminal).thenReturn(true);
        when(() => mockStdout.terminalLines).thenReturn(50);
        expect(calculateDiffSize(mockStdout), 40);
      });
    });
  });
}
