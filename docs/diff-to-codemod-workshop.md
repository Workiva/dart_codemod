# Diff-to-Codemod Workshop: Real-World Scenarios

This document provides step-by-step walkthroughs of converting real code diffs into working codemod scripts. Each example includes the original diff, analysis, and complete working code.

## Workshop Format

Each example follows this structure:
1. **Original Diff** - The actual code change
2. **Analysis** - Breaking down what needs to happen
3. **Step-by-Step Solution** - Complete working code with explanations
4. **Testing** - How to verify it works
5. **Edge Cases** - What to watch out for

---

## Scenario 1: Renaming a Function Across Codebase

### Original Diff

```diff
--- a/lib/utils.dart
+++ b/lib/utils.dart
@@ -10,7 +10,7 @@
-String formatDate(DateTime date) {
+String formatDateTime(DateTime date) {
   return date.toString();
 }
 
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -5,7 +5,7 @@
 void main() {
-  print(formatDate(DateTime.now()));
+  print(formatDateTime(DateTime.now()));
 }
```

### Analysis

**What changed:**
- Function name: `formatDate` → `formatDateTime`
- All call sites updated

**Pattern to match:**
- Function declaration: `formatDate(...)`
- Function calls: `formatDate(...)`

**Approach:** AST-based (need to match both declarations and invocations)

### Step-by-Step Solution

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class RenameFormatDate extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  static const String oldName = 'formatDate';
  static const String newName = 'formatDateTime';
  
  // Handle function declarations
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.name == oldName) {
      yieldPatch(newName, node.name.offset, node.name.end);
    }
    super.visitFunctionDeclaration(node);
  }
  
  // Handle method calls
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == oldName) {
      yieldPatch(newName, node.methodName.offset, node.methodName.end);
    }
    super.visitMethodInvocation(node);
  }
  
  // Handle function expressions (if used as values)
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier && function.name == oldName) {
      yieldPatch(newName, function.offset, function.end);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
```

### Testing

```dart
test('renames function declaration', () async {
  final context = await fileContextForTest('test.dart', '''
String formatDate(DateTime date) {
  return date.toString();
}
''');
  
  final expected = '''
String formatDateTime(DateTime date) {
  return date.toString();
}
''';
  
  expectSuggestorGeneratesPatches(RenameFormatDate().call, context, expected);
});

test('renames function calls', () async {
  final context = await fileContextForTest('test.dart', '''
void main() {
  print(formatDate(DateTime.now()));
}
''');
  
  final expected = '''
void main() {
  print(formatDateTime(DateTime.now()));
}
''';
  
  expectSuggestorGeneratesPatches(RenameFormatDate().call, context, expected);
});
```

### Edge Cases

- Function with same name in different scopes (should only rename in target scope)
- Function used as parameter name (should not rename)
- String literals containing the name (should not rename)

---

## Scenario 2: Migrating from Optional to Required Parameters

### Original Diff

```diff
--- a/lib/api.dart
+++ b/lib/api.dart
@@ -5,7 +5,7 @@
-void processData(String data, {String? prefix}) {
+void processData(String data, {required String prefix}) {
   print('$prefix$data');
 }
 
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -3,7 +3,7 @@
 void main() {
-  processData('hello');
+  processData('hello', prefix: '');
 }
```

### Analysis

**What changed:**
- Parameter `prefix` became required
- All call sites need to provide `prefix`

**Pattern to match:**
- Parameter declarations in method signatures
- Method invocations missing the parameter

**Approach:** AST-based (complex, needs two passes)

### Step-by-Step Solution

**Step 1: Update Method Signatures**

```dart
class MakeParameterRequired extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  static const String targetMethod = 'processData';
  static const String targetParam = 'prefix';
  
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name != targetMethod) {
      super.visitMethodDeclaration(node);
      return;
    }
    
    final params = node.parameters;
    if (params is FormalParameterList) {
      // Find the named parameter
      for (final param in params.parameters) {
        if (param is DefaultFormalParameter &&
            param.parameter is SimpleFormalParameter) {
          final simple = param.parameter as SimpleFormalParameter;
          if (simple.name?.name == targetParam && !simple.isRequired) {
            // Make it required
            // Find the position to insert 'required'
            final paramStart = simple.offset;
            yieldPatch('required ', paramStart, paramStart);
          }
        }
      }
    }
    
    super.visitMethodDeclaration(node);
  }
}
```

**Step 2: Update Call Sites**

```dart
class AddMissingParameter extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'processData') {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Check if prefix parameter is present
    final hasPrefix = node.argumentList.arguments.any((arg) =>
      arg is NamedExpression && arg.name.label.name == 'prefix');
    
