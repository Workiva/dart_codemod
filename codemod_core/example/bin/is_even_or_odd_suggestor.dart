import 'package:codemod_core/codemod_core.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart';

// ignore: avoid_relative_lib_imports
import '../lib/src/suggestors/is_even_or_odd_suggestor.dart';

/// To run this example:
///     $ cd example/bin
///     $ dart is_even_or_odd_suggester.dart
void main(List<String> args) async {
  final paths = filePathsFromGlob(
    Glob(join('fixtures', 'is_even_or_odd_suggestor', '**.dart')),
  );
  final pg = PatchGenerator([IsEvenOrOddSuggestor().call]);
  final changeSets = pg.generate(paths: paths);

  await for (final changeSet in changeSets) {
    /// Change .apply to .applyAndSave to write the changes to disk
    changeSet.apply();
    // changeSet.applyAndSave();
  }
}
