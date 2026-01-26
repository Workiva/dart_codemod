# Getting Started with Codemod

This guide will help you get started with the `codemod` package for Dart.

## Installation

Add `codemod` to your `pubspec.yaml`:

```yaml
dependencies:
  codemod: ^1.3.0
```

Then run:

```bash
dart pub get
```

## Requirements

- Dart SDK >= 3.9.0
- For running codemods: Dart installed and available in PATH

## Your First Codemod

Let's create a simple codemod that adds a license header to all Dart files.

### Step 1: Create a Suggestor

A suggestor is a function that takes a `FileContext` and returns a `Stream<Patch>`. Create a file `license_header_suggestor.dart`:

```dart
import 'package:codemod/codemod.dart';

final String licenseHeader = '''
// Copyright 2025 Your Company
// Licensed under the MIT License
''';

Stream<Patch> licenseHeaderInserter(FileContext context) async* {
  // Skip if license header already exists
  if (context.sourceText.trimLeft().startsWith(licenseHeader)) return;

  // Insert license header at the beginning of the file
  yield Patch(licenseHeader, 0, 0);
}
```

### Step 2: Create a Runner Script

Create a file `add_license_headers.dart`:

```dart
import 'dart:io';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

import 'license_header_suggestor.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart', recursive: true)),
    licenseHeaderInserter,
    args: args,
  );
}
```

### Step 3: Run the Codemod

```bash
dart add_license_headers.dart
```

The codemod will:
1. Find all `.dart` files in the `lib` directory
2. Show you each file that needs a license header
3. Display a diff of the proposed change
4. Ask you to accept (y), skip (n), accept all (A), or quit (q)

## Command Line Options

Codemod supports several command-line options:

- `-h, --help` - Print help output
- `-v, --verbose` - Output all logging to stdout/stderr
- `--yes-to-all` - Accept all patches without prompting (useful for scripts)
- `--fail-on-changes` - Return non-zero exit code if changes are needed (dry-run mode)
- `--stderr-assume-tty` - Force ANSI color highlighting of stderr

### Example: Dry Run

Check what changes would be made without actually applying them:

```bash
dart add_license_headers.dart --fail-on-changes
```

### Example: Automated Script

Accept all changes automatically:

```bash
dart add_license_headers.dart --yes-to-all
```

## Project Structure

A typical codemod project structure:

```
my_codemod/
├── pubspec.yaml
├── lib/
│   ├── suggestors/
│   │   ├── license_header_suggestor.dart
│   │   └── deprecation_remover.dart
│   └── main.dart
└── test/
    └── suggestors/
        └── license_header_suggestor_test.dart
```

## Next Steps

- Read the [API Reference](api-reference.md) to understand all available APIs
- Check out [Examples](examples.md) for more complex patterns
- Learn about [Best Practices](best-practices.md) for writing effective codemods
- Explore [Advanced Topics](advanced-topics.md) for advanced features

## Common Use Cases

### Adding License Headers

See the example above or check `example/license_header_inserter.dart` in the repository.

### Updating Package Versions

Use regex-based suggestors to update version constraints in `pubspec.yaml` files. See `example/regex_substituter.dart`.

### Removing Deprecated Code

Use AST-based suggestors to find and remove deprecated declarations. See `example/deprecated_remover.dart`.

### Refactoring Code Patterns

Use AST visitors to find and transform specific code patterns. See `example/is_even_or_odd_suggestor.dart`.

## Troubleshooting

### "No files found"

Make sure your glob pattern matches the files you want to process. Use `--verbose` to see what files are being considered.

### "Analysis errors"

If you get analysis errors, make sure:
- All dependencies are installed (`dart pub get`)
- The code compiles normally
- You're using a compatible Dart SDK version (>= 3.9.0)

### "Patches not applying correctly"

- Check that your patch offsets are correct
- Ensure patches don't overlap
- Use `--verbose` to see detailed logging

## Getting Help

- Check the [Examples](examples.md) for similar use cases
- Review the [API Reference](api-reference.md)
- Open an issue on [GitHub](https://github.com/Workiva/dart_codemod/issues)