    if (!hasPrefix) {
      // Add prefix parameter
      final args = node.argumentList;
      final newArgs = args.arguments.isEmpty
          ? 'prefix: \'\''
          : ', prefix: \'\'';
      
      // Insert before closing parenthesis
      yieldPatch(newArgs, args.leftParenthesis.end, args.rightParenthesis.offset);
    }
    
    super.visitMethodInvocation(node);
  }
}
```

**Step 3: Combine**

```dart
void main(List<String> args) async {
  exitCode = await runInteractiveCodemodSequence(
    filePathsFromGlob(Glob('lib/**/*.dart')),
    [
      MakeParameterRequired().call,  // First: update signatures
      AddMissingParameter().call,    // Second: update calls
    ],
    args: args,
  );
}
```

---

## Scenario 3: Converting String Concatenation to Interpolation

### Original Diff

```diff
--- a/lib/utils.dart
+++ b/lib/utils.dart
@@ -5,7 +5,7 @@
-String message = 'Hello, ' + name + '!';
+String message = 'Hello, $name!';
```

### Analysis

**What changed:**
- String concatenation with `+` → String interpolation
- Pattern: `'text' + variable + 'text'`

**Approach:** AST-based (need to understand expression structure)

### Solution

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class StringInterpolation extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitBinaryExpression(BinaryExpression node) {
    // Check if it's a string concatenation
    if (node.operator.stringValue == '+') {
      final result = tryConvertToInterpolation(node);
      if (result != null) {
        yieldPatch(result, node.offset, node.end);
        return; // Don't visit children, we're replacing the whole expression
      }
    }
    
    super.visitBinaryExpression(node);
  }
  
  String? tryConvertToInterpolation(BinaryExpression node) {
    // Collect string parts and variables
    final parts = <String>[];
    final variables = <String>[];
    
    // Traverse the binary expression tree
    if (!collectParts(node, parts, variables)) {
      return null; // Can't convert
    }
    
    // Build interpolation string
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      buffer.write(parts[i]);
      if (i < variables.length) {
        buffer.write('\${${variables[i]}}');
      }
    }
    
    return buffer.toString();
  }
  
  bool collectParts(BinaryExpression node, List<String> parts, List<String> variables) {
    // Left operand
    if (node.leftOperand is StringLiteral) {
      parts.add((node.leftOperand as StringLiteral).stringValue ?? '');
    } else if (node.leftOperand is SimpleIdentifier) {
      variables.add((node.leftOperand as SimpleIdentifier).name);
    } else if (node.leftOperand is BinaryExpression) {
      if (!collectParts(node.leftOperand as BinaryExpression, parts, variables)) {
        return false;
      }
    } else {
      return false; // Unsupported
    }
    
    // Right operand
    if (node.rightOperand is StringLiteral) {
      parts.add((node.rightOperand as StringLiteral).stringValue ?? '');
    } else if (node.rightOperand is SimpleIdentifier) {
      variables.add((node.rightOperand as SimpleIdentifier).name);
    } else {
      return false; // Unsupported
    }
    
    return true;
  }
}
```

---

## Scenario 4: Adding Null Safety Checks

### Original Diff

```diff
--- a/lib/utils.dart
+++ b/lib/utils.dart
@@ -5,7 +5,7 @@
-String process(String? value) {
-  return value.toUpperCase();
+String process(String? value) {
+  return value?.toUpperCase() ?? '';
 }
```

### Analysis

**What changed:**
- Added null-aware operator `?.`
- Added null-coalescing operator `??`

**Pattern:** Method calls on nullable types without null checks

**Approach:** AST-based with resolved types (need to know if type is nullable)

### Solution

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class AddNullSafety extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  bool shouldResolveAst(FileContext context) => true; // Need type info
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check if target is nullable
    final target = node.target;
    if (target != null) {
      final targetType = target.staticType;
      if (targetType != null && targetType.isNullable) {
        // Check if already using null-aware operator
        final parent = node.parent;
        if (parent is! ConditionalExpression || 
            (parent as ConditionalExpression).condition != node) {
          
          // Check if method returns non-nullable
          final returnType = node.staticType;
          if (returnType != null && !returnType.isNullable) {
            // Add null-aware and null-coalescing
            // This is complex - would need to determine default value
            // Simplified version:
            final methodName = node.methodName.name;
            final newCall = '${target.toString()}?.$methodName() ?? defaultValue';
            yieldPatch(newCall, node.offset, node.end);
          }
        }
      }
    }
    
    super.visitMethodInvocation(node);
  }
}
```

**Note:** This is a simplified version. Real implementation would need to:
- Determine appropriate default value based on return type
- Handle different method signatures
- Preserve arguments

---

## Scenario 5: Reordering Import Statements

### Original Diff

```diff
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,5 +1,5 @@
+import 'package:flutter/material.dart';
 import 'dart:io';
-import 'package:flutter/material.dart';
 import 'package:my_package/utils.dart';
