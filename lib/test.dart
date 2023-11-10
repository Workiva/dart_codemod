import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'src/file_context.dart';
import 'src/suggestor.dart';
import 'src/util.dart';

export 'src/util.dart' show applyPatches;

/// Uses [suggestor] to generate a stream of patches for [context] and returns
/// what the resulting file contents would be after applying all of them.
///
/// Use this to test that a suggestor produces the expected result:
///     test('MySuggestor', () async {
///       var context = await fileContextForTest('foo.dart', 'library foo;');
///       var suggestor = MySuggestor();
///       var expectedOutput = '...';
///       expectSuggestorGeneratesPatches(suggestor, context, expectedOutput);
///     });
void expectSuggestorGeneratesPatches(
    Suggestor suggestor, FileContext context, dynamic resultMatcher) {
  expect(
      suggestor(context)
          .toList()
          .then((patches) => applyPatches(context.sourceFile, patches)),
      completion(resultMatcher));
}

/// Creates a temporary file with the given [name] and [sourceText] using the
/// `test_descriptor` package, sets up analysis for that file, and returns a
/// [FileContext] wrapper around it.
///
/// Use this to setup tests for [Suggestor]s:
///     test('My suggestor', () async {
///       var context = await fileContextForTest('foo.dart', 'library foo; // etc');
///       var patches = MySuggestor().generatePatches(context);
///       expect(patches, ...);
///     });
///
/// See also: [PackageContextForTest] if testing [Suggestor]s that need a fully
/// resolved AST from the analyzer.
Future<FileContext> fileContextForTest(String name, String sourceText) async {
  // Use test_descriptor to create the file in a temporary directory
  d.Descriptor descriptor;
  final segments = p.split(name);
  // Last segment should be the file
  descriptor = d.file(segments.last, sourceText);
  // Any preceding segments (if any) are directories
  for (final dir in segments.reversed.skip(1)) {
    descriptor = d.dir(dir, [descriptor]);
  }
  await descriptor.create();

  // Setup analysis for this file
  final path = p.canonicalize(d.path(name));
  final collection = AnalysisContextCollection(includedPaths: [path]);

  return FileContext(path, collection, root: d.sandbox);
}

/// Creates a temporary directory with a pubspec using the `test_descriptor`
/// package, installs dependencies with `dart pub get`, and sets up an analysis
/// context for the package.
///
/// Source files can then be added to the package with [addFile], which will
/// return a [FileContext] wrapper for use in tests.
///
/// Use this to setup tests for [Suggestor]s that require the resolved AST, like
/// the [AstVisitingSuggestor] when `shouldResolveAst()` returns true. Doing so
/// will enable the analyzer to resolve imports and symbols from other source
/// files and dependencies.
///     test('MySuggestor', () async {
///       var pkg = await PackageContextForTest.fromPubspec('''
///     name: pkg
///     version: 0.0.0
///     environment:
///       sdk: '>=3.0.0 <4.0.0'
///     dependencies:
///       meta: ^1.0.0
///     ''');
///       var context = await pkg.addFile('''
///     import 'package:meta/meta.dart';
///     @visibleForTesting var foo = true;
///     ''');
///       var suggestor = MySuggestor();
///       var expectedOutput = '...';
///       expectSuggestorGeneratesPatches(suggestor, context, expectedOutput);
///     });
class PackageContextForTest {
  final AnalysisContextCollection _collection;
  final String _name;
  final String _root;
  static int _fileCounter = 0;
  static int _packageCounter = 0;

  /// Creates a temporary directory named [dirName] using the `test_descriptor`
  /// package, installs dependencies with `dart pub get`, sets up an analysis
  /// context for the package, and returns a [PackageContextForTest] wrapper
  /// that allows you to add source files to the package and use them in tests.
  ///
  /// If [dirName] is null, a unique name will be generated.
  ///
  /// Throws an [ArgumentError] if it fails to install dependencies.
  static Future<PackageContextForTest> fromPubspec(
    String pubspecContents, [
    String? dirName,
  ]) async {
    dirName ??= 'package_${_packageCounter++}';

    await d.dir(dirName, [
      d.file('pubspec.yaml', pubspecContents),
    ]).create();

    final root = p.canonicalize(d.path(dirName));
    final pubGet =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: root);
    if (pubGet.exitCode != 0) {
      printOnFailure('''
PROCESS: dart pub get
WORKING DIR: $root
STDOUT:
${pubGet.stdout}
STDERR:
${pubGet.stderr}
''');
      throw ArgumentError('Failed to install dependencies from given pubspec');
    }
    final collection = AnalysisContextCollection(includedPaths: [root]);
    return PackageContextForTest._(dirName, root, collection);
  }

  PackageContextForTest._(this._name, this._root, this._collection);

  /// Creates a temporary file at the given [path] (relative to the root of this
  /// package) with the given [sourceText] using the `test_descriptor` package
  /// and returns a [FileContext] wrapper around it.
  ///
  /// If [path] is null, a unique filename will be generated.
  ///
  /// The returned [FileContext] will use the analysis context for this whole
  /// package rather than just this file, which enables testing of [Suggestor]s
  /// that require the resolved AST.
  ///
  /// See [PackageContextForTest] for an example.
  Future<FileContext> addFile(String sourceText, [String? path]) async {
    path ??= 'test_${_fileCounter++}.dart';

    // Use test_descriptor to create the file in a temporary directory
    d.Descriptor descriptor;
    final segments = p.split(path);
    // Last segment should be the file
    descriptor = d.file(segments.last, sourceText);
    // Any preceding segments (if any) are directories
    for (final dir in segments.reversed.skip(1)) {
      descriptor = d.dir(dir, [descriptor]);
    }
    // Add the root directory.
    descriptor = d.dir(_name, [descriptor]);

    await descriptor.create();
    final canonicalizedPath = p.canonicalize(p.join(d.sandbox, _name, path));
    return FileContext(canonicalizedPath, _collection, root: _root);
  }
}
