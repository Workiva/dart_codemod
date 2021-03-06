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

import 'aggregate_suggestors.dart';
import 'ast_visiting_suggestor.dart';
import 'file_context.dart';
import 'patch.dart';
import 'run_interactive_codemod.dart'
    show runInteractiveCodemod, runInteractiveCodemodSequence;

/// Function signature representing the core driver of a "codemod" (code
/// modification).
///
/// A suggestor's job is to receive a [FileContext] and generate [Patch]es on
/// that file. A suggestor may generate zero, one, or multiple [Patch]es on each
/// input file.
///
/// A suggestor is run via one of the two "runner" methods provided by this
/// library:
/// - [runInteractiveCodemod]
/// - [runInteractiveCodemodSequence]
///
/// During this codemod process, the runner will create the context object for
/// each file and pass it to the suggestor. If this function throws at any
/// point, the runner will log the exception and return early with a non-zero
/// exit code.
///
/// For simple suggestors, it may be sufficient to write a function that
/// operates on the source text manually (potentially by using regexes). Here's
/// an example of this:
///     import 'package:codemod/codemod.dart';
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
///     Stream<Patch> regexSubstituter(FileContext context) async* {
///       for (final match in pattern.allMatches(context.sourceText)) {
///         final line = match.group(0);
///         final constraint = match.group(1);
///         final updated = line.replaceFirst(constraint, targetConstraint) + '\n';
///
///         yield Patch(updated, match.start, match.end);
///       }
///     }
///
/// If, however, your aim is to modify Dart code, using the analyzer's visitor
/// pattern to traverse the AST or elements is a much more robust option and
/// allows for the creation of very powerful codemods with relatively little
/// effort. See [AstVisitingSuggestor].
///
/// Finally, it's recommended that you keep your suggestors simple. Rather than
/// writing a single suggestor that performs several modifications that aren't
/// strictly related, a better option is to write several small, focused
/// suggestors that you then combine using [aggregateSuggestors] to be run as a
/// single "codemod". This makes maintenance and testing much easier.
typedef Suggestor = Stream<Patch> Function(FileContext context);
