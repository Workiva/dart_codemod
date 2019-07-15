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

import 'package:mockito/mockito.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:codemod/src/patch.dart';
import 'package:codemod/src/util.dart';

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
      final insertion = Patch(
        sourceFile,
        sourceFile.span(2, 2),
        '<INS>',
      );

      // >>>
      // line 2;
      // line 3;
      // <<<
      // l<REP>ine 3;
      final replacement = Patch(
        sourceFile,
        sourceFile.span(9, 17),
        '<REP>',
      );

      // >>>
      // line 4;
      // <<<
      // l4;
      final deletion = Patch(
        sourceFile,
        sourceFile.span(25, 29),
        '',
      );

      // >>>
      // line 4;
      // line 5;
      // <<<
      // line 4;
      //
      final eofDeletion = Patch(
        sourceFile,
        sourceFile.span(sourceFile.length - 'line 5;'.length),
        '',
      );

      // Patch that overlaps with [replacement].
      final overlapsReplacement = Patch(
        sourceFile,
        sourceFile.span(11, 12),
        'NOPE',
      );

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
      }, skip: 'https://github.com/dart-lang/source_span/pull/28');

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
        when(mockStdout.hasTerminal).thenReturn(false);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 if # of terminal lines is too small', () {
        final mockStdout = MockStdout();
        when(mockStdout.hasTerminal).thenReturn(true);
        when(mockStdout.terminalLines).thenReturn(15);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 less than available # of terminal lines', () {
        final mockStdout = MockStdout();
        when(mockStdout.hasTerminal).thenReturn(true);
        when(mockStdout.terminalLines).thenReturn(50);
        expect(calculateDiffSize(mockStdout), 40);
      });
    });

    test('createPathFilter() returns a filter function for given extensions',
        () {
      final filter = createPathFilter(['.yaml', '.yml']);
      expect(filter('./lib/foo.yaml'), isTrue);
      expect(filter('./lib/foo.yml'), isTrue);
      expect(filter('./lib/foo.dart'), isFalse);
    });

    test('isDartFile() returns true only if extension is .dart', () {
      expect(isDartFile('./lib/foo.dart'), isTrue);
      expect(isDartFile('./lib/foo.yaml'), isFalse);
    });

    group('pathLooksLikeCode()', () {
      test('returns false if any path segment starts with a dot', () {
        expect(pathLooksLikeCode('/.dotfile'), isFalse);
        expect(pathLooksLikeCode('.packages'), isFalse);
        expect(pathLooksLikeCode('.dart_tool/pub/bin/sdk-version'), isFalse);
        expect(pathLooksLikeCode('project/.packages'), isFalse);
        expect(pathLooksLikeCode('project/.dart_tool/'), isFalse);
      });

      test('returns false if root path segment is build', () {
        expect(pathLooksLikeCode('build/'), isFalse);
        expect(pathLooksLikeCode('build/test.dart'), isFalse);
        expect(pathLooksLikeCode('build/packages/test.dart'), isFalse);
      });

      test('returns true if non-root path segment is build', () {
        expect(pathLooksLikeCode('lib/src/build/'), isTrue);
        expect(pathLooksLikeCode('tool/build/test.dart'), isTrue);
      });

      test(
          'returns true if root path segment is build and includeFiles contains build',
          () {
        expect(pathLooksLikeCode('build/', includePaths: ['build']), isTrue);
        expect(pathLooksLikeCode('build/test.dart', includePaths: ['build']),
            isTrue);
        expect(
            pathLooksLikeCode('build/packages/test.dart',
                includePaths: ['build/']),
            isTrue);
      });

      test('returns true if path starts with dot but only to reference cwd',
          () {
        expect(pathLooksLikeCode('./lib/foo.dart'), isTrue);
      });

      test('returns true otherwise', () {
        expect(pathLooksLikeCode('foo.dart'), isTrue);
        expect(pathLooksLikeCode('./foo.dart'), isTrue);
        expect(pathLooksLikeCode('lib/foo.dart'), isTrue);
        expect(pathLooksLikeCode('./lib/foo.dart'), isTrue);
      });
    });
  });
}

class MockStdout extends Mock implements Stdout {}
