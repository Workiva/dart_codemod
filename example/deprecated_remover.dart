/// To run this example:
///     $ cd example
///     $ dart deprecated_remover.dart
library dart_codemod.example.deprecated_remover;

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

/// Suggestor that generates deletion patches for all deprecated declarations
/// (i.e. classes, constructors, variables, methods, etc.).
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

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    FileQuery.dir(path: 'deprecated_remover_fixtures/', pathFilter: isDartFile),
    DeprecatedRemover(),
    args: args,
  );
}
