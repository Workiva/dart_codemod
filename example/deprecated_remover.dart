import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

class DeprecatedRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');

  @override
  visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the node by replacing the span from its start offset to its end
      // offset with an empty string.
      yieldPatch(node.offset, node.end, '');
    }
  }
}

void main(List<String> args) => runInteractiveCodemod(
      FileQuery.cwd(pathFilter: isDartFile),
      DeprecatedRemover(),
      args: args,
    );
