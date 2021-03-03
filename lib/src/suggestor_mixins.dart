import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:codemod/src/file_context.dart';

import 'patch.dart';
import 'suggestor.dart';

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
///         with UnresolvedAstVisitingSuggestor {
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
  final patches = <Patch>{};

  bool shouldResolveAst(FileContext context) => false;

  Stream<Patch> call(FileContext context) async* {
    final unit = shouldResolveAst(context)
        ? (await context.getResolvedUnit()).unit
        : context.getUnresolvedUnit();
    patches.clear();
    unit.accept(this);
    // Call toList() here to force the copying of the list, otherwise it would
    // be a lazy iterable mapped to the field on this class that will change on
    // next usage.
    yield* Stream.fromIterable(patches.toList());
  }

  void yieldPatch(String updatedText, int startOffset, [int endOffset]) {
    patches.add(Patch(updatedText, startOffset, endOffset));
  }
}

/// Mixin that implements the [Suggestor] interface and makes it easier to write
/// suggestors that operate as an [ElementVisitor].
///
/// With the [ElementVisitor] pattern, you can override the applicable `visit`
/// methods to find what you're looking for and generate patches at specific
/// locations in the source using the offsets provided by the [Element]s and
/// tokens therein.
///
/// Note that this mixin provides an implementation of [generatePatches] that
/// should not need to be overridden except for performance optimization reasons
/// like avoiding analysis on certain files.
mixin ElementVisitingSuggestor<R> on ElementVisitor<R> {
  final patches = <Patch>[];

  /// The context helper for the file for which patches are currently being
  /// generated.
  FileContext get context => _context;
  FileContext _context;

  Stream<Patch> suggestor(FileContext context) async* {
    final resolvedLibrary = await context.getResolvedLibrary();
    patches.clear();
    resolvedLibrary.element.accept(this);
    // Call toList() here to force the copying of the list, otherwise it would
    // be a lazy iterable mapped to the field on this class that will change on
    // next usage.
    yield* Stream.fromIterable(patches.toList());
  }

  void yieldPatch(String updatedText, int startOffset, [int endOffset]) {
    patches.add(Patch(updatedText, startOffset, endOffset));
  }
}
