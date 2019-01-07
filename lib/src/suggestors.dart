import 'package:analyzer/analyzer.dart';
import 'package:source_span/source_span.dart';

import 'patch.dart';

abstract class Suggestor {
  bool shouldSkip(String sourceFileContents);

  Iterable<Patch> generatePatches(SourceFile sourceFile);
}

class AggregateSuggestor implements Suggestor {
  final List<Suggestor> suggestors;

  AggregateSuggestor(this.suggestors);

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    for (final suggestor in suggestors) {
      yield* suggestor.generatePatches(sourceFile);
    }
  }

  @override
  bool shouldSkip(String sourceFileContents) =>
      suggestors.every((s) => s.shouldSkip(sourceFileContents));
}

mixin AstVisitingSuggestorMixin implements AstVisitor, Suggestor {
  final List<Patch> _patches = [];

  SourceFile _sourceFile;
  SourceFile get sourceFile => _sourceFile;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    _patches.clear();
    _sourceFile = sourceFile;

    final compilationUnit = parseCompilationUnit(sourceFile.getText(0));
    compilationUnit.accept(this);
    yield* _patches;
  }

  bool shouldSkip(_) => false;

  void yieldPatch(int startOffset, int endOffset, String updatedText) {
    if (sourceFile == null) {
      throw new StateError('yieldPatch() called outside of a visiting context. '
          'Ensure that it is only called inside an AST visitor method.');
    }
    _patches.add(Patch(
      sourceFile,
      sourceFile.span(startOffset, endOffset),
      updatedText,
    ));
  }
}
