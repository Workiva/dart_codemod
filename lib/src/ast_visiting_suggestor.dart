import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:codemod/src/file_context.dart';
import 'package:logging/logging.dart';

import 'patch.dart';
import 'suggestor.dart';

final _log = Logger('AstVisitingSuggestor');

/// Mixin that implements the [Suggestor] interface and makes it easier to write
/// suggestors that operate as an [AstVisitor].
///
/// With the [AstVisitor] pattern, you can override the applicable `visit`
/// methods to find what you're looking for and generate patches at specific
/// locations in the source using the offsets provided by the [AstNode]s and
/// tokens therein.
///
/// Note that this mixin provides an implementation of [generatePatches] that
/// should not need to be overridden except for performance optimization reasons
/// like avoiding analysis on certain files.
///
/// By default, this operates on the unresolved AST. Subclasses that need a
/// fully resolved AST (e.g. for static typing info) should override
/// [shouldResolveAst] to return true.
///
/// The easiest way to understand this pattern is to see an example. Consider
/// the following suggestor that aims to remove all deprecated declarations:
///
///     import 'package:analyzer/analyzer.dart';
///     import 'package:codemod/codemod.dart';
///
///     class DeprecatedRemover extends GeneralizingAstVisitor
///         with AstVisitingSuggestor {
///
///       static bool isDeprecated(AnnotatedNode node) =>
///           node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');
///
///       @override
///       visitDeclaration(Declaration node) {
///         if (isDeprecated(node)) {
///           // Remove the node by replacing the span from its start offset to its end
///           // offset with an empty string.
///           yieldPatch('', node.offset, node.end);
///         }
///       }
///     }
mixin AstVisitingSuggestor<R> on AstVisitor<R> {
  final _patches = <Patch>{};

  /// The context helper for the file currently being visited.
  FileContext get context {
    if (_context != null) return _context!;
    throw StateError('context accessed outside of a visiting context. '
        'Ensure that your suggestor only accesses `this.context` inside an AST visitor method.');
  }

  FileContext? _context;

  Stream<Patch> call(FileContext context) async* {
    if (shouldSkip(context)) return;

    CompilationUnit unit;
    if (shouldResolveAst(context)) {
      var result = await context.getResolvedUnit();
      if (result == null) {
        _log.warning(
            'Could not get resolved unit for "${context.relativePath}"');
        return;
      }
      unit = result.unit;
    } else {
      unit = context.getUnresolvedUnit();
    }

    _patches.clear();
    _context = context;
    unit.accept(this);
    // Force the copying of this list, otherwise it would be a lazy iterable
    // mapped to the field on this class that will change on the next call.
    final patches = _patches.toList();
    _context = null;

    yield* Stream.fromIterable(patches);
  }

  /// Whether the AST should be resolved for the file represented by [context].
  ///
  /// Note that resolving the AST is much slower.
  bool shouldResolveAst(FileContext context) => false;

  /// Whether the file represented by [context] should be parsed and visited.
  ///
  /// Subclasses can override this to skip all work for a file based on its
  /// contents if needed.
  bool shouldSkip(FileContext context) => false;

  void yieldPatch(String updatedText, int startOffset, [int? endOffset]) {
    _patches.add(Patch(updatedText, startOffset, endOffset));
  }
}
