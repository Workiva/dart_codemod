import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:codemod_core/src/change_set.dart';
import 'package:path/path.dart';

import 'exceptions.dart';
import 'file_context.dart';
import 'logging.dart';
import 'patch.dart';
import 'suggestor.dart';

typedef Path = String;

class PatchGenerator {
  PatchGenerator(this.suggestors);

  Iterable<Suggestor> suggestors;

  Stream<ChangeSet> generate(
      {required Iterable<Path> paths, List<Path>? destPaths}) async* {
    _validateArgs(paths, destPaths);

    final canonicalizedPaths = paths.map((path) => canonicalize(path)).toList();

    final collection =
        AnalysisContextCollection(includedPaths: canonicalizedPaths);

    for (var i = 0; i < canonicalizedPaths.length; i++) {
      final canonicalizedPath = canonicalizedPaths[i];

      // test goes here
      // and here.
      final context = FileContext(canonicalizedPath, collection,
          destPath: destPaths == null ? null : destPaths[i]);

      var patches = <SourcePatch>[];
      for (final suggestor in suggestors) {
        logger.fine('file: ${context.relativePath}');
        try {
          final patchSet = await suggestor(context)
              .map((p) => SourcePatch.from(p, context.sourceFile))
              .toList();
          for (final patch in patchSet) {
            if (patch.isNoop) {
              // Patch suggested, but without any changes. This is probably an
              // error in the suggestor implementation.
              logger.severe('Empty patch suggested: $patch');
              throw PatchException(
                  'Empty patch suggested: $patch - this is probably a bug a sugestor');
            }
          }
          patches.addAll(patchSet);
        } catch (e, stackTrace) {
          logger.severe(
              'Suggestor.generatePatches() threw unexpectedly.', e, stackTrace);
          throw PatchException(e.toString());
        }
      }
      yield ChangeSet(context.sourceFile, patches,
          destinationPath: context.destPath);
    }
  }

  void _validateArgs(Iterable<Path> paths, Iterable<Path>? destPaths) {
    assert(
      destPaths == null || paths.length == destPaths.length,
      'number of destPaths must be equal to the number of filePaths',
    );
  }
}
