import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod_core/codemod_core.dart';

/// Removes all modulus operations on the int type and refactors them to use
/// [int.isEven] and [int.isOdd].
class IsEvenOrOddSuggestor extends GeneralizingAstVisitor<void>
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
        if (left.leftOperand.staticType!.isDartCoreInt) {
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
