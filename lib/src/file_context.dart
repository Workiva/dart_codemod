import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'patch.dart';

/// A helper class for a file located at [path] that provides access to its
/// contents and analyzed formats like [CompilationUnit] and [LibraryElement].
class FileContext {
  final AnalysisContextCollection _analysisContextCollection;

  /// This file's absolute path.
  final String path;

  /// This file's path relative to [root].
  final String relativePath;

  /// The path to the working directory from which this file was discovered.
  ///
  /// Defaults to current working directory.
  final String root;

  FileContext(this.path, this._analysisContextCollection, {String? root})
      : root = root ?? p.current,
        relativePath = p.relative(path, from: root) {
    if (!p.isAbsolute(path)) {
      throw ArgumentError.value(path, 'path', 'must be absolute.');
    }
  }

  /// A representation of this file that makes it easy to reference spans of
  /// text, which is useful for the creation of [SourcePatch]es.
  late final SourceFile sourceFile =
      SourceFile.fromString(sourceText, url: Uri.file(path));

  /// The contents of this file.
  late final String sourceText = File(path).readAsStringSync();

  /// Uses the analyzer to resolve and return the library result for this file,
  /// which includes the [LibraryElement].
  Future<ResolvedLibraryResult?> getResolvedLibrary() async {
    final result = await _analysisContextCollection
        .contextFor(path)
        .currentSession
        .getResolvedLibrary(path);
    return result is ResolvedLibraryResult ? result : null;
  }

  /// Uses the analyzer to resolve and return the AST result for this file,
  /// which includes the [CompilationUnit].
  ///
  /// If the fully resolved AST is not needed, use the much faster
  /// [getUnresolvedUnit].
  Future<ResolvedUnitResult?> getResolvedUnit() async {
    final result = await _analysisContextCollection
        .contextFor(path)
        .currentSession
        .getResolvedUnit(path);
    return result is ResolvedUnitResult ? result : null;
  }

  /// Returns the unresolved AST for this file.
  ///
  /// If the fully resolved AST is needed, use [getResolvedUnit].
  CompilationUnit getUnresolvedUnit() {
    final result =
        parseString(content: sourceText, path: path, throwIfDiagnostics: false);
    if (result.errors.isEmpty) return result.unit;

    // Errors thrown by parseString don't include the filename, and result in
    // the codemod halting without indicating which file it failed on.
    // To aid in debugging, we'll construct the error message the same way
    // parseString does, but also include the path to the file.
    var buffer = StringBuffer();
    for (var error in result.errors) {
      var location = result.lineInfo.getLocation(error.offset);
      buffer.writeln('  ${error.errorCode.name}: ${error.message} - '
          '${location.lineNumber}:${location.columnNumber}');
    }
    throw ArgumentError(
        'File "${relativePath}" produced diagnostics when parsed:\n$buffer');
  }
}
