import 'package:meta/meta.dart';

import 'file_context.dart';
import 'patch.dart';
import 'suggestor.dart';

/// Aggregates multiple [Suggestor]s into a single suggestor that yields the
/// collective set of [Patch]es generted by each individual suggestor for each
/// source file.
///     runInteractiveCodemod(
///       filesFromGlob(Glob('**.dart', recursive: true)),
///       AggregateSuggestor([
///         SuggestorA(),
///         SuggestorB(),
///         SuggestorC(),
///         ...
///       ]),
///     );
class AggregateSuggestor implements Suggestor {
  final Iterable<Suggestor> _suggestors;

  AggregateSuggestor(Iterable<Suggestor> suggestors) : _suggestors = suggestors;

  @visibleForTesting
  Iterable<Suggestor> get aggregatedSuggestors => _suggestors.toList();

  @override
  Stream<Patch> generatePatches(FileContext context) async* {
    for (final suggestor in _suggestors) {
      yield* suggestor.generatePatches(context);
    }
  }
}
