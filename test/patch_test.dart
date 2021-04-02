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
import 'package:io/ansi.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:codemod/src/patch.dart';

import 'util.dart';

final contents = '''
line 1;
line 2;
line 3;
line 4;
line 5;
line 6;''';

final sourceFileUrl = 'lib/foo.dart';
final sourceFile = SourceFile.fromString(contents, url: sourceFileUrl);

void main() {
  late String pls;
  late String mns;
  overrideAnsiOutput(true, () {
    pls = green.wrap('+ ')!;
    mns = red.wrap('- ')!;
  });

  group('SourcePatch', () {
    test('from(Patch patch)', () {
      final patch1 = SourcePatch.from(Patch('one', 0, 5), sourceFile);
      expect(patch1.startOffset, 0);
      expect(patch1.endOffset, 5);
      expect(patch1.updatedText, 'one');

      // Patch with endOffset omitted
      final patch2 = SourcePatch.from(Patch('two', 10), sourceFile);
      expect(patch2.startOffset, 10);
      expect(patch2.endOffset, sourceFile.length);
      expect(patch2.updatedText, 'two');
    });

    test('compareTo() compares the sourceSpans', () {
      final span1 = sourceFile.span(0, 5);
      final span2 = sourceFile.span(10, 15);
      final patch1 = SourcePatch(sourceFile, span1, '');
      final patch2 = SourcePatch(sourceFile, span2, '');
      expect(patch1.compareTo(patch2), lessThan(0));
      expect(patch2.compareTo(patch1), greaterThan(0));
      expect(patch1.compareTo(patch1), 0);
    });

    test('isNoop is true if the updated text is the same as original', () {
      final span = sourceFile.span(5, 10);
      final patch = SourcePatch(sourceFile, span, span.text);
      expect(patch.isNoop, isTrue);
    });

    test('isNoop is false if the updated text is different than original', () {
      final span = sourceFile.span(5, 10);
      final patch = SourcePatch(sourceFile, span, 'different');
      expect(patch.isNoop, isFalse);
    });

    test('startLine is the line for the start of the sourceSpan', () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.startLine, 1);
    });

    test('startLineOffset is the offset for startLine', () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.startLineOffset, 'line 1;\n'.length);
    });

    test('startOffset is the offset of the start of the sourceSpan', () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.startOffset, 10);
    });

    test('endLine is the line after the line for the end of the sourceSpan',
        () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.endLine, 2);
    });

    test('endLineOffset is one less than the offset for the endLine', () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.endLineOffset, 'line 1;\nline 2;'.length);
    });

    test(
        'endLineOffset is null if the sourceSpan reaches the end of the sourceFile',
        () {
      final span = sourceFile.span(10);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.endLineOffset, isNull);
    });

    test('endOffset is the offset of the end of the sourceSpan', () {
      final span = sourceFile.span(10, 15);
      final patch = SourcePatch(sourceFile, span, '');
      expect(patch.endOffset, 15);
    });

    group('renderDiff()', () {
      testWithAnsi('represents an insertion', () {
        // li><ne 2;
        final span = sourceFile.span(10, 10);
        final patch = SourcePatch(sourceFile, span, 'ADDED');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'line 2;',
          pls + 'li' + green.wrap('ADDED')! + 'ne 2;',
          '',
        ]);
      });

      testWithAnsi('represents a multi-line insertion', () {
        // li><ne 2;
        final span = sourceFile.span(10, 10);
        final patch = SourcePatch(sourceFile, span, 'ADDED1\nADDED2');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'line 2;',
          pls + 'li' + green.wrap('ADDED1')!,
          pls + green.wrap('ADDED2')! + 'ne 2;',
          '',
        ]);
      });

      testWithAnsi('represents a replacement', () {
        // li>ne< 2;
        final span = sourceFile.span(10, 12);
        final patch = SourcePatch(sourceFile, span, 'REPLACED');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne')! + ' 2;',
          pls + 'li' + green.wrap('REPLACED')! + ' 2;',
          '',
        ]);
      });

      testWithAnsi('represents a single-line replacement across multiple lines',
          () {
        // li>ne 2;
        // l<ine 3;
        final span = sourceFile.span(10, 17);
        final patch = SourcePatch(sourceFile, span, 'REPLACED');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne 2;')!,
          mns + red.wrap('l')! + 'ine 3;',
          pls + 'li' + green.wrap('REPLACED')! + 'ine 3;',
          '',
        ]);
      });

      testWithAnsi('represents a multi-line replacement across multiple lines',
          () {
        // li>ne 2;
        // l<ine 3;
        final span = sourceFile.span(10, 17);
        final patch = SourcePatch(sourceFile, span, 'REPLACED1\nREPLACED2');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne 2;')!,
          mns + red.wrap('l')! + 'ine 3;',
          pls + 'li' + green.wrap('REPLACED1')!,
          pls + green.wrap('REPLACED2')! + 'ine 3;',
          '',
        ]);
      });

      testWithAnsi('represents a multi-line replacement across one line', () {
        // li>ne< 2;
        final span = sourceFile.span(10, 12);
        final patch = SourcePatch(sourceFile, span, 'REPLACED1\nREPLACED2');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne')! + ' 2;',
          pls + 'li' + green.wrap('REPLACED1')!,
          pls + green.wrap('REPLACED2')! + ' 2;',
          '',
        ]);
      });

      testWithAnsi('represents a deletion', () {
        // li>ne< 2;
        final span = sourceFile.span(10, 12);
        final patch = SourcePatch(sourceFile, span, '');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne')! + ' 2;',
          '',
        ]);
      });

      testWithAnsi('represents a multi-line deletion', () {
        // li>ne 2;
        // l<ine 3;
        final span = sourceFile.span(10, 17);
        final patch = SourcePatch(sourceFile, span, '');
        final diffLines = patch.renderDiff(1).split('\n');
        expect(diffLines, [
          mns + 'li' + red.wrap('ne 2;')!,
          mns + red.wrap('l')! + 'ine 3;',
          '',
        ]);
      });

      testWithAnsi('includes before/after context lines if there is room', () {
        // line 1;
        // line 2;
        // li>ne 3;
        // l<ine 4;
        // line 5;
        // line 6;
        final span = sourceFile.span(18, 25);
        final patch = SourcePatch(sourceFile, span, 'R1\nR2');
        final diffLines = patch.renderDiff(12).split('\n');
        expect(diffLines, [
          '~',
          '~',
          '  line 1;',
          '  line 2;',
          mns + 'li' + red.wrap('ne 3;')!,
          mns + red.wrap('l')! + 'ine 4;',
          pls + 'li' + green.wrap('R1')!,
          pls + green.wrap('R2')! + 'ine 4;',
          '  line 5;',
          '  line 6;',
          '~',
          '~',
          '',
        ]);
      });
    });

    group('renderRange()', () {
      test('with a single-line patch', () {
        // li>ne 2<;
        final span = sourceFile.span(10, 14);
        final patch = SourcePatch(sourceFile, span, '');
        expect(patch.renderRange(), 'lib/foo.dart:2');
      });

      test('with a multi-line patch', () {
        // li>ne 2;
        // lin<e 3;
        final span = sourceFile.span(10, 19);
        final patch = SourcePatch(sourceFile, span, '');
        expect(patch.renderRange(), 'lib/foo.dart:2-3');
      });
    });

    group('toString()', () {
      test('returns a human-readable representation of the patch', () {
        // li>ne 2;
        // lin<e 3;
        final span = sourceFile.span(10, 19);
        final patch = SourcePatch(sourceFile, span, '');
        expect(
            patch.toString(), '<SourcePatch: on lib/foo.dart from 2:3 to 3:4>');
      });

      test('substitutes <unknown> if source file URL is missing', () {
        final sourceFile = SourceFile.fromString(' ');
        final span = sourceFile.span(0);
        final patch = SourcePatch(sourceFile, span, '');
        expect(patch.toString(), startsWith('<SourcePatch: on <unknown>'));
      });
    });
  });
}
