# Advanced Topics

This document covers advanced features and techniques for using codemod.

## Table of Contents

- [Ignore Mechanism](#ignore-mechanism)
- [File Filtering](#file-filtering)
- [Statistics and Metrics](#statistics-and-metrics)
- [Error Recovery](#error-recovery)
- [Parallel Processing](#parallel-processing)
- [Custom Runners](#custom-runners)
- [Integration with CI/CD](#integration-with-cicd)

## Ignore Mechanism

The codemod framework automatically respects ignore comments in your code, allowing users to exclude specific lines or blocks from transformations.

### Single Line Ignore

Ignore the next line:

```dart
// codemod_ignore
void specialFunction() {
  // This function will be skipped
}

// codemod_ignore: This is a special case that needs manual handling
void anotherSpecialFunction() {
  // This will also be skipped, with a reason
}
```

### Block Ignore

Ignore a block of code:

```dart
// codemod_ignore_start
void function1() {
  // This will be ignored
}

void function2() {
  // This will also be ignored
}
// codemod_ignore_end

void function3() {
  // This will be processed normally
}
```

### Comment Styles

Both `//` and `/* */` styles are supported:

```dart
// codemod_ignore
/* codemod_ignore */
// codemod_ignore_start ... codemod_ignore_end
/* codemod_ignore_start */ ... /* codemod_ignore_end */
```

### Implementation Details

The framework automatically filters patches that overlap with ignored regions. You don't need to do anything special in your suggestor - it just works!

## File Filtering

Use `FileFilter` to create sophisticated file selection rules.

### Basic Filtering

```dart
import 'package:codemod/codemod.dart';

final filter = FileFilter(FileFilterConfig(
  includePatterns: ['lib/**/*.dart'],
  excludePatterns: [
    'lib/**/*.g.dart',
    'lib/**/*.freezed.dart',
  ],
));

final allFiles = filePathsFromGlob(Glob('**/*.dart', recursive: true));
final filteredFiles = filter.filterFiles(allFiles);
```

### Advanced Filtering

```dart
final filter = FileFilter(FileFilterConfig(
  includePatterns: [
    'lib/**/*.dart',
    'test/**/*.dart',
  ],
  excludePatterns: [
    '**/*.g.dart',           // Generated files
    '**/*.freezed.dart',     // Freezed files
    '**/generated/**',       // Generated directories
    '**/build/**',           // Build output
  ],
  ignoreHidden: true,        // Ignore .hidden files
  ignoreDartHidden: true,    // Ignore .dart_tool, .packages
));
```

### Configuration from YAML

```dart
final config = FileFilterConfig.fromMap({
  'include': ['lib/**/*.dart'],
  'exclude': ['lib/**/*.g.dart'],
  'ignore_hidden': true,
  'ignore_dart_hidden': true,
});

final filter = FileFilter(config);
```

## Statistics and Metrics

Track codemod execution with `CodemodStats`.

### Accessing Statistics

Statistics are automatically tracked during execution. Enable verbose mode to see them:

```bash
dart my_codemod.dart --verbose
```

### Programmatic Access

```dart
import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  // Statistics are tracked internally
  final exitCode = await runInteractiveCodemod(
    files,
    mySuggestor,
    args: args,
  );
  
  // In verbose mode, statistics are printed automatically
}
```

### Statistics Fields

- `filesProcessed` - Total files examined
- `filesModified` - Files that were changed
- `patchesSuggested` - Total patches generated
- `patchesApplied` - Patches that were accepted
- `patchesSkipped` - Patches that were rejected
- `patchesIgnored` - Patches filtered by ignore comments
- `errors` - Number of errors encountered
- `duration` - Total execution time

## Error Recovery

The framework includes built-in error recovery to prevent one file's errors from stopping the entire codemod.

### Automatic Recovery

Errors in individual files are caught and logged, but processing continues:

```dart
// If this file has an error, it's logged but other files continue
Stream<Patch> mySuggestor(FileContext context) async* {
  // If this throws, the error is caught and logged
  // Processing continues with the next file
  yield Patch('new code', 0, 10);
}
```

### Error Tracking

Errors are tracked in `CodemodStats`:

```dart
// After execution, check stats.errors
// Exit code will be non-zero if errors occurred
```

### Best Practices

1. **Validate inputs** - Check conditions before processing
2. **Handle nulls** - AST nodes can be null
3. **Catch exceptions** - Wrap risky operations in try-catch
4. **Log context** - Include file path in error messages

## Parallel Processing

While the framework processes files sequentially by default, you can optimize suggestor performance.

### Efficient Suggestors

Write suggestors that process quickly:

```dart
// Fast: Uses unresolved AST
class FastSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  // No shouldResolveAst override = fast
}

// Slower: Needs resolved AST
class SlowSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldResolveAst(_) => true; // Only when needed!
}
```

### Skip Unnecessary Work

```dart
class EfficientSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldSkip(FileContext context) {
    // Skip early to avoid parsing
    return !context.sourceText.contains('target');
  }
}
```

## Custom Runners

While `runInteractiveCodemod` is the standard way to run codemods, you can build custom runners.

### Basic Custom Runner

```dart
Future<void> customRunner(
  Iterable<String> files,
  Suggestor suggestor,
) async {
  final collection = AnalysisContextCollection(includedPaths: files);
  
  for (final file in files) {
    final context = FileContext(file, collection);
    final patches = await suggestor(context).toList();
    
    // Custom processing
    if (patches.isNotEmpty) {
      applyPatchesAndSave(context.sourceFile, patches);
    }
  }
}
```

### Batch Processing

```dart
Future<void> batchRunner(
  Iterable<String> files,
  Suggestor suggestor,
  int batchSize,
) async {
  final batches = files.toList().chunked(batchSize);
  
  for (final batch in batches) {
    await processBatch(batch, suggestor);
  }
}
```

## Integration with CI/CD

Codemods are perfect for CI/CD pipelines.

### Dry Run Mode

Check if changes are needed without applying them:

```bash
dart my_codemod.dart --fail-on-changes
```

Exit code:
- `0` - No changes needed
- `1` - Changes required

### Automated Application

Apply changes automatically in CI:

```bash
dart my_codemod.dart --yes-to-all
```

### GitHub Actions Example

```yaml
name: Run Codemod

on:
  pull_request:
    branches: [main]

jobs:
  codemod:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      
      - name: Check for required changes
        run: dart my_codemod.dart --fail-on-changes
        continue-on-error: true
      
      - name: Apply changes
        if: failure()
        run: dart my_codemod.dart --yes-to-all
        
      - name: Create PR
        # Create PR with changes
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

dart my_codemod.dart --fail-on-changes
if [ $? -ne 0 ]; then
  echo "Codemod changes required. Run: dart my_codemod.dart --yes-to-all"
  exit 1
fi
```

## Advanced Patterns

### Collector Pattern

Collect information in one pass, use in another:

```dart
final collectedData = <String, dynamic>{};

final collector = (FileContext context) async* {
  // Collect information
  collectedData[context.relativePath] = extractInfo(context);
};

final transformer = (FileContext context) async* {
  // Use collected information
  final info = collectedData[context.relativePath];
  if (info != null) {
    yield Patch(transform(info), 0, 10);
  }
};

await runInteractiveCodemodSequence(files, [collector, transformer]);
```

### Conditional Transformation

Transform based on file context:

```dart
class ConditionalSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldSkip(FileContext context) {
    // Skip test files
    if (context.relativePath.contains('_test.dart')) return true;
    
    // Skip if doesn't match criteria
    return !meetsCriteria(context);
  }
  
  bool meetsCriteria(FileContext context) {
    // Your logic
    return context.sourceText.contains('target');
  }
}
```

### Multi-file Dependencies

Handle transformations that span multiple files:

```dart
// First pass: collect cross-file information
final crossFileData = <String, Set<String>>{};

final collector = (FileContext context) async* {
  final imports = extractImports(context);
  crossFileData[context.relativePath] = imports;
};

// Second pass: use cross-file data
final transformer = (FileContext context) async* {
  final dependencies = crossFileData[context.relativePath] ?? {};
  // Transform based on dependencies
};
```

## Performance Optimization

### Profile Your Codemod

```dart
void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();
  
  await runInteractiveCodemod(files, suggestor, args: args);
  
  stopwatch.stop();
  print('Execution time: ${stopwatch.elapsedMilliseconds}ms');
}
```

### Optimize AST Traversal

```dart
class OptimizedSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  // Only visit nodes you care about
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Process
    // Don't call super if you don't need to visit children
  }
  
  // Skip visiting children when possible
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (shouldSkipClass(node)) {
      // Skip visiting class body
      return;
    }
    super.visitClassDeclaration(node);
  }
}
```

## Debugging

### Verbose Logging

```bash
dart my_codemod.dart --verbose 2>debug.log
```

### Debug Specific Files

```dart
void main(List<String> args) async {
  // Process only specific files for debugging
  final debugFiles = ['lib/specific_file.dart'];
  
  exitCode = await runInteractiveCodemod(
    debugFiles,
    mySuggestor,
    args: args,
  );
}
```

### Print Patch Details

```dart
Stream<Patch> debugSuggestor(FileContext context) async* {
  final patches = await generatePatches(context);
  
  for (final patch in patches) {
    print('Patch: ${patch.startOffset}-${patch.endOffset}');
    print('  Old: ${context.sourceText.substring(patch.startOffset, patch.endOffset)}');
    print('  New: ${patch.updatedText}');
    yield patch;
  }
}
```

## Summary

Advanced features enable:
- **Flexibility** - Ignore mechanism, file filtering
- **Observability** - Statistics and metrics
- **Reliability** - Error recovery
- **Integration** - CI/CD support
- **Performance** - Optimization techniques

Use these features to build production-ready codemods that integrate seamlessly into your workflow.
