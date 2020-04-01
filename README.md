# codemod for Dart

[![Pub](https://img.shields.io/pub/v/codemod.svg)](https://pub.dartlang.org/packages/codemod)
[![Build Status](https://travis-ci.org/Workiva/dart_codemod.svg?branch=master)](https://travis-ci.org/Workiva/dart_codemod)

A library that makes it easy to write and run automated code modifications
on a codebase. Primarily geared towards updating/refactoring Dart code by
leveraging the [analyzer][analyzer] package's APIs for parsing and traversing
the AST.

Inspired by and based on [Facebook's `codemod` library][facebook-codemod].

## Demo

![demo](images/demo.gif)

## How It Works

The end goal of this library is to enable you to easily and automatically
apply code modifications and refactors via an interactive CLI. To that end,
the following function is provided:

```dart
int runInteractiveCodemod(Iterable<File> files, Suggestor suggestor);
```

Calling this will tell codemod run the `suggestor` on each file in `files`. For
each file, the suggestor will return a list of patches that should be suggested
to the user. As patches are suggested and accepted by the user, codemod handles
applying them to the files and writing the result to disk.

## Writing a Suggestor

This library provides `Suggestor`, but it is just an interface with two methods:

```dart
abstract class Suggestor {
  bool shouldSkip(String sourceFileContents);
  Iterable<Patch> generatePatches(SourceFile sourceFile);
}
```

Codemod will read the contents of each file returned from the query and first
pass it to `shouldSkip()`. This provides a way to short-circuit the potentially
expensive `generatePatches()` method if need be.

If not skipped, the file contents will be passed to `generatePatches()` in the
form of a [`SourceFile` from the `source_span` package][SourceFile]. Operating
on this model makes it easy to create patches at specific offsets within the
file.

### Suggestor Example: Insert License Headers

The following suggestor checks each file for the expected license header, and if
missing, yields a `Patch` that inserts it at the beginning of the file.

```dart
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

final String licenseHeader = '''
// Lorem ispum license.
// 2018-2019
''';

class LicenseHeaderInserter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) =>
      sourceFileContents.trimLeft().startsWith(licenseHeader);

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    yield Patch(
      sourceFile,
      // The span across which the patch should be applied.
      sourceFile.span(
        // Start offset.
        // 0 means "insert at the beginning of the file."
        0,
        // End offset.
        // Using the same offset as the start offset here means that the patch
        // is being inserted at this point instead of replacing a span of text.
        0,
      ),
      // Text to insert.
      licenseHeader,
    );
  }
}
```

### Suggestor Example: Regex Substitution

Regex substitutions are also a common strategy for codemods and are sufficient
for simple changes. The following suggestor updates a version constraint for the
`codemod` package in a `pubspec.yaml`:

```dart
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

/// Pattern that matches a dependency version constraint line for the `codemod`
/// package, with the first capture group being the constraint.
final RegExp pattern = RegExp(
  r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
  multiLine: true,
);

/// The version constraint that `codemod` entries should be updated to.
const String targetConstraint = '^1.0.0';

class RegexSubstituter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) => false;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    for (final match in pattern.allMatches(contents)) {
      final line = match.group(0);
      final constraint = match.group(1);
      final updated = line.replaceFirst(constraint, targetConstraint) + '\n';

      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        updated,
      );
    }
  }
}
```

### Suggestor Example: AST Visitor

Regexes and custom parsing can get you pretty far, but using the
[analyzer][analyzer]'s visitor pattern to traverse the parsed AST is a much more
robust option and allows for the creation of very powerful codemods with
relatively little effort.

Consider the following suggestor that removes all deprecated declarations
(i.e. classes, constructors, variables, methods, etc.):

```dart
import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

class DeprecatedRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');

  @override
  visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the node by replacing the span from its start offset to its end
      // offset with an empty string.
      yieldPatch(node.offset, node.end, '');
    }
  }
}
```

In this example, the suggestor extends the `GeneralizingAstVisitor` which allows
it to target all nodes that could be deprecated with a single visit method. Then
it's just a matter of checking for either the `@Deprecated()` or `@deprecated()`
annotation and yielding a patch with an empty string across the entire node,
which is effectively a deletion.

You may notice that in this example, the suggestor is no longer implementing
`generatePatches()` – instead, we use the `AstVisitingSuggestorMixin`. This
mixin handles parsing the AST for the given `SourceFile` and starting the
visitor pattern so that all you have to do is override the applicable `visit`
methods.

Additionally, although the `GeneralizingAstVisitor` was the appropriate choice
for this suggestor, any `AstVisitor` will work. Choose whichever one fits the
job.

> If you're not familiar with the analyzer API, in particular the `AstNode`
> class hierarchy and the `AstVisitor` pattern, it may be a good opportunity to
> browse the analyzer source code or look at the AST visiting suggestor codemods
> that are linked below in the [references section](#references) to see what is
> possible with this approach.

## Running a Codemod

All you need to run a codemod is:

1. A set of files to be read.

    You can create this `Iterable<String>` input however you like. An easy
    option is to use `Glob` from `package:glob` with the `filePathsFromGlob()`
    util method from this package. Globs make it easy to query for files
    recursively, and `filePathsFromGlob()` will filter out hidden files by
    default:

    ```dart
    filePathsFromGlob(Glob('**.dart', recursive: true))
    ```

2. A `Suggestor` to suggest patches on each file.

3. A `.dart` file with a `main()` block that calls `runInteractiveCodemod()`.

If we were to run the 3 suggestor examples from above, it would like like so:

**Regex Substituter:**

```dart
import 'dart:io';
import 'package:codemod/codemod.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    ['pubspec.yaml'],
    RegexSubstituter(),
    args: args,
  );
}
```

**License Header Inserter:**

```dart
import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    filePathsFromGlob(Glob('**.dart', recursive: true)),
    LicenseHeaderInserter(),
    args: args,
  );
}
```

**Deprecated Remover:**

```dart
import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    filePathsFromGlob(Glob('**.dart', recursive: true)),
    DeprecatedRemover(),
    args: args,
  );
}
```

Run the `.dart` file directly or package it up as an executable and publish it
on pub!

## Additional Options

To facilitate the creation of more complex codemods, two additional pieces are
provided by this library:

- Aggregate multiple suggestors into a single suggestor with
  `AggregateSuggestor`:

    ```dart
    import 'dart:io';

    import 'package:codemod/codemod.dart';

    void main(List<String> args) {
      exitCode = runInteractiveCodemod(
        [...], // input files
        AggregateSuggestor([
          SuggestorA(),
          SuggestorB(),
        ]),
      );
    }
    ```

- Run multiple suggestors (or aggregate suggestors) sequentially:

    ```dart
    import 'dart:io';

    import 'package:codemod/codemod.dart';

    void main(List<String> args) {
      exitCode = runInteractiveCodemodSequence(
        [...], // input files
        [
          PhaseOneSuggestor(),
          PhaseTwoSuggestor(),
        ],
        args: args,
      );
    }
    ```

    This can be useful if a certain modification needs to happen prior to
    another, or if you need to use a "collector" pattern wherein the first
    suggestor collects information from the files that a second suggestor will
    then use to suggest patches.

## Testing Suggestors

Testing suggestors is relatively easy for two reasons:

- The API surface area is small (most of the time you only need to test the
  `generatePatches()` method)

- The list of patches returned by `generatePatches()` can be applied to the
  input `SourceFile` to obtain a `String` output, which is trivial to examine in
  order to assert correctness.

In other words, all you need to do is determine a sufficient set of inputs and
their respective expected outputs.

To help out, this library exports the `applyPatches(sourceFile, patches)`
function that it uses internally to make it easy to compare the result of a
suggestor's patches to the expected output.

Let's use the `DeprecatedRemover` suggestor example from above to demonstrate
testing:

```dart
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  group('DeprecatedRemover', () {
    test('removes deprecated variable', () {
      final sourceFile = SourceFile.fromString('''
// Not deprecated.
var foo = 'foo';
@deprecated
var bar = 'bar';''');
      final expectedOutput = '''
// Not deprecated.
var foo = 'foo';
''';

      final patches = DeprecatedRemover().generatePatches(sourceFile);
      expect(patches, hasLength(1));
      expect(applyPatches(sourceFile, patches), expectedOutput);
    });
  });
}
```

## References

- [over_react_codemod][over_react_codemod]: codemods for the `over_react` UI
  library

## Credits

- [facebook/codemod][facebook-codemod]: python codemod tool that this library
  was based on

---

## Contributing

- **Run tests:** `pub run test`

- **Format code:** `pub run dart_dev format`

- **Run static analysis:** `dartanalyzer .`

[analyzer]: https://pub.dartlang.org/packages/analyzer
[facebook-codemod]: https://github.com/facebook/codemod
[over_react_codemod]: https://github.com/Workiva/over_react_codemod
[SourceFile]: https://pub.dartlang.org/documentation/source_span/latest/source_span/SourceFile-class.html
