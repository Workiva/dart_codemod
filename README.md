# codemod for Dart

[![Pub](https://img.shields.io/pub/v/codemod.svg)](https://pub.dartlang.org/packages/codemod)
[![Dart CI](https://github.com/Workiva/dart_codemod/workflows/Dart%20CI/badge.svg?branch=master)](https://github.com/Workiva/dart_codemod/actions?query=workflow%3A%22Dart+CI%22+branch%3Amaster)

A powerful library for writing and running automated code modifications on a codebase. Primarily geared towards updating and refactoring Dart code by leveraging the [analyzer][analyzer] package's APIs for parsing and traversing the AST.

Inspired by and based on [Facebook's `codemod` library][facebook-codemod].

## Features

- 🚀 **Interactive CLI** - Review and approve changes before applying
- 🔍 **AST-based transformations** - Robust code analysis and modification
- 📝 **Regex-based suggestors** - Simple text pattern matching
- 🎯 **Ignore mechanism** - Exclude specific code from transformations
- 📊 **Statistics tracking** - Monitor execution metrics
- 🔧 **File filtering** - Advanced include/exclude patterns
- 🛡️ **Error recovery** - Graceful handling of errors
- ✅ **CI/CD ready** - Dry-run mode and automated application

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  codemod: ^1.3.0
```

```bash
dart pub get
```

### Your First Codemod

```dart
import 'dart:io';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

Stream<Patch> addLicenseHeader(FileContext context) async* {
  const header = '// Copyright 2025\n';
  if (context.sourceText.startsWith(header)) return;
  yield Patch(header, 0, 0);
}

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart')),
    addLicenseHeader,
    args: args,
  );
}
```

Run it:

```bash
dart my_codemod.dart
```

## Documentation

📚 **Comprehensive documentation is available in the [`docs/`](docs/) directory:**

- **[Getting Started](docs/getting-started.md)** - Installation, setup, and first steps
- **[API Reference](docs/api-reference.md)** - Complete API documentation
- **[Examples](docs/examples.md)** - AST and non-AST examples
- **[AI/LLM Guide](docs/ai-guide.md)** - Instructions for AI assistants to generate codemods
- **[Best Practices](docs/best-practices.md)** - Guidelines for writing effective codemods
- **[Advanced Topics](docs/advanced-topics.md)** - Advanced features and techniques

## Core Concepts

### Suggestor

A `Suggestor` is a function that takes a `FileContext` and returns a `Stream<Patch>`:

```dart
typedef Suggestor = Stream<Patch> Function(FileContext context);
```

### Patch

A `Patch` represents a single change - insertion, deletion, or replacement:

```dart
// Insertion
yield Patch('new code', offset, offset);

// Deletion
yield Patch('', startOffset, endOffset);

// Replacement
yield Patch('new code', startOffset, endOffset);
```

### FileContext

Provides access to file contents and analyzed formats:

```dart
// Get source text
final text = context.sourceText;

// Get unresolved AST (fast)
final unit = context.getUnresolvedUnit();

// Get resolved AST (slower, includes types)
final resolved = await context.getResolvedUnit();
```

## Examples

### Non-AST: Regex Substitution

```dart
Stream<Patch> updateVersion(FileContext context) async* {
  final pattern = RegExp(r'codemod:\s*([\d^.]+)');
  for (final match in pattern.allMatches(context.sourceText)) {
    yield Patch('codemod: ^1.3.0', match.start, match.end);
  }
}
```

### AST-Based: Remove Deprecated Code

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class DeprecatedRemover extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitDeclaration(Declaration node) {
    final isDeprecated = node.metadata.any((m) => 
      m.name.name.toLowerCase() == 'deprecated');
    if (isDeprecated) {
      yieldPatch('', node.offset, node.end);
    }
    super.visitDeclaration(node);
  }
}
```

See [Examples](docs/examples.md) for more patterns.

## Command Line Options

- `-h, --help` - Print help output
- `-v, --verbose` - Output all logging and statistics
- `--yes-to-all` - Accept all patches automatically (for scripts)
- `--fail-on-changes` - Exit with non-zero if changes needed (dry-run)
- `--stderr-assume-tty` - Force ANSI colors in stderr

### Usage Examples

```bash
# Interactive mode (default)
dart my_codemod.dart

# Dry run - check what would change
dart my_codemod.dart --fail-on-changes

# Automated - apply all changes
dart my_codemod.dart --yes-to-all

# Verbose - see detailed logs and statistics
dart my_codemod.dart --verbose
```

## Ignore Mechanism

Exclude code from transformations using comments:

```dart
// codemod_ignore
void specialFunction() {
  // This will be skipped
}

// codemod_ignore_start
void function1() { }
void function2() { }
// codemod_ignore_end
```

See [Advanced Topics](docs/advanced-topics.md#ignore-mechanism) for details.

## File Filtering

Filter files using include/exclude patterns:

```dart
final filter = FileFilter(FileFilterConfig(
  includePatterns: ['lib/**/*.dart'],
  excludePatterns: ['lib/**/*.g.dart', 'lib/**/*.freezed.dart'],
));

final filtered = filter.filterFiles(allFiles);
```

## Combining Suggestors

### Aggregate (Parallel)

Run multiple suggestors in parallel:

```dart
exitCode = await runInteractiveCodemod(
  files,
  aggregate([
    licenseHeaderInserter,
    deprecationRemover,
    versionUpdater,
  ]),
);
```

### Sequence (Sequential)

Run suggestors in sequence (useful for dependencies):

```dart
exitCode = await runInteractiveCodemodSequence(
  files,
  [
    collectorSuggestor,  // Collects information
    transformerSuggestor, // Uses collected data
  ],
);
```

## Testing

The `package:codemod/test.dart` library provides testing utilities:

```dart
import 'package:codemod/test.dart';
import 'package:test/test.dart';

test('MySuggestor', () async {
  final context = await fileContextForTest('test.dart', '''
oldMethod();
''');
  
  final expected = '''
newMethod();
''';
  
  expectSuggestorGeneratesPatches(MySuggestor(), context, expected);
});
```

See [API Reference](docs/api-reference.md#testing-utilities) for more details.

## Requirements

- Dart SDK >= 3.9.0

## Use Cases

- **Large-scale refactoring** - Update code patterns across codebases
- **Dependency migrations** - Upgrade package versions, migrate APIs
- **Code modernization** - Apply new language features, remove deprecated code
- **Consistency enforcement** - Standardize code style, add license headers
- **Automated fixes** - Apply common fixes automatically

## CI/CD Integration

### Dry Run in CI

```yaml
- name: Check for required changes
  run: dart my_codemod.dart --fail-on-changes
```

### Automated Application

```yaml
- name: Apply codemod changes
  run: dart my_codemod.dart --yes-to-all
```

See [Advanced Topics](docs/advanced-topics.md#integration-with-cicd) for complete examples.

## Resources

- 📖 [Full Documentation](docs/README.md)
- 🚀 [Getting Started](docs/getting-started.md)
- 🔧 [API Reference](docs/api-reference.md)
- 💡 [Examples](docs/examples.md)
- 🤖 [AI/LLM Guide](docs/ai-guide.md) - **Comprehensive 1160+ line guide for AI assistants**
- 🎓 [Diff-to-Codemod Workshop](docs/diff-to-codemod-workshop.md) - Real-world scenarios
- ✨ [Best Practices](docs/best-practices.md)
- 🚀 [Advanced Topics](docs/advanced-topics.md)

## References

- [over_react_codemod][over_react_codemod] - Codemods for the `over_react` UI library
- [analyzer][analyzer] - Dart analyzer package

## Credits

- [facebook/codemod][facebook-codemod] - Python codemod tool that inspired this library

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- **Run tests:** `dart test`
- **Format code:** `dart format`
- **Run analysis:** `dart analyze`

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---

[analyzer]: https://pub.dartlang.org/packages/analyzer
[facebook-codemod]: https://github.com/facebook/codemod
[over_react_codemod]: https://github.com/Workiva/over_react_codemod
