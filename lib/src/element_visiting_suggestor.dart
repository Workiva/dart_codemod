import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'file_context.dart';
import 'patch.dart';

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
  final _patches = <Patch>{};

  /// The context helper for the file currently being visited.
  FileContext get context => _context;
  FileContext _context;

  Stream<Patch> call(FileContext context) async* {
    if (shouldSkip(context)) return;

    final resolvedLibrary = await context.getResolvedLibrary();
    _patches.clear();
    _context = context;
    resolvedLibrary.element.accept(this);
    // Force the copying of this list, otherwise it would be a lazy iterable
    // mapped to the field on this class that will change on the next call.
    final patches = _patches.toList();
    yield* Stream.fromIterable(patches);
  }

  /// Returns the [AstNode] associated with the given [element] declaration,
  /// which is useful for getting the start and end offsets for elements and
  /// using them to yield patches.
  ///
  /// The returned node will be unresolved.
  ///
  /// Returns null if [element] is synthetic.
  T elementNode<T extends AstNode>(Element element) => element.session
      .getParsedLibraryByElement(element.library)
      .getElementDeclaration(element)
      ?.node;

  /// Whether the file represented by [context] should be parsed and visited.
  ///
  /// Subclasses can override this to skip all work for a file based on its
  /// contents if needed.
  bool shouldSkip(FileContext context) => false;

  void yieldPatch(String updatedText, int startOffset, [int endOffset]) {
    _patches.add(Patch(updatedText, startOffset, endOffset));
  }
}
