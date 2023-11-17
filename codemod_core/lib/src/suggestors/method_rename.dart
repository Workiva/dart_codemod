import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../codemod_core.dart';

/// Suggestor that renames a variables and fields
class MethodRename extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  MethodRename(this.existingName, this.newName);

  String existingName;
  String newName;

  bool isMatching(NamedCompilationUnitMember node) =>
      node.name.value() == existingName;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == existingName) {
      yieldPatch(newName, node.name.offset, node.name.end);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _patch(node.methodName);
    super.visitMethodInvocation(node);
  }

  void _patch(SimpleIdentifier node) {
    if (node.name == existingName) {
      yieldPatch(newName, node.offset, node.end);
    }
  }
}
