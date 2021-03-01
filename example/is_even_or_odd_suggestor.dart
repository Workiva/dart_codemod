import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
// ignore: deprecated_member_use
import 'package:analyzer/analyzer.dart';

/// Removes all modulus operations on the int type and refactors them to use
/// [int.isEven] and [int.isOdd].
class IsEvenOrOddSuggestor extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  @override
  bool shouldResolveAst(_) => true;

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
            yieldPatch('.isEven', left.leftOperand.end, node.end);
          }
          if (right.value == 1) {
            yieldPatch('.isOdd', left.leftOperand.end, node.end);
          }
        }
      }
    }
    return super.visitBinaryExpression(node);
  }
}

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('codemod_analysis_required_fixtures/**.dart')),
    IsEvenOrOddSuggestor(),
    args: args,
  );
}
