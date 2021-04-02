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
  SourceFile get sourceFile =>
      _sourceFile ??= SourceFile.fromString(sourceText, url: Uri.file(path));
  SourceFile? _sourceFile;

  /// The contents of this file.
  String get sourceText => _contents ??= File(path).readAsStringSync();
  String? _contents;

  /// Uses the analyzer to resolve and return the library result for this file,
  /// which includes the [LibraryElement].
  Future<ResolvedLibraryResult> getResolvedLibrary() =>
      _analysisContextCollection
          .contextFor(path)
          .currentSession
          .getResolvedLibrary(path);

  /// Uses the analyzer to resolve and return the AST result for this file,
  /// which includes the [CompilationUnit].
  ///
  /// If the fully resolved AST is not needed, use the much faster
  /// [getUnresolvedUnit].
  Future<ResolvedUnitResult> getResolvedUnit() => _analysisContextCollection
      .contextFor(path)
      .currentSession
      .getResolvedUnit(path);

  /// Returns the unresolved AST for this file.
  ///
  /// If the fully resolved AST is needed, use [getResolvedUnit].
  CompilationUnit getUnresolvedUnit() =>
      parseString(content: sourceText, path: path).unit;
}
