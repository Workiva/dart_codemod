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

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

/// Removes all modulus operations on the int type and refactors them to use
/// [int.isEven] and [int.isOdd].
class IsEvenOrOddSuggestor extends GeneralizingAstVisitor
    with ResolvedAstVisitingSuggestorMixin {
  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.leftOperand is BinaryExpression &&
        node.rightOperand is IntegerLiteral) {
      final left = node.leftOperand as BinaryExpression;
      final right = node.rightOperand as IntegerLiteral;
      if (left.operator.stringValue == '%' &&
          node.operator.stringValue == '==') {
        if (left.leftOperand.staticType.isDartCoreInt) {
          if (right.value == 0) {
            yieldPatch(left.leftOperand.end, node.end, '.isEven');
          }
          if (right.value == 1) {
            yieldPatch(left.leftOperand.end, node.end, '.isOdd');
          }
        }
      }
    }
    return super.visitBinaryExpression(node);
  }
}

void main() {
  group('Examples: AnalysisRequired', () {
    test('changes modulus to isEven and isOdd only for an int receiver',
        () async {
      final sourceFile = SourceFile.fromString('''
// Change to isEven
var foo = (250 + 2) % 2 == 0;

// Change to isOdd
var bar = (250 + 2) % 2 == 1;

// No changes, not int modulus
var baz = 25.0 % 2 == 0;
''');
      final dir = Directory.current.createTempSync();
      final filePath = path.join(dir.path, 'test.dart');
      File(filePath).writeAsStringSync(sourceFile.getText(0));

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final f = path.canonicalize(filePath);
      final context = collection.contextFor(f);
      final unit = await context.currentSession.getResolvedUnit(f);
      final compilationUnit = unit.unit;
      final expectedOutput = '''
// Change to isEven
var foo = (250 + 2).isEven;

// Change to isOdd
var bar = (250 + 2).isOdd;

// No changes, not int modulus
var baz = 25.0 % 2 == 0;
''';
      dir.deleteSync(recursive: true);
      final patches = IsEvenOrOddSuggestor()
          .generatePatches(sourceFile, compilationUnit: compilationUnit);
      expect(patches, hasLength(2));
      expect(applyPatches(sourceFile, patches), expectedOutput);
    });
  });
}