```

### Analysis

**What changed:**
- Import order changed (Flutter imports first, then Dart SDK, then packages)

**Pattern:** Import directives need reordering

**Approach:** AST-based (need to understand import structure)

### Solution

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class ReorderImports extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitCompilationUnit(CompilationUnit node) {
    final imports = node.directives.whereType<ImportDirective>().toList();
    
    if (imports.length < 2) {
      super.visitCompilationUnit(node);
      return;
    }
    
    // Categorize imports
    final flutterImports = <ImportDirective>[];
    final dartImports = <ImportDirective>[];
    final packageImports = <ImportDirective>[];
    final relativeImports = <ImportDirective>[];
    
    for (final import in imports) {
      final uri = import.uri.stringValue ?? '';
      if (uri.startsWith('package:flutter/')) {
        flutterImports.add(import);
      } else if (uri.startsWith('dart:')) {
        dartImports.add(import);
      } else if (uri.startsWith('package:')) {
        packageImports.add(import);
      } else {
        relativeImports.add(import);
      }
    }
    
    // Check if reordering is needed
    final ordered = [...flutterImports, ...dartImports, ...packageImports, ...relativeImports];
    if (!_areInOrder(imports, ordered)) {
      // Generate new import section
      final newImports = ordered.map((i) => _importToString(i)).join('\n');
      final firstImport = imports.first;
      final lastImport = imports.last;
      
      yieldPatch('$newImports\n', firstImport.offset, lastImport.end);
    }
    
    super.visitCompilationUnit(node);
  }
  
  bool _areInOrder(List<ImportDirective> current, List<ImportDirective> ordered) {
    if (current.length != ordered.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].offset != ordered[i].offset) return false;
    }
    return true;
  }
  
  String _importToString(ImportDirective import) {
    // Reconstruct import statement
    final uri = import.uri.stringValue ?? '';
    final prefix = import.prefix?.name;
    final show = import.combinators
        .whereType<ShowCombinator>()
        .expand((c) => c.shownNames.map((n) => n.name))
        .join(', ');
    final hide = import.combinators
        .whereType<HideCombinator>()
        .expand((c) => c.hiddenNames.map((n) => n.name))
        .join(', ');
    
    var result = "import '$uri'";
    if (prefix != null) result += " as $prefix";
    if (show.isNotEmpty) result += " show $show";
    if (hide.isNotEmpty) result += " hide $hide";
    result += ';';
    
    return result;
  }
}
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Replacing Too Much

**Problem:**
```dart
// Replaces entire method when only name should change
yieldPatch('newMethod', node.offset, node.end);
```

**Solution:**
```dart
// Replace only the method name
yieldPatch('newMethod', node.name.offset, node.name.end);
```

### Pitfall 2: Not Handling Nested Structures

**Problem:** Replacing outer structure breaks inner structure

**Solution:** Replace at the correct level:
```dart
// For method call: replace just the method name
yieldPatch('new', node.methodName.offset, node.methodName.end);

// For entire expression: replace the whole thing
yieldPatch('newExpression', node.offset, node.end);
```

### Pitfall 3: Breaking Code Formatting

**Problem:** Generated code has wrong indentation

**Solution:** Preserve original formatting:
```dart
// Get indentation from original
final lineStart = context.sourceFile.getOffset(node.startLine);
final indent = context.sourceText.substring(lineStart, node.offset);
final newCode = '$indent$transformedCode\n';
```

---

## Testing Your Codemod

Always test with:

1. **Empty file**
2. **File without target pattern**
3. **File with single occurrence**
4. **File with multiple occurrences**
5. **File already transformed**
6. **File with edge cases** (comments, strings containing pattern, etc.)

```dart
test('handles all cases', () async {
  // Test 1: Empty
  final empty = await fileContextForTest('empty.dart', '');
  expectSuggestorGeneratesPatches(MySuggestor().call, empty, '');
  
  // Test 2: No match
  final noMatch = await fileContextForTest('nomatch.dart', 'other code');
  expectSuggestorGeneratesPatches(MySuggestor().call, noMatch, 'other code');
  
  // Test 3: Single match
  final single = await fileContextForTest('single.dart', 'oldMethod()');
  expectSuggestorGeneratesPatches(MySuggestor().call, single, 'newMethod()');
  
  // Test 4: Multiple matches
  final multiple = await fileContextForTest('multi.dart', '''
oldMethod();
other();
oldMethod();
''');
  final expected = '''
newMethod();
other();
newMethod();
''';
  expectSuggestorGeneratesPatches(MySuggestor().call, multiple, expected);
  
  // Test 5: Already transformed
  final done = await fileContextForTest('done.dart', 'newMethod()');
  expectSuggestorGeneratesPatches(MySuggestor().call, done, 'newMethod()');
});
```

---

This workshop provides real-world examples that AI assistants can use as templates when generating codemod scripts from diffs.
