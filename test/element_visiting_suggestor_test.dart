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
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:test/test.dart';

class Simple extends RecursiveElementVisitor<void>
    with ElementVisitingSuggestor {
  @override
  void visitCompilationUnitElement(_) {
    yieldPatch('foo', 0, 1);
  }
}

class Duplicate extends RecursiveElementVisitor<void>
    with ElementVisitingSuggestor {
  @override
  void visitCompilationUnitElement(_) {
    yieldPatch('foo', 0, 1);
    yieldPatch('foo', 0, 1);
  }
}

class ImportExporter extends RecursiveElementVisitor<void>
    with ElementVisitingSuggestor {
  @override
  void visitLibraryElement(LibraryElement element) {
    final insertOffset = elementNode<ImportDirective>(element.imports.last).end;
    for (final import in element.imports) {
      final importNode = elementNode<ImportDirective>(import);
      yieldPatch("\nexport '${importNode.uri.stringValue}';", insertOffset,
          insertOffset);
    }
  }
}

class DartCoreImportRemover extends RecursiveElementVisitor<void>
    with ElementVisitingSuggestor {
  @override
  void visitImportElement(ImportElement element) {
    if (element.importedLibrary.isDartCore) {
      final node = elementNode(element);
      yieldPatch('', node.offset, node.end);
    }
  }
}

void main() {
  group('ElementVisitingSuggestor', () {
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

    test('should have access to fully resolved elements', () async {
      final suggestor = DartCoreImportRemover();
      final context = await fileContextForTest('foo.dart', '''library foo;
import 'dart:core';
import 'dart:async';''');
      expectSuggestorGeneratesPatches(suggestor, context, '''library foo;
import 'dart:async';''');
    });

    test(
        'should scope patch generation such that it is not broken by '
        'listening to streams out-of-order', () async {
      final suggestor = ImportExporter();

      final contextA = await fileContextForTest('a.dart', '''library a;
import 'dart:async';''');
      final patchesA = suggestor(contextA);

      final contextB = await fileContextForTest('b.dart', '''library b;
import 'dart:collection';''');
      final patchesB = suggestor(contextB);

      final contextC = await fileContextForTest('c.dart', '''library c;
import 'dart:typed_data';''');
      final patchesC = suggestor(contextC);

      expect(await patchesB.toList(),
          [Patch("\nexport 'dart:collection';", 10, 10)]);
      expect(
          await patchesA.toList(), [Patch("\nexport 'dart:async';", 10, 10)]);
      expect(await patchesC.toList(),
          [Patch("\nexport 'dart:typed_data';", 10, 10)]);
    });
  });
}
