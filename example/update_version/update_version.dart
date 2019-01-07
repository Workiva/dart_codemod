import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

/// Suggestor that finds all variable declarations with the name `version` and
/// updates their values to the given [newVersion].
///
///     runInteractiveCodemod(
///       FileQuery.cwd(pathFilter: isDartFile),
///       UpdateVersionSuggestor('2.0.0'),
///     );
class UpdateVersionSuggestor extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin {
  /// The new version string value to which all `version` variable declarations
  /// should be updated.
  final String newVersion;

  UpdateVersionSuggestor(this.newVersion);

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.name == 'version') {
      yieldPatch(
        node.initializer.offset,
        node.initializer.end,
        "'$newVersion'",
      );
    }
  }
}
