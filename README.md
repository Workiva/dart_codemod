# codemod for Dart

[![Pub](https://img.shields.io/pub/v/codemod.svg)](https://pub.dartlang.org/packages/codemod)
[![Dart CI](https://github.com/Workiva/dart_codemod/workflows/Dart%20CI/badge.svg?branch=master)](https://github.com/Workiva/dart_codemod/actions?query=workflow%3A%22Dart+CI%22+branch%3Amaster)

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
Future<int> runInteractiveCodemod(Iterable<File> files, Suggestor suggestor);
```

Calling this will tell codemod run the `suggestor` on each file in `files`. For
each file, the suggestor will return a stream of patches that should be
suggested to the user. As patches are suggested and accepted by the user,
codemod handles applying them to the files and writing the result to disk.

## Writing a Suggestor

```dart
typedef Suggestor = Stream<Patch> Function(FileContext context);
```

Suggestor is just a typedef, so any function with that signature or class that
overrides `call()` with that signature will work.

Codemod creates the `FileContext` instance for each file path it is given and
passes it to the suggestor; it is just a helper class with methods for reading
the file's contents and analyzing it with [`package:analyzer`][analyzer].

The context can be used to get the file's contents (`context.sourceText`), a
`SourceFile` representation (`context.sourceFile`) for easily referencing spans
of text within the file, or, for Dart files, the analyzed formats like the
`CompilationUnit` (unresolved or resolved) or the fully resolved
`LibraryElement`.

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

Stream<Patch> licenseHeaderInserter(FileContext context) async* {
  // Skip if license header already exists.
  if (context.sourceText.trimLeft().startsWith(licenseHeader)) return;

  yield Patch(
    // Text to insert.
    licenseHeader,
    // Start offset.
    // 0 means "insert at the beginning of the file."
    0,
    // End offset.
    // Using the same offset as the start offset here means that the patch
    // is being inserted at this point instead of replacing a span of text.
    0,
  );
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

Stream<Patch> regexSubstituter(FileContext context) async* {
  for (final match in pattern.allMatches(context.sourceText)) {
    final line = match.group(0);
    final constraint = match.group(1);
    final updated = line.replaceFirst(constraint, targetConstraint) + '\n';

    yield Patch(updated, match.start, match.end);
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

class DeprecatedRemover extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');

  @override
  void visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the node by replacing the span from its start offset to its end
      // offset with an empty string.
      yieldPatch('', node.offset, node.end);
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
`generatePatches()` – instead, we use `AstVisitingSuggestor`. This mixin handles
obtaining the `CompilationUnit` for the given file and starting the visitor
pattern so that all you have to do is override the applicable `visit` methods.

Although the `GeneralizingAstVisitor` was the appropriate choice for this
suggestor, any `AstVisitor` will work. Choose whichever one fits the job.

Note that by default `AstVisitingSuggestor` operates on a Dart file's
_unresolved_ AST, but you can override `shouldResolveAst()` to tell the mixin to
resolve the AST:

```dart
class ExampleSuggestor extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  @override
  bool shouldResolveAst(FileContext context) => true;

  ...
}
```

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

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    ['pubspec.yaml'],
    regexSubstituter,
    args: args,
  );
}
```

**License Header Inserter:**

```dart
import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('**.dart', recursive: true)),
    licenseHeaderInserter,
    args: args,
  );
}
```

**Deprecated Remover:**

```dart
import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('**.dart', recursive: true)),
    DeprecatedRemover(),
    args: args,
  );
}
```

Run the `.dart` file directly or package it up as an executable and publish it
to pub!

## Additional Options

To facilitate the creation of more complex codemods, two additional pieces are
provided by this library:

- Aggregate multiple suggestors into a single suggestor with `aggregate()`:

    ```dart
    import 'dart:io';

    import 'package:codemod/codemod.dart';

    void main(List<String> args) async {
      exitCode = await runInteractiveCodemod(
        [...], // input files
        aggregate([
          suggestorA,
          suggestorB,
        ]),
      );
    }
    ```

- Run multiple suggestors (or aggregate suggestors) sequentially:

    ```dart
    import 'dart:io';

    import 'package:codemod/codemod.dart';

    void main(List<String> args) async {
      exitCode = await runInteractiveCodemodSequence(
        [...], // input files
        [
          phaseOneSuggestor,
          phaseTwoSuggestor,
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
  suggestor function).

- The stream of patches returned by a suggestor can be applied to the source
  file to obtain a `String` output, which can easily be compared against an
  expected output.

In other words, all you need to do is determine a sufficient set of inputs and
their respective expected outputs.

To help out, the `package:codemod/test.dart` library exports a few functions.
These two should be sufficient for writing most suggestor tests:

- `fileContextForTest(name, contents)` for creating a `FileContext` that can be
used as the input for `Suggestor.generatePatches()`
- `expectSuggestorGeneratesPatches(suggestor, context, resultMatcher)` for
asserting that a suggestor produces the expected result for a given input

If, however, you need to examine the generated patches more closely, you can
call a suggestor yourself and then use the `applyPatches(sourceFile, patches)`
function to get the resulting output.

Let's use the `DeprecatedRemover` suggestor example from above to demonstrate
testing:

```dart
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  group('DeprecatedRemover', () {
    test('removes deprecated variable', () async {
      final context = await fileContextForTest('test.dart', '''
// Not deprecated.
var foo = 'foo';
@deprecated
var bar = 'bar';''');
      final expectedOutput = '''
// Not deprecated.
var foo = 'foo';
''';
      expectSuggestorGeneratesPatches(
          DeprecatedRemover(), context, expectedOutput);
    });
  });
}
```

### Testing Suggestors with Resolved AST

The `fileContextForTest()` helper shown above makes it easy to test suggestors
that operate on the _unresolved_ AST, but some suggestors require the _resolved_
AST. For example, a suggestor may need to rename a specific symbol from a specific
package, and so it would need to check the resolved element of a node. This is
only possible if the analysis context is aware of all the relevant files and
package dependencies.

To help with this scenario, the `package:codemod/test.dart` library also exports
a `PackageContextForTest` helper class. This class handles creating a temporary
package directory, installing dependencies, and setting up an analysis context
that has access to the whole package and its dependencies. You can then add
source file(s) and use the wrapping `FileContext`s to test suggestors.

```dart
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  group('AlwaysThrowsFixer', () {
    test('returns Never instead', () async {
      final pkg = await PackageContextForTest.fromPubspec('''
name: pkg
publish_to: none
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  meta: ^1.0.0
''');
      final context = await pkg.addFile('''
import 'package:meta/meta.dart';
@alwaysThrows toss() { throw 'Thrown'; }
''');
      final expectedOutput = '''
import 'package:meta/meta.dart';
Never toss() { throw 'Thrown'; }
''';
      expectSuggestorGeneratesPatches(
          AlwaysThrowsFixer(), context, expectedOutput);
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

- **Run tests:** `dart test`

- **Format code:** `dart format`

- **Run static analysis:** `dart analyze`

[analyzer]: https://pub.dartlang.org/packages/analyzer
[facebook-codemod]: https://github.com/facebook/codemod
[over_react_codemod]: https://github.com/Workiva/over_react_codemod
[SourceFile]: https://pub.dartlang.org/documentation/source_span/latest/source_span/SourceFile-class.html
