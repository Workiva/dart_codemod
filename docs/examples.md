# Examples

This document provides comprehensive examples of writing codemods, both using AST-based and non-AST approaches.

## Table of Contents

- [Non-AST Examples](#non-ast-examples)
  - [License Header Inserter](#license-header-inserter)
  - [Regex Substitution](#regex-substitution)
- [AST-Based Examples](#ast-based-examples)
  - [Deprecated Code Remover](#deprecated-code-remover)
  - [Method Refactoring](#method-refactoring)
  - [Type-Based Transformations](#type-based-transformations)
- [Advanced Examples](#advanced-examples)
  - [Multiple Suggestors](#multiple-suggestors)
  - [File Filtering](#file-filtering)
  - [Using Ignore Comments](#using-ignore-comments)

## Non-AST Examples

### License Header Inserter

A simple suggestor that adds a license header to files that don't have one.

```dart
import 'package:codemod/codemod.dart';

final String licenseHeader = '''
// Copyright 2025 Your Company
// Licensed under the MIT License
''';

Stream<Patch> licenseHeaderInserter(FileContext context) async* {
  // Skip if license header already exists
  if (context.sourceText.trimLeft().startsWith(licenseHeader)) return;

  // Insert at the beginning of the file (offset 0)
  yield Patch(licenseHeader, 0, 0);
}
```

**Usage:**
```dart
void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart')),
    licenseHeaderInserter,
    args: args,
  );
}
```

### Regex Substitution

Update version constraints in `pubspec.yaml` files.

```dart
import 'package:codemod/codemod.dart';

final RegExp pattern = RegExp(
  r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
  multiLine: true,
);

const String targetConstraint = '^1.3.0';

Stream<Patch> regexSubstituter(FileContext context) async* {
  for (final match in pattern.allMatches(context.sourceText)) {
    final line = match.group(0)!;
    final constraint = match.group(1)!;
    final updated = '${line.replaceFirst(constraint, targetConstraint)}\n';

    yield Patch(updated, match.start, match.end);
  }
}
```

**Input:**
```yaml
dependencies:
  codemod: ^1.0.0
```

**Output:**
```yaml
dependencies:
  codemod: ^1.3.0
```

### Text Replacement

Replace specific strings in code.

```dart
Stream<Patch> replaceOldApi(FileContext context) async* {
  const oldApi = 'oldFunction';
  const newApi = 'newFunction';
  
  int start = 0;
  while (true) {
    final index = context.sourceText.indexOf(oldApi, start);
    if (index == -1) break;
    
    yield Patch(newApi, index, index + oldApi.length);
    start = index + oldApi.length;
  }
}
```

## AST-Based Examples

### Deprecated Code Remover

Remove all deprecated declarations using AST visitor.

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class DeprecatedRemover extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => 
        m.name.name.toLowerCase() == 'deprecated');

  @override
  void visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the entire declaration
      yieldPatch('', node.offset, node.end);
    }
    super.visitDeclaration(node);
  }
}
```

**Input:**
```dart
@Deprecated('Use newFunction instead')
void oldFunction() {}

void newFunction() {}
```

**Output:**
```dart
void newFunction() {}
```

### Method Refactoring

Refactor method calls to use new API.

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class MethodRefactor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check if method name matches
    if (node.methodName.name == 'oldMethod') {
      // Replace with new method call
      final newCall = 'newMethod(${node.argumentList.arguments.join(', ')})';
      yieldPatch(newCall, node.offset, node.end);
    }
    super.visitMethodInvocation(node);
  }
}
```

### Type-Based Transformations

Transform code based on type information (requires resolved AST).

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class IsEvenOrOddRefactor extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldResolveAst(_) => true; // Need type information

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.leftOperand is BinaryExpression &&
        node.rightOperand is IntegerLiteral) {
      final left = node.leftOperand as BinaryExpression;
      final right = node.rightOperand as IntegerLiteral;
      
      // Check if it's a modulus operation on int
      if (left.operator.stringValue == '%' &&
          node.operator.stringValue == '==' &&
          left.leftOperand.staticType?.isDartCoreInt == true) {
        
        if (right.value == 0) {
          // Replace with .isEven
          yieldPatch('.isEven', left.leftOperand.end, node.end);
        } else if (right.value == 1) {
          // Replace with .isOdd
          yieldPatch('.isOdd', left.leftOperand.end, node.end);
        }
      }
    }
    super.visitBinaryExpression(node);
  }
}
```

**Input:**
```dart
bool isEven = (x % 2) == 0;
bool isOdd = (x % 2) == 1;
```

**Output:**
```dart
bool isEven = x.isEven;
bool isOdd = x.isOdd;
```

### Class Annotation Adder

Add annotations to classes matching certain criteria.

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class AddAnnotation extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Check if class already has the annotation
    final hasAnnotation = node.metadata.any((m) => 
      m.name.name == 'Serializable');
    
    if (!hasAnnotation && shouldAddAnnotation(node)) {
      // Add annotation before class declaration
      yieldPatch('@Serializable\n', node.offset, node.offset);
    }
    super.visitClassDeclaration(node);
  }
  
  bool shouldAddAnnotation(ClassDeclaration node) {
    // Your logic here
    return true;
  }
}
```

## Advanced Examples

### Multiple Suggestors

Combine multiple suggestors using `aggregate()`.

```dart
import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart')),
    aggregate([
      licenseHeaderInserter,
      deprecationRemover,
      versionUpdater,
    ]),
    args: args,
  );
}
```

### Sequential Suggestors

Run suggestors in sequence (useful when one depends on another).

```dart
void main(List<String> args) async {
  exitCode = await runInteractiveCodemodSequence(
    filePathsFromGlob(Glob('lib/**/*.dart')),
    [
      collectorSuggestor,  // Collects information
      transformerSuggestor, // Uses collected information
    ],
    args: args,
  );
}
```

### File Filtering

Filter files using include/exclude patterns.

```dart
import 'package:codemod/codemod.dart';

void main(List<String> args) async {
  final filter = FileFilter(FileFilterConfig(
    includePatterns: ['lib/**/*.dart'],
    excludePatterns: [
      'lib/**/*.g.dart',
      'lib/**/*.freezed.dart',
      'lib/**/generated/**',
    ],
    ignoreHidden: true,
    ignoreDartHidden: true,
  ));
  
  final allFiles = filePathsFromGlob(Glob('**/*.dart', recursive: true));
  final filteredFiles = filter.filterFiles(allFiles);
  
  exitCode = await runInteractiveCodemod(
    filteredFiles,
    mySuggestor,
    args: args,
  );
}
```

### Using Ignore Comments

Allow users to exclude specific code from codemod changes.

**In your code:**
```dart
// codemod_ignore: This is a special case
void specialFunction() {
  // This function will be ignored
}

// codemod_ignore_start
void function1() {
  // This will be ignored
}

void function2() {
  // This will also be ignored
}
// codemod_ignore_end
```

The codemod will automatically skip patches for code marked with ignore comments.

### Conditional Processing

Skip files based on content.

```dart
class ConditionalSuggestor extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  bool shouldSkip(FileContext context) {
    // Skip test files
    if (context.relativePath.contains('_test.dart')) {
      return true;
    }
    
    // Skip generated files
    if (context.sourceText.contains('// GENERATED CODE')) {
      return true;
    }
    
    return false;
  }
  
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Your transformation logic
  }
}
```

### Error Handling

Handle errors gracefully in your suggestor.

```dart
Stream<Patch> robustSuggestor(FileContext context) async* {
  try {
    // Your logic here
    yield Patch('new code', 0, 10);
  } catch (e, stackTrace) {
    // Log error but continue processing other files
    // The runner will track errors in CodemodStats
    return;
  }
}
```

## Real-World Patterns

### Migration Pattern

Migrate from one API to another.

```dart
class ApiMigration extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  final Map<String, String> apiMapping = {
    'oldMethod1': 'newMethod1',
    'oldMethod2': 'newMethod2',
  };
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final oldName = node.methodName.name;
    if (apiMapping.containsKey(oldName)) {
      final newName = apiMapping[oldName]!;
      // Replace method name
      yieldPatch(newName, node.methodName.offset, node.methodName.end);
    }
    super.visitMethodInvocation(node);
  }
}
```

### Code Style Enforcement

Enforce consistent code style.

```dart
class StyleEnforcer extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Enforce naming conventions
    if (node.name.name.startsWith('_') && 
        !node.isPrivate) {
      // Fix visibility
    }
    super.visitVariableDeclaration(node);
  }
}
```

## Testing Your Suggestors

See the [API Reference](api-reference.md) for testing utilities, or check the test files in the repository for examples.
