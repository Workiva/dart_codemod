// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import 'patch.dart';
import 'run_interactive_codemod.dart'
    show runInteractiveCodemod, runInteractiveCodemodSequence;

/// Interface representing the core driver of a "codemod" (code modification).
///
/// A suggestor's job is to receive a [SourceFile] and generate [Patch]es on
/// the file via its [generatePatches] method. A suggestor may generate zero,
/// one, or multiple [Patch]es on each input file.
///
/// A suggestor is run via one of the two "runner" methods provided by this
/// library:
/// - [runInteractiveCodemod]
/// - [runInteractiveCodemodSequence]
///
/// During this codemod process, the runner will read the contents of each file
/// returned from the query and first pass it to [shouldSkip]. This provides a
/// way to short-circuit the potentially expensive [generatePatches] method if
/// need be.
///
/// If not skipped, the file contents will be passed to [generatePatches] in
/// the form of a [SourceFile] from the `source_span` package. Operating on this
/// model makes it easy to create [Patch]es at specific offsets within the file.
///
/// If either of these methods throw at any point, the runner will log the
/// exception and will return early with a non-zero exit code.
///
/// For simple suggestors, it may be sufficient to implement this interface
/// directly and operate on the source text manually (potentially by using
/// regexes). An example of this would look like so:
///     import 'package:codemod/codemod.dart';
///     import 'package:source_span/source_span.dart';
///
///     /// Pattern that matches a dependency version constraint line for the `codemod`
///     /// package, with the first capture group being the constraint.
///     final RegExp pattern = RegExp(
///       r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
///       multiLine: true,
///     );
///
///     /// The version constraint that `codemod` entries should be updated to.
///     const String targetConstraint = '^1.0.0';
///
///     class RegexSubstituter implements Suggestor {
///       @override
///       bool shouldSkip(String sourceFileContents) => false;
///
///       @override
///       Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
///         final contents = sourceFile.getText(0);
///         for (final match in pattern.allMatches(contents)) {
///           final line = match.group(0);
///           final constraint = match.group(1);
///           final updated = line.replaceFirst(constraint, targetConstraint) + '\n';
///
///           yield Patch(
///             sourceFile,
///             sourceFile.span(match.start, match.end),
///             updated,
///           );
///         }
///       }
///     }
///
/// If, however, your aim is to modify Dart code, using the analyzer's visitor
/// pattern to traverse the parsed AST is a much more robust option and allows
/// for the creation of very powerful codemods with relatively little effort.
/// See [AstVisitingSuggestorMixin] for more information.
///
/// Finally, it's recommended that you keep your suggestors simple. Rather than
/// writing a single suggestor that performs several modifications that aren't
/// strictly related, a better option is to write several small, focused
/// suggestors that you then combine into an [AggregateSuggestor] to be run as
/// a single "codemod". This makes maintenance and testing much easier.
abstract class Suggestor {
  /// Should return true if it can be determined from the [sourceFileContents]
  /// that the file will not yield any [Patch]es, and false otherwise.
  ///
  /// Use this method as way to avoid having [generatePatches] called
  /// unnecessarily, which may be beneficial if it is an expensive operation.
  ///
  /// If this is not a concern, subclasses should implement this method to
  /// always return false:
  ///     @override
  ///     bool shouldSkip(_) => false;
  bool shouldSkip(String sourceFileContents);

  /// Should return [Patch]es for the given [sourceFile] that will then be shown
  /// to the user via the CLI to be accepted or skipped.
  Iterable<Patch> generatePatches(SourceFile sourceFile);
}

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
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final sourceFileContents = sourceFile.getText(0);
    final unskippedSuggestors = _suggestors
        .where((suggestor) => !suggestor.shouldSkip(sourceFileContents));

    for (final suggestor in unskippedSuggestors) {
      yield* suggestor.generatePatches(sourceFile);
    }
  }

  @override
  bool shouldSkip(_) => false;
}

/// Mixin that implements the [Suggestor] interface and makes it easier to write
/// suggestors that operate as an [AstVisitor].
///
/// With the [AstVisitor] pattern, you can override the applicable `visit`
/// methods to find what you're looking for and generate patches at specific
/// locations in the source using the offsets provided by the [AstNode]s and
/// tokens therein.
///
/// Note that this mixin provides an implementation of [generatePatches] that
/// should not need to be overridden as well as a default implementation of
/// [shouldSkip] that always returns false. Subclasses may override [shouldSkip]
/// if it is beneficial to do so.
///
/// The easiest way to understand this pattern is to see an example. Consider
/// the following suggestor that aims to remove all deprecated declarations:
///     import 'package:analyzer/analyzer.dart';
///     import 'package:codemod/codemod.dart';
///
///     class DeprecatedRemover extends GeneralizingAstVisitor
///         with AstVisitingSuggestorMixin {
///
///       static bool isDeprecated(AnnotatedNode node) =>
///           node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');
///
///       @override
///       visitDeclaration(Declaration node) {
///         if (isDeprecated(node)) {
///           // Remove the node by replacing the span from its start offset to its end
///           // offset with an empty string.
///           yieldPatch(node.offset, node.end, '');
///         }
///       }
///     }
mixin AstVisitingSuggestorMixin<R> on AstVisitor<R> implements Suggestor {
  final _patches = <Patch>{};

  SourceFile _sourceFile;
  SourceFile get sourceFile => _sourceFile;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    _patches.clear();
    _sourceFile = sourceFile;

    final parsed =
        parseString(content: sourceFile.getText(0), path: '${sourceFile.url}');
    parsed.unit.accept(this);
    yield* _patches;
  }

  @override
  bool shouldSkip(_) => false;

  void yieldPatch(int startOffset, int endOffset, String updatedText) {
    if (sourceFile == null) {
      throw StateError('yieldPatch() called outside of a visiting context. '
          'Ensure that it is only called inside an AST visitor method.');
    }
    _patches.add(Patch(
      sourceFile,
      sourceFile.span(startOffset, endOffset),
      updatedText,
    ));
  }
}
