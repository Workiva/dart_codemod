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
import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

class Simple extends SimpleAstVisitor with AstVisitingSuggestorMixin {
  @override
  visitCompilationUnit(_) {
    yieldPatch(0, 1, 'foo');
  }
}

void main() {
  group('AstVisitingSuggestorMixin', () {
    test('should make the sourceFile available', () {
      final suggestor = Simple();
      final sourceFile = SourceFile.fromString(' ');
      suggestor.generatePatches(sourceFile).toList();
      expect(suggestor.sourceFile, sourceFile);
    });

    test('shouldSkip() returns false by default', () {
      final suggestor = Simple();
      expect(suggestor.shouldSkip(''), isFalse);
    });

    group('generatePatches()', () {
      test('should parse compilation unit, visit it, and yield patches', () {
        final suggestor = Simple();
        final sourceFile = SourceFile.fromString('library lib;');
        final patches = suggestor.generatePatches(sourceFile);
        expect(patches, hasLength(1));
        expect(patches.single.startOffset, 0);
        expect(patches.single.endOffset, 1);
        expect(patches.single.updatedText, 'foo');
      });

      test('should be able to be run multiple times', () {
        final suggestor = Simple();

        final sourceFileA = SourceFile.fromString('library a;');
        final patchesA = suggestor.generatePatches(sourceFileA);
        expect(patchesA, hasLength(1));
        expect(patchesA.single.startOffset, 0);
        expect(patchesA.single.endOffset, 1);
        expect(patchesA.single.updatedText, 'foo');
        expect(suggestor.sourceFile, sourceFileA);

        final sourceFileB = SourceFile.fromString('library b;');
        final patchesB = suggestor.generatePatches(sourceFileB);
        expect(patchesB, hasLength(1));
        expect(patchesB.single.startOffset, 0);
        expect(patchesB.single.endOffset, 1);
        expect(patchesB.single.updatedText, 'foo');
        expect(suggestor.sourceFile, sourceFileB);
      });
    });

    test(
        'yieldPatch() should throw StateError if called outside generatePatches()',
        () {
      expect(() => Simple().yieldPatch(0, 0, ''), throwsStateError);
    });
  });
}
