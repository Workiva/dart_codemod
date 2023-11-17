import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../codemod_core.dart';

typedef Replace = String Function(String existing);

/// Suggestor that renames a class
class ClassRename extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  ClassRename(this.replace);

  Replace replace;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // if (isMatching(node)) {
    //   yieldPatch(newClassName, node.offset, node.end);
    // }
    super.visitSimpleIdentifier(node);
  }

  // The actual class declaration
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final replacement = replace(node.name.lexeme);
    yieldPatch(replacement, node.name.offset, node.name.end);
    super.visitClassDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // if (node.runtimeType.toString() == existingClassName) {
    final replacement = replace(node.name.lexeme);
    yieldPatch(replacement, node.name.offset, node.name.end);
    //}
    super.visitVariableDeclaration(node);
  }
}
