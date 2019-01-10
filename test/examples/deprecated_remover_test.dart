import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

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

void main() {
  group('Examples: DeprecatedRemover', () {
    test('removes deprecated variable', () {
      final sourceFile = SourceFile.fromString('''
// Not deprecated.
var foo = 'foo';
@deprecated
var bar = 'bar';''');
      final expectedOutput = '''
// Not deprecated.
var foo = 'foo';
''';

      final patches = DeprecatedRemover().generatePatches(sourceFile);
      expect(patches, hasLength(1));
      expect(applyPatches(sourceFile, patches), expectedOutput);
    });
  });
}
