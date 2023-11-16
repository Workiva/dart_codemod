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
library codemod.test.ast_visiting_suggestor_test;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:test/test.dart';

class Simple extends SimpleAstVisitor<void> with AstVisitingSuggestor {
  @override
  void visitCompilationUnit(_) {
    yieldPatch('foo', 0, 1);
  }
}

class Duplicate extends SimpleAstVisitor<void> with AstVisitingSuggestor {
  @override
  void visitCompilationUnit(_) {
    yieldPatch('foo', 0, 1);
    yieldPatch('foo', 0, 1);
  }
}

class LibNameDoubler extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitLibraryIdentifier(LibraryIdentifier node) {
    for (final component in node.components) {
      yieldPatch(component.name * 2, component.offset, component.end);
    }
  }
}

void main() {
  group('AstVisitingSuggestor', () {
    test('should get compilation unit, visit it, and yield patches', () async {
      final suggestor = Simple();
      final context = await fileContextForTest('lib.dart', 'library lib;');
      expect(
          suggestor(context),
          emitsInOrder([
            isA<Patch>()
                .having((p) => p.startOffset, 'startOffset', 0)
                .having((p) => p.endOffset, 'endOffset', 1)
                .having((p) => p.updatedText, 'updatedText', 'foo'),
            emitsDone,
          ]));
    });

    test('should be able to be run multiple times', () async {
      final suggestor = Simple();
      final expectedPatches = [Patch('foo', 0, 1)];

      final contextA = await fileContextForTest('a.dart', 'library a;');
      final patchesA = await suggestor(contextA).toList();
      expect(patchesA, expectedPatches);

      final contextB = await fileContextForTest('b.dart', 'library b;');
      final patchesB = await suggestor(contextB).toList();
      expect(patchesB, expectedPatches);
    });

    test('should de-duplicate patches', () async {
      final suggestor = Duplicate();
      final context = await fileContextForTest('foo.dart', 'library foo;');
      expect(await suggestor(context).toList(), hasLength(1));
    });

    test(
        'should scope patch generation such that it is not broken by '
        'listening to streams out-of-order', () async {
      final suggestor = LibNameDoubler();

      final contextA = await fileContextForTest('a.dart', 'library a;');
      final patchesA = suggestor(contextA);

      final contextB = await fileContextForTest('b.dart', 'library b;');
      final patchesB = suggestor(contextB);

      final contextC = await fileContextForTest('c.dart', 'library c;');
      final patchesC = suggestor(contextC);

      expect(await patchesB.toList(), [Patch('bb', 8, 9)]);
      expect(await patchesA.toList(), [Patch('aa', 8, 9)]);
      expect(await patchesC.toList(), [Patch('cc', 8, 9)]);
    });
  });
}
