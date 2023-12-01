import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:path/path.dart';

import 'change_set.dart';
import 'exceptions.dart';
import 'file_context.dart';
import 'logging.dart';
import 'patch.dart';
import 'suggestor.dart';

typedef Path = String;

/// The [PatchGenerator] is the main entry point to codemod_core.
///
/// The [PatchGenerator] creates [ChangeSet]s based on a set of
/// [Suggestor]s that you supply.
///
/// You can then 'apply' those changes to the Dart Libraries.
/// ```dart
/// void main(List<String> args) async {
///     /// Identify the that we want to add a license header to
///     var paths = filePathsFromGlob(
///     Glob(join('fixtures', 'license_header', '**.dart')),
///   );
///
///   /// Instantiate the [PatchGenerator] with the set of
///   /// Suggestors we are going to using to generate [ChangeSet]s.
///   var pg = PatchGenerator([licenseHeaderInserter]);
///
///   /// Generate the [ChangeSet]s.
///   var changeSets = pg.generate(paths: paths);
///
///   /// Apply the [ChangeSet] to the code.
///   await for (var changeSet in changeSets) {
///     /// Change .apply to .applyAndSave to write the changes to disk
///     /// overwritting the existing .dart source files.
///     /// ---------------------------------------
///     /// WARNING: backup your source first!!!!
///     /// ---------------------------------------
///     var patchedSource = changeSet.apply();
///     // changeSet.applyAndSave();
///   }
/// }
/// ```dart
///
class PatchGenerator {
  PatchGenerator(this.suggestors);

  Iterable<Suggestor> suggestors;

  /// Generates a [Stream] of [ChangeSet] objects based on the passed
  /// [suggestors] that need to be applied to the source.
  /// Throws a [PatchException] or any exception thrown by the [Suggestor]s.
  Stream<ChangeSet> generate(
      {required Iterable<Path> paths, List<Path>? destPaths}) async* {
    _validateArgs(paths, destPaths);

    final canonicalizedPaths = paths.map(canonicalize).toList();

    final collection =
        AnalysisContextCollection(includedPaths: canonicalizedPaths);

    for (var i = 0; i < canonicalizedPaths.length; i++) {
      final canonicalizedPath = canonicalizedPaths[i];

      // test goes here
      // and here.
      final context = FileContext(canonicalizedPath, collection,
          destPath: destPaths == null ? null : destPaths[i]);

      final patches = <SourcePatch>[];
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
                  '''Empty patch suggested: $patch - this is probably a bug a sugestor''');
            }
          }
          patches.addAll(patchSet);
          // ignore: avoid_catches_without_on_clauses
        } catch (e, stackTrace) {
          logger.severe(
              'Suggestor.generatePatches() threw unexpectedly.', e, stackTrace);
          rethrow;
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
