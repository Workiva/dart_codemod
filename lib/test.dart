import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'src/file_context.dart';
import 'src/suggestor.dart';
import 'src/util.dart';

export 'src/util.dart' show applyPatches;

/// Creates a file with the given [name] and [sourceText] using the
/// `test_descriptor` package, sets up analysis for that file, and returns a
/// [FileContext] wrapper around it.
///
/// Use this to setup tests for [Suggestor]s:
///     test('My suggestor', () async {
///       var context = await fileContextForTest('foo.dart', 'library foo; // etc');
///       var patches = MySuggestor().generatePatches(context);
///       expect(patches, ...);
///     });
Future<FileContext> fileContextForTest(String name, String sourceText) async {
  await d.file(name, sourceText).create();
  final path = p.canonicalize(p.join(d.sandbox, name));
  final collection = AnalysisContextCollection(includedPaths: [path]);
  return FileContext(path, collection);
}

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
