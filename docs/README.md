# Codemod for Dart - Documentation

Welcome to the comprehensive documentation for the `codemod` package for Dart. This library enables you to write and run automated code modifications on a codebase, primarily geared towards updating and refactoring Dart code.

## Documentation Structure

- **[Getting Started](getting-started.md)** - Installation, basic setup, and your first codemod
- **[API Reference](api-reference.md)** - Complete API documentation for all classes, functions, and methods
- **[Examples](examples.md)** - Comprehensive examples including AST-based and non-AST suggestors
- **[AI/LLM Guide](ai-guide.md)** - **Comprehensive guide for AI assistants** to generate codemod scripts from diffs (1160+ lines with detailed instructions)
- **[Diff-to-Codemod Workshop](diff-to-codemod-workshop.md)** - Step-by-step walkthroughs of real-world scenarios
- **[Best Practices](best-practices.md)** - Guidelines and patterns for writing effective codemods
- **[Advanced Topics](advanced-topics.md)** - Advanced features like ignore mechanisms, file filtering, and statistics

## Quick Links

- [Package on pub.dev](https://pub.dev/packages/codemod)
- [GitHub Repository](https://github.com/Workiva/dart_codemod)
- [Changelog](../CHANGELOG.md)
- [Contributing Guide](../CONTRIBUTING.md)

## What is Codemod?

Codemod is a library that makes it easy to write and run automated code modifications on a codebase. It's inspired by Facebook's codemod tool and is designed to help with:

- **Large-scale refactoring** - Update code patterns across entire codebases
- **Dependency migrations** - Upgrade package versions, migrate APIs
- **Code modernization** - Apply new language features, remove deprecated code
- **Consistency enforcement** - Standardize code style, add license headers
- **Automated fixes** - Apply common fixes automatically

## Key Concepts

### Suggestor

A `Suggestor` is a function that takes a `FileContext` and returns a `Stream<Patch>`. It's the core abstraction for code transformations.

### Patch

A `Patch` represents a single change to a file - an insertion, deletion, or replacement at a specific location.

### FileContext

A `FileContext` provides access to file contents and analyzed formats (AST, resolved types, etc.) for a given file.

### Runner

The runner (`runInteractiveCodemod` or `runInteractiveCodemodSequence`) executes suggestors on files and handles user interaction.

## Getting Help

- Check the [Examples](examples.md) for common patterns
- Review the [API Reference](api-reference.md) for detailed method documentation
- See [Best Practices](best-practices.md) for guidance on writing effective codemods
- Open an issue on [GitHub](https://github.com/Workiva/dart_codemod/issues)
