import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../codemod_core.dart';

/// Suggestor that renames a variables and fields
class VariableRename extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  VariableRename(this.existingName, this.newName);

  String existingName;
  String newName;

  bool isMatching(NamedCompilationUnitMember node) =>
      node.name.value() == existingName;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _patch(node.name);
    super.visitVariableDeclaration(node);
  }

  void _patch(Token node) {
    if (node.lexeme == existingName) {
      yieldPatch(newName, node.offset, node.end);
    }
  }
}
