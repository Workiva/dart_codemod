# Best Practices

This guide covers best practices for writing effective, maintainable, and reliable codemods.

## Table of Contents

- [Writing Suggestors](#writing-suggestors)
- [Error Handling](#error-handling)
- [Performance](#performance)
- [Testing](#testing)
- [Maintainability](#maintainability)
- [User Experience](#user-experience)

## Writing Suggestors

### Keep Suggestors Focused

**Good**: Each suggestor does one thing
```dart
Stream<Patch> addLicenseHeader(FileContext context) async* {
  // Only adds license headers
}

Stream<Patch> removeDeprecated(FileContext context) async* {
  // Only removes deprecated code
}
```

**Bad**: One suggestor does multiple unrelated things
```dart
Stream<Patch> doEverything(FileContext context) async* {
  // Adds headers, removes deprecated code, updates versions...
  // Too complex!
}
```

### Use Appropriate Approach

**Use Non-AST (Regex/Text) for:**
- Simple string replacements
- File-level changes (headers, footers)
- Non-Dart files (YAML, JSON, Markdown)
- Patterns easily matched with regex

**Use AST-based for:**
- Code structure understanding
- Type-aware transformations
- Language construct matching
- Robust pattern matching

### Check Before Patching

Always verify that a change is needed:

```dart
Stream<Patch> smartSuggestor(FileContext context) async* {
  // Check if already transformed
  if (context.sourceText.contains('newPattern')) return;
  
  // Check if pattern exists
  if (!context.sourceText.contains('oldPattern')) return;
  
  // Only then generate patches
  yield Patch('newPattern', 0, 10);
}
```

### Handle Edge Cases

```dart
Stream<Patch> robustSuggestor(FileContext context) async* {
  // Handle empty files
  if (context.sourceText.isEmpty) return;
  
  // Handle files that don't match pattern
  if (!shouldProcess(context)) return;
  
  // Handle already transformed code
  if (isAlreadyTransformed(context)) return;
  
  // Your transformation logic
}
```

## Error Handling

### Graceful Degradation

Don't let errors in one file stop the entire codemod:

```dart
Stream<Patch> safeSuggestor(FileContext context) async* {
  try {
    // Your logic
    yield Patch('new code', 0, 10);
  } catch (e, stackTrace) {
    // Log error but continue
    // The runner will track it in CodemodStats
    return;
  }
}
```

### Validate Inputs

```dart
class SafeAstSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Validate node exists
    if (node.methodName == null) {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Validate conditions
    if (node.methodName.name != 'targetMethod') {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Safe to proceed
    yieldPatch('newMethod', node.methodName.offset, node.methodName.end);
    super.visitMethodInvocation(node);
  }
}
```

### Provide Clear Error Messages

When validation fails, provide helpful context:

```dart
Stream<Patch> validatedSuggestor(FileContext context) async* {
  if (!context.sourceText.contains('requiredPattern')) {
    // Log why we're skipping
    logger.fine('Skipping ${context.relativePath}: missing required pattern');
    return;
  }
  
  // Process file
}
```

## Performance

### Use Unresolved AST When Possible

Resolved AST is much slower. Only use it when you need type information:

```dart
class FastSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  // Don't override shouldResolveAst - uses unresolved AST (fast)
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Can check method name without resolution
    if (node.methodName.name == 'target') {
      yieldPatch('new', node.methodName.offset, node.methodName.end);
    }
    super.visitMethodInvocation(node);
  }
}

class SlowSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldResolveAst(_) => true; // Only when needed!
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Need type information
    if (node.staticType?.isDartCoreInt == true) {
      // Transformation
    }
    super.visitMethodInvocation(node);
  }
}
```

### Skip Files Early

Use `shouldSkip()` to avoid unnecessary work:

```dart
class EfficientSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldSkip(FileContext context) {
    // Skip test files
    if (context.relativePath.contains('_test.dart')) return true;
    
    // Skip generated files
    if (context.sourceText.contains('// GENERATED')) return true;
    
    // Skip if pattern not present
    if (!context.sourceText.contains('targetPattern')) return true;
    
    return false;
  }
}
```

### Avoid Redundant Processing

```dart
Stream<Patch> efficientSuggestor(FileContext context) async* {
  // Check once, not in loop
  if (!context.sourceText.contains('pattern')) return;
  
  // Process all matches
  for (final match in pattern.allMatches(context.sourceText)) {
    yield Patch('replacement', match.start, match.end);
  }
}
```

## Testing

### Test with Real Examples

```dart
test('MySuggestor transforms correctly', () async {
  final context = await fileContextForTest('test.dart', '''
// Input code here
oldMethod();
''');
  
  final expected = '''
// Expected output
newMethod();
''';
  
  expectSuggestorGeneratesPatches(MySuggestor(), context, expected);
});
```

### Test Edge Cases

```dart
test('MySuggestor handles edge cases', () async {
  // Empty file
  final empty = await fileContextForTest('empty.dart', '');
  expectSuggestorGeneratesPatches(MySuggestor(), empty, '');
  
  // Already transformed
  final transformed = await fileContextForTest('done.dart', 'newMethod();');
  expectSuggestorGeneratesPatches(MySuggestor(), transformed, 'newMethod();');
  
  // No matches
  final noMatch = await fileContextForTest('nomatch.dart', 'otherCode();');
  expectSuggestorGeneratesPatches(MySuggestor(), noMatch, 'otherCode();');
});
```

### Test Multiple Patches

```dart
test('MySuggestor handles multiple occurrences', () async {
  final context = await fileContextForTest('multi.dart', '''
oldMethod();
other code;
oldMethod();
''');
  
  final expected = '''
newMethod();
other code;
newMethod();
''';
  
  expectSuggestorGeneratesPatches(MySuggestor(), context, expected);
});
```

## Maintainability

### Use Constants

```dart
class MaintainableSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  static const String oldPattern = 'oldMethod';
  static const String newPattern = 'newMethod';
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == oldPattern) {
      yieldPatch(newPattern, node.methodName.offset, node.methodName.end);
    }
    super.visitMethodInvocation(node);
  }
}
```

### Document Complex Logic

```dart
Stream<Patch> complexSuggestor(FileContext context) async* {
  // Step 1: Find all method calls matching pattern
  // We use regex because we need to capture the full call including arguments
  final matches = methodCallPattern.allMatches(context.sourceText);
  
  // Step 2: For each match, check if it needs transformation
  // We skip if the method is already using the new API
  for (final match in matches) {
    if (shouldTransform(match)) {
      // Step 3: Generate replacement
      // We preserve arguments but change method name
      yield Patch(generateReplacement(match), match.start, match.end);
    }
  }
}
```

### Extract Helper Functions

```dart
class CleanSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (shouldTransform(node)) {
      final replacement = generateReplacement(node);
      yieldPatch(replacement, node.offset, node.end);
    }
    super.visitMethodInvocation(node);
  }
  
  bool shouldTransform(MethodInvocation node) {
    // Complex logic here
    return node.methodName.name == 'old' && 
           hasRequiredParameters(node);
  }
  
  String generateReplacement(MethodInvocation node) {
    // Transformation logic here
    return 'new(${extractArguments(node)})';
  }
}
```

## User Experience

### Provide Clear Diffs

Make sure your patches create clear, understandable diffs:

```dart
// Good: Clear replacement
yield Patch('newMethod()', oldCall.offset, oldCall.end);

// Bad: Unclear what changed
yield Patch('new', oldCall.offset, oldCall.offset + 3);
```

### Respect Ignore Comments

The framework automatically handles ignore comments, but be aware:

```dart
// Users can mark code to skip:
// codemod_ignore
void specialFunction() {
  // This will be skipped automatically
}
```

### Use Descriptive Names

```dart
// Good
class DeprecatedCodeRemover extends ...
class ApiVersionUpdater extends ...
Stream<Patch> addLicenseHeaders(FileContext context) async* {}

// Bad
class Suggestor1 extends ...
class MyCodemod extends ...
Stream<Patch> doStuff(FileContext context) async* {}
```

### Combine Related Suggestors

Use `aggregate()` for related transformations:

```dart
final apiMigration = aggregate([
  updateMethodCalls,
  updateTypeSignatures,
  updateImports,
]);
```

### Use Sequential Suggestors for Dependencies

When one transformation depends on another:

```dart
exitCode = await runInteractiveCodemodSequence(
  files,
  [
    collectInformation,  // First: gather data
    transformCode,        // Second: use collected data
  ],
);
```

## Code Organization

### Project Structure

```
my_codemod/
├── lib/
│   ├── suggestors/
│   │   ├── license_header.dart
│   │   ├── deprecation_remover.dart
│   │   └── api_migration.dart
│   ├── utils/
│   │   └── helpers.dart
│   └── main.dart
├── test/
│   └── suggestors/
│       ├── license_header_test.dart
│       └── deprecation_remover_test.dart
└── pubspec.yaml
```

### Separate Concerns

```dart
// lib/suggestors/api_migration.dart
class ApiMigration extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  // Migration logic
}

// lib/utils/migration_maps.dart
final apiMappings = {
  'oldMethod': 'newMethod',
  'oldClass': 'newClass',
};

// lib/main.dart
import 'suggestors/api_migration.dart';
import 'utils/migration_maps.dart';
```

## Common Pitfalls

### 1. Forgetting to Call super

```dart
// Bad: Stops traversal
@override
void visitMethodInvocation(MethodInvocation node) {
  if (shouldTransform(node)) {
    yieldPatch('new', node.offset, node.end);
  }
  // Missing super.visitMethodInvocation(node);
}

// Good: Continues traversal
@override
void visitMethodInvocation(MethodInvocation node) {
  if (shouldTransform(node)) {
    yieldPatch('new', node.offset, node.end);
  }
  super.visitMethodInvocation(node);
}
```

### 2. Wrong Offset Calculation

```dart
// Bad: Using line numbers
yield Patch('new', lineNumber * 80, lineNumber * 80 + 10);

// Good: Using node offsets
yield Patch('new', node.offset, node.end);
```

### 3. Creating Overlapping Patches

```dart
// Bad: Overlapping patches
yield Patch('new1', 0, 10);
yield Patch('new2', 5, 15); // Overlaps!

// Good: Non-overlapping patches
yield Patch('new1', 0, 10);
yield Patch('new2', 10, 20);
```

### 4. Not Checking Conditions

```dart
// Bad: Always patches
@override
void visitMethodInvocation(MethodInvocation node) {
  yieldPatch('new', node.offset, node.end);
}

// Good: Checks condition first
@override
void visitMethodInvocation(MethodInvocation node) {
  if (node.methodName.name == 'target') {
    yieldPatch('new', node.offset, node.end);
  }
  super.visitMethodInvocation(node);
}
```

## Summary

1. **Keep it focused** - One suggestor, one purpose
2. **Choose the right approach** - AST vs non-AST
3. **Handle errors gracefully** - Don't break on one file
4. **Optimize for performance** - Use unresolved AST when possible
5. **Test thoroughly** - Cover edge cases
6. **Write maintainable code** - Constants, helpers, documentation
7. **Consider users** - Clear diffs, respect ignores
8. **Avoid common pitfalls** - Call super, use correct offsets

Following these practices will help you write effective, reliable codemods that are easy to maintain and use.
