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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:test/test.dart';

class DeprecatedRemover extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');

  @override
  void visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the node by replacing the span from its start offset to its end
      // offset with an empty string.
      yieldPatch('', node.offset, node.end);
    }
  }
}

void main() {
  group('Examples: DeprecatedRemover', () {
    test('removes deprecated variable', () async {
      final context = await fileContextForTest('test.dart', '''
// Not deprecated.
var foo = 'foo';
@deprecated
var bar = 'bar';''');
      final expectedOutput = '''
// Not deprecated.
var foo = 'foo';
''';
      expectSuggestorGeneratesPatches(
          DeprecatedRemover(), context, expectedOutput);
    });
  });
}
