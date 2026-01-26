# AI/LLM Guide: Converting Code Diffs to Codemod Scripts

**Purpose**: This guide provides detailed, step-by-step instructions for AI assistants and LLMs to convert code diffs and refactoring requirements into working codemod scripts for Dart.

**Target Audience**: AI assistants, LLMs, and developers who need to generate codemod scripts from diffs without prior experience with the codemod library.

---

## Table of Contents

1. [Fundamental Concepts](#fundamental-concepts)
2. [Step-by-Step Diff-to-Codemod Process](#step-by-step-diff-to-codemod-process)
3. [Complete Examples with Real Diffs](#complete-examples-with-real-diffs)
4. [AST Node Reference Guide](#ast-node-reference-guide)
5. [Common Patterns Library](#common-patterns-library)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Quick Decision Tree](#quick-decision-tree)

---

## Fundamental Concepts

### What is a Codemod?

A codemod is an automated code transformation script. In Dart's codemod library:

- **Suggestor**: A function that analyzes code and generates changes
- **Patch**: A single change (insert, delete, or replace)
- **FileContext**: Provides access to file contents and parsed code structure

### Core Signature

```dart
typedef Suggestor = Stream<Patch> Function(FileContext context);
```

**Key Points**:
- Must be `async*` (async generator)
- Takes `FileContext` as input
- Returns `Stream<Patch>` using `yield`
- Can yield zero, one, or multiple patches per file

### Patch Structure

```dart
Patch(String updatedText, int startOffset, int? endOffset)
```

**Parameters**:
- `updatedText`: New text to insert (empty string = deletion)
- `startOffset`: Character position where change starts (0-based)
- `endOffset`: Character position where change ends (null = end of file)

**Patch Types**:
- **Insertion**: `startOffset == endOffset`, non-empty `updatedText`
- **Deletion**: `startOffset < endOffset`, empty `updatedText`
- **Replacement**: `startOffset < endOffset`, non-empty `updatedText`

### Two Approaches

1. **Non-AST (Text/Regex)**: Fast, simple, for text patterns
2. **AST-based**: Robust, understands code structure, for language constructs

---

## Step-by-Step Diff-to-Codemod Process

### Phase 1: Analyze the Diff

**Step 1.1: Identify Change Type**

Look at the diff and determine:
- Is it an **insertion**? (only `+` lines)
- Is it a **deletion**? (only `-` lines)
- Is it a **replacement**? (both `-` and `+` lines)

**Step 1.2: Extract Patterns**

From the diff, extract:
- **Old pattern**: What code needs to be matched
- **New pattern**: What it should become
- **Context**: Where it appears (file type, location in code)

**Step 1.3: Determine Scope**

- **Single occurrence** or **multiple occurrences**?
- **File-level** (headers, imports) or **code-level** (statements, expressions)?
- **Simple text** or **structured code**?

### Phase 2: Choose Approach

**Decision Criteria**:

| If the change involves... | Use... | Why |
|---------------------------|--------|-----|
| Simple string replacement | Non-AST | Fast, straightforward |
| File headers/footers | Non-AST | File-level, no structure needed |
| YAML/JSON/Config files | Non-AST | Not Dart code |
| Method/function calls | AST | Need to understand structure |
| Type annotations | AST | Need type information |
| Class/interface definitions | AST | Need structure |
| Annotations | AST | Need to parse metadata |
| Complex nested patterns | AST | More robust matching |

### Phase 3: Write the Suggestor

**For Non-AST approach**:

```dart
Stream<Patch> mySuggestor(FileContext context) async* {
  // 1. Early exit if not applicable
  if (context.sourceText.isEmpty) return;
  if (!context.sourceText.contains('targetPattern')) return;
  
  // 2. Find all matches
  final pattern = RegExp(r'yourPattern');
  for (final match in pattern.allMatches(context.sourceText)) {
    // 3. Generate replacement
    final replacement = generateReplacement(match);
    yield Patch(replacement, match.start, match.end);
  }
}
```

**For AST approach**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class MySuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  bool shouldResolveAst(FileContext context) => false; // true if need types
  
  @override
  void visitTargetNode(TargetNode node) {
    // 1. Check if this node matches
    if (!shouldTransform(node)) {
      super.visitTargetNode(node);
      return;
    }
    
    // 2. Generate patch
    yieldPatch(generateReplacement(node), node.offset, node.end);
    
    // 3. Continue traversal
    super.visitTargetNode(node);
  }
  
  bool shouldTransform(TargetNode node) {
    // Your matching logic
    return true;
  }
  
  String generateReplacement(TargetNode node) {
    // Your transformation logic
    return 'new code';
  }
}
```

### Phase 4: Create Runner Script

```dart
import 'dart:io';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart', recursive: true)),
    MySuggestor().call, // or mySuggestor for non-AST
    args: args,
  );
}
```

---

## Complete Examples with Real Diffs

### Example 1: Simple Method Rename

**Diff**:
```diff
- oldMethod();
+ newMethod();
```

**Analysis**:
- Type: Replacement
- Pattern: Method call `oldMethod()`
- Approach: AST-based (need to match method calls, not just text)

**Step-by-Step Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class MethodRename extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Step 1: Check if method name matches
    if (node.methodName.name == 'oldMethod') {
      // Step 2: Replace only the method name, keep arguments
      // node.methodName.offset to node.methodName.end covers just the name
      yieldPatch('newMethod', node.methodName.offset, node.methodName.end);
    }
    
    // Step 3: Always call super to continue traversal
    super.visitMethodInvocation(node);
  }
}
```

**Key Points**:
- Use `node.methodName.offset` and `node.methodName.end` (not `node.offset`)
- This preserves arguments: `oldMethod(arg1, arg2)` → `newMethod(arg1, arg2)`
- Must call `super.visitMethodInvocation(node)` to continue

### Example 2: Add Annotation to Classes

**Diff**:
```diff
+ @Serializable()
  class MyClass {
    // ...
  }
```

**Analysis**:
- Type: Insertion
- Pattern: Classes without `@Serializable()` annotation
- Approach: AST-based (need to check existing annotations)

**Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class AddSerializableAnnotation extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Step 1: Check if annotation already exists
    final hasAnnotation = node.metadata.any((annotation) => 
      annotation.name.name == 'Serializable');
    
    // Step 2: Only add if missing
    if (!hasAnnotation) {
      // Step 3: Insert at the start of class declaration
      // node.offset is the start of the class keyword
      yieldPatch('@Serializable()\n', node.offset, node.offset);
    }
    
    super.visitClassDeclaration(node);
  }
}
```

**Key Points**:
- Check `node.metadata` for existing annotations
- Use `node.offset` for insertion (same start and end = insertion)
- Add `\n` after annotation for proper formatting

### Example 3: Remove Deprecated Code

**Diff**:
```diff
- @Deprecated('Use newMethod instead')
- void oldMethod() {
-   print('old');
- }
```

**Analysis**:
- Type: Deletion
- Pattern: Declarations with `@Deprecated` annotation
- Approach: AST-based (need to identify declarations with annotations)

**Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class RemoveDeprecated extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  
  // Helper to check if node is deprecated
  static bool isDeprecated(AnnotatedNode node) {
    return node.metadata.any((annotation) => 
      annotation.name.name.toLowerCase() == 'deprecated');
  }
  
  @override
  void visitDeclaration(Declaration node) {
    // Step 1: Check if deprecated
    if (isDeprecated(node)) {
      // Step 2: Delete entire declaration
      // Empty string = deletion
      // node.offset to node.end covers the whole declaration
      yieldPatch('', node.offset, node.end);
    }
    
    // Note: Don't call super for GeneralizingAstVisitor
    // It automatically visits children
  }
}
```

**Key Points**:
- Use `GeneralizingAstVisitor` to catch all declaration types
- Empty string `''` = deletion
- `node.offset` to `node.end` covers entire node including annotations

### Example 4: Update Package Version in pubspec.yaml

**Diff**:
```diff
  dependencies:
-   codemod: ^1.2.0
+   codemod: ^1.3.0
```

**Analysis**:
- Type: Replacement
- Pattern: Version constraint in YAML
- Approach: Non-AST (YAML file, regex pattern)

**Solution**:

```dart
import 'package:codemod/codemod.dart';

Stream<Patch> updateCodemodVersion(FileContext context) async* {
  // Step 1: Define pattern to match version line
  // Captures: codemod: <version>
  final pattern = RegExp(
    r'^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$',
    multiLine: true, // Match across lines
  );
  
  const newVersion = '^1.3.0';
  
  // Step 2: Find all matches
  for (final match in pattern.allMatches(context.sourceText)) {
    // Step 3: Extract the old version (group 1)
    final oldVersion = match.group(1)!;
    
    // Step 4: Build replacement line
    // match.group(0) is the full line
    final fullLine = match.group(0)!;
    final updatedLine = fullLine.replaceFirst(oldVersion, newVersion);
    
    // Step 5: Generate patch
    yield Patch('$updatedLine\n', match.start, match.end);
  }
}
```

**Key Points**:
- Use regex with `multiLine: true` for line-based patterns
- `match.group(0)` = full match, `match.group(1)` = first capture
- Preserve whitespace in replacement

### Example 5: Convert Positional to Named Parameters

**Diff**:
```diff
- processData(value1, value2);
+ processData(value1: value1, value2: value2);
```

**Analysis**:
- Type: Replacement
- Pattern: Method calls with positional arguments
- Approach: AST-based (need to access argument list)

**Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class NamedParameters extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Step 1: Check if this is the target method
    if (node.methodName.name != 'processData') {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Step 2: Check if already using named parameters
    final args = node.argumentList.arguments;
    if (args.isEmpty) {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Check if all are already named
    if (args.every((arg) => arg is NamedExpression)) {
      super.visitMethodInvocation(node);
      return;
    }
    
    // Step 3: Convert arguments to named
    final namedArgs = <String>[];
    for (final arg in args) {
      if (arg is NamedExpression) {
        // Already named, keep as is
        namedArgs.add(arg.toString());
      } else {
        // Positional, convert to named
        // Extract variable name from expression
        final argName = extractVariableName(arg);
        namedArgs.add('$argName: ${arg.toString()}');
      }
    }
    
    // Step 4: Build new call
    final newCall = '${node.methodName.name}(${namedArgs.join(', ')})';
    
    // Step 5: Replace entire method invocation
    yieldPatch(newCall, node.offset, node.end);
    
    super.visitMethodInvocation(node);
  }
  
  String extractVariableName(Expression expr) {
    // Handle simple identifiers
    if (expr is SimpleIdentifier) {
      return expr.name;
    }
    // For complex expressions, you might need different logic
    // This is a simplified version
    return expr.toString().split('.').first;
  }
}
```

**Key Points**:
- Access `node.argumentList.arguments` for arguments
- Check `arg is NamedExpression` to detect named parameters
- Replace entire `node.offset` to `node.end` for full call

### Example 6: Add Import Statement

**Diff**:
```diff
+ import 'package:new_package/new_package.dart';
  import 'package:other/other.dart';
```

**Analysis**:
- Type: Insertion
- Pattern: Files missing specific import
- Approach: AST-based (check existing imports)

**Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class AddImport extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  static const String targetImport = "import 'package:new_package/new_package.dart';";
  
  @override
  void visitCompilationUnit(CompilationUnit node) {
    // Step 1: Check if import already exists
    final hasImport = node.directives.any((directive) =>
      directive is ImportDirective &&
      directive.uri.stringValue == 'package:new_package/new_package.dart');
    
    if (hasImport) {
      super.visitCompilationUnit(node);
      return;
    }
    
    // Step 2: Find insertion point (after last import or at start)
    int insertOffset = node.offset;
    
    // Find the last import directive
    final imports = node.directives
        .whereType<ImportDirective>()
        .toList();
    
    if (imports.isNotEmpty) {
      // Insert after last import
      final lastImport = imports.last;
      insertOffset = lastImport.end;
    }
    
    // Step 3: Add newline if needed
    final insertText = node.directives.isEmpty 
        ? '$targetImport\n'
        : '\n$targetImport\n';
    
    // Step 4: Generate patch
    yieldPatch(insertText, insertOffset, insertOffset);
    
    super.visitCompilationUnit(node);
  }
}
```

**Key Points**:
- Check `node.directives` for existing imports
- Find appropriate insertion point
- Handle both empty and non-empty import sections

### Example 7: Replace Type Annotation

**Diff**:
```diff
- List<String> items;
+ List<String?> items;
```

**Analysis**:
- Type: Replacement
- Pattern: Type annotations `List<String>`
- Approach: AST-based (need type information, but can use unresolved AST)

**Solution**:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

class MakeStringNullable extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  void visitTypeAnnotation(TypeAnnotation node) {
    final type = node.type;
    
    // Step 1: Check if it's a List type
    if (type is! NamedType || type.name.name != 'List') {
      super.visitTypeAnnotation(node);
      return;
    }
    
    // Step 2: Check type arguments
    final typeArgs = type.typeArguments;
    if (typeArgs == null || typeArgs.arguments.isEmpty) {
      super.visitTypeAnnotation(node);
      return;
    }
    
    // Step 3: Check if first argument is String (non-nullable)
    final firstArg = typeArgs.arguments.first;
    if (firstArg is! NamedType || 
        firstArg.name.name != 'String' ||
        firstArg.isNullable) {
      super.visitTypeAnnotation(node);
      return;
    }
    
    // Step 4: Replace with nullable version
    yieldPatch('List<String?>', node.offset, node.end);
    
    super.visitTypeAnnotation(node);
  }
}
```

**Key Points**:
- Check `type is NamedType` for named types
- Access `type.typeArguments.arguments` for generic parameters
- Check `isNullable` property

---

## AST Node Reference Guide

### Common AST Nodes

#### CompilationUnit
Root of the AST. Contains all top-level declarations.

```dart
void visitCompilationUnit(CompilationUnit node) {
  // Access: node.directives (imports, exports)
  // Access: node.declarations (classes, functions, etc.)
}
```

#### ClassDeclaration
Class definitions.

```dart
void visitClassDeclaration(ClassDeclaration node) {
  // Access: node.name (class name)
  // Access: node.metadata (annotations)
  // Access: node.members (methods, fields, etc.)
  // Access: node.extendsClause (superclass)
  // Access: node.implementsClause (interfaces)
  // Access: node.withClause (mixins)
}
```

#### MethodDeclaration
Method definitions.

```dart
void visitMethodDeclaration(MethodDeclaration node) {
  // Access: node.name (method name)
  // Access: node.returnType (return type)
  // Access: node.parameters (parameters)
  // Access: node.body (method body)
  // Access: node.metadata (annotations)
}
```

#### MethodInvocation
Method calls.

```dart
void visitMethodInvocation(MethodInvocation node) {
  // Access: node.methodName (method name identifier)
  // Access: node.target (receiver object, if any)
  // Access: node.argumentList.arguments (arguments)
  // Access: node.staticType (type, requires resolved AST)
}
```

#### VariableDeclaration
Variable declarations.

```dart
void visitVariableDeclaration(VariableDeclaration node) {
  // Access: node.name (variable name)
  // Access: node.type (type annotation)
  // Access: node.initializer (initial value)
  // Access: node.metadata (annotations)
}
```

#### TypeAnnotation
Type annotations.

```dart
void visitTypeAnnotation(TypeAnnotation node) {
  // Access: node.type (the type itself)
  // If node.type is NamedType:
  //   - node.type.name.name (type name)
  //   - node.type.typeArguments (generic arguments)
  //   - node.type.isNullable (nullable check)
}
```

#### ImportDirective
Import statements.

```dart
void visitImportDirective(ImportDirective node) {
  // Access: node.uri.stringValue (import URI)
  // Access: node.prefix (import prefix, if any)
  // Access: node.combinators (show/hide clauses)
}
```

### Key Properties

**Offset Properties**:
- `node.offset` - Start character position (inclusive)
- `node.end` - End character position (exclusive)
- `node.length` - Length in characters

**Name Properties**:
- `node.name` - Name identifier (for named nodes)
- `node.name.name` - String name value

**Structure Properties**:
- `node.metadata` - List of annotations
- `node.parent` - Parent node
- `node.thisOrAncestorOfType<T>()` - Find ancestor of type T

**Type Properties** (require resolved AST):
- `node.staticType` - Static type of expression
- `node.staticType.isDartCoreInt` - Check if type is int
- `node.staticType.isDartCoreString` - Check if type is String

### Visitor Types

**RecursiveAstVisitor**:
- Visits all nodes recursively
- Must call `super.visitX()` to continue
- Use when you need fine control

**GeneralizingAstVisitor**:
- Visits nodes by category (declarations, statements, expressions)
- Automatically visits children
- Use when you want to catch all nodes of a category

**SimpleAstVisitor**:
- Only visits specific node types you override
- Fastest, but most limited
- Use when you only care about specific nodes

---

## Common Patterns Library

### Pattern 1: Conditional Transformation

```dart
@override
void visitTargetNode(TargetNode node) {
  // Always check conditions first
  if (!shouldTransform(node)) {
    super.visitTargetNode(node);
    return; // Early return
  }
  
  // Transform
  yieldPatch(transform(node), node.offset, node.end);
  
  // Continue
  super.visitTargetNode(node);
}

bool shouldTransform(TargetNode node) {
  // Your conditions
  return node.meetsCriteria();
}
```

### Pattern 2: Preserve Context

When replacing, preserve surrounding code:

```dart
// Bad: Replaces too much
yieldPatch('new', node.offset, node.end);

// Good: Replace only what needs changing
yieldPatch('newName', node.name.offset, node.name.end);
```

### Pattern 3: Multi-line Insertions

```dart
final newCode = '''
// New code line 1
// New code line 2
''';

// Insert before node
yieldPatch(newCode, node.offset, node.offset);

// Insert after node
yieldPatch('\n$newCode', node.end, node.end);
```

### Pattern 4: Handling Optional Nodes

```dart
@override
void visitMethodDeclaration(MethodDeclaration node) {
  // Check if return type exists
  if (node.returnType != null) {
    // Transform return type
    yieldPatch('NewReturnType', 
      node.returnType!.offset, 
      node.returnType!.end);
  }
  
  super.visitMethodDeclaration(node);
}
```

### Pattern 5: Finding Ancestors

```dart
@override
void visitExpression(Expression node) {
  // Find containing method
  final method = node.thisOrAncestorOfType<MethodDeclaration>();
  if (method != null && method.name.name == 'targetMethod') {
    // Transform only in specific context
    yieldPatch('transformed', node.offset, node.end);
  }
  
  super.visitExpression(node);
}
```

### Pattern 6: Text-based with Context

```dart
Stream<Patch> contextualReplace(FileContext context) async* {
  final text = context.sourceText;
  
  // Find pattern with context
  final pattern = RegExp(
    r'oldMethod\(([^)]+)\)', // Match oldMethod(...)
    dotAll: true, // . matches newlines
  );
  
  for (final match in pattern.allMatches(text)) {
    // Extract captured groups
    final args = match.group(1)!;
    
    // Build replacement with context
    final replacement = 'newMethod($args)';
    
    yield Patch(replacement, match.start, match.end);
  }
}
```

---

## Troubleshooting Guide

### Problem: Patches Not Applying

**Symptoms**: Codemod runs but no changes made

**Solutions**:
1. Check if pattern matches: Add logging
   ```dart
   logger.info('Checking file: ${context.relativePath}');
   logger.info('Contains pattern: ${context.sourceText.contains('target')}');
   ```

2. Verify offsets are correct: Use `node.offset` and `node.end`, not line numbers

3. Check if already transformed:
   ```dart
   if (context.sourceText.contains('newPattern')) {
     logger.fine('Already transformed, skipping');
     return;
   }
   ```

### Problem: Wrong Text Replaced

**Symptoms**: More or less text replaced than intended

**Solutions**:
1. Use specific node offsets, not parent node:
   ```dart
   // Bad: Replaces entire method
   yieldPatch('new', node.offset, node.end);
   
   // Good: Replaces only method name
   yieldPatch('new', node.name.offset, node.name.end);
   ```

2. For text-based: Be precise with regex:
   ```dart
   // Bad: Too broad
   final pattern = RegExp(r'old');
   
   // Good: Specific
   final pattern = RegExp(r'\boldMethod\b'); // Word boundary
   ```

### Problem: Overlapping Patches

**Symptoms**: Error about overlapping patches

**Solutions**:
1. Ensure patches don't overlap:
   ```dart
   // Bad
   yieldPatch('a', 0, 10);
   yieldPatch('b', 5, 15); // Overlaps!
   
   // Good
   yieldPatch('a', 0, 10);
   yieldPatch('b', 10, 20); // Adjacent or separate
   ```

2. Sort patches by offset if generating multiple

### Problem: AST Node is Null

**Symptoms**: Null pointer exceptions

**Solutions**:
1. Always check for null:
   ```dart
   if (node.returnType == null) return;
   if (node.typeArguments == null) return;
   ```

2. Use null-aware operators:
   ```dart
   final typeName = node.type?.name?.name ?? 'unknown';
   ```

### Problem: Type Information Not Available

**Symptoms**: `staticType` is null

**Solutions**:
1. Enable resolved AST:
   ```dart
   @override
   bool shouldResolveAst(FileContext context) => true;
   ```

2. Check if type is available:
   ```dart
   if (node.staticType == null) {
     // Handle case where type is unknown
     return;
   }
   ```

### Problem: Regex Not Matching

**Symptoms**: Pattern exists but regex doesn't match

**Solutions**:
1. Use correct flags:
   ```dart
   RegExp(r'pattern', multiLine: true, dotAll: true)
   ```

2. Escape special characters:
   ```dart
   RegExp(r'\(\)') // Matches literal "()"
   ```

3. Use word boundaries for whole words:
   ```dart
   RegExp(r'\bmethod\b') // Matches "method" but not "myMethod"
   ```

### Problem: Code Formatting Issues

**Symptoms**: Generated code has wrong indentation/formatting

**Solutions**:
1. Preserve original formatting when possible
2. Use `dart format` after codemod runs
3. Match indentation:
   ```dart
   // Get line start
   final lineStart = context.sourceFile.getOffset(node.startLine);
   final indent = context.sourceText.substring(
     lineStart, 
     node.offset
   );
   final newCode = '$indent$transformedCode';
   ```

---

## Quick Decision Tree

```
Start: Need to transform code
│
├─ Is it a simple string replacement?
│  └─ YES → Use Non-AST (Regex/Text)
│     └─ Pattern: context.sourceText.indexOf() or RegExp
│
├─ Is it a file-level change (header/footer)?
│  └─ YES → Use Non-AST (Text)
│     └─ Pattern: Check start/end of file, insert at offset 0 or end
│
├─ Does it involve Dart code structure?
│  └─ YES → Use AST-based
│     │
│     ├─ Need type information?
│     │  └─ YES → Set shouldResolveAst() => true
│     │  └─ NO → Use unresolved AST (faster)
│     │
│     ├─ What node type?
│     │  ├─ Method calls → visitMethodInvocation
│     │  ├─ Classes → visitClassDeclaration
│     │  ├─ Variables → visitVariableDeclaration
│     │  ├─ Types → visitTypeAnnotation
│     │  └─ All declarations → visitDeclaration (GeneralizingAstVisitor)
│     │
│     └─ Which visitor?
│        ├─ Need all nodes → RecursiveAstVisitor
│        ├─ Need by category → GeneralizingAstVisitor
│        └─ Need specific only → SimpleAstVisitor
│
└─ Complex pattern?
   └─ Use AST-based for robustness
```

---

## Critical Rules for AI

### Rule 1: Always Check Before Patching

```dart
// NEVER do this:
yieldPatch('new', node.offset, node.end);

// ALWAYS do this:
if (shouldTransform(node)) {
  yieldPatch('new', node.offset, node.end);
}
```

### Rule 2: Always Call super (for RecursiveAstVisitor)

```dart
@override
void visitMethodInvocation(MethodInvocation node) {
  // Your logic
  yieldPatch('new', node.offset, node.end);
  
  // MUST call super
  super.visitMethodInvocation(node);
}
```

### Rule 3: Use Correct Offsets

```dart
// For method name only:
node.methodName.offset to node.methodName.end

// For entire method call:
node.offset to node.end

// For insertion:
same offset for start and end: node.offset, node.offset
```

### Rule 4: Handle Edge Cases

```dart
// Check empty files
if (context.sourceText.isEmpty) return;

// Check if already transformed
if (isAlreadyTransformed(context)) return;

// Check if node exists
if (node.returnType == null) return;
```

### Rule 5: Test Your Logic

When generating codemod, think about:
- What if the pattern appears multiple times?
- What if it's already transformed?
- What if the file is empty?
- What if the node structure is different?

---

## Complete Template

Use this template as a starting point:

```dart
import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

// OPTION 1: Non-AST Suggestor
Stream<Patch> myTextSuggestor(FileContext context) async* {
  // Early exits
  if (context.sourceText.isEmpty) return;
  if (!context.sourceText.contains('target')) return;
  
  // Find and replace
  final pattern = RegExp(r'targetPattern');
  for (final match in pattern.allMatches(context.sourceText)) {
    yield Patch('replacement', match.start, match.end);
  }
}

// OPTION 2: AST-based Suggestor
class MyAstSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  
  @override
  bool shouldResolveAst(FileContext context) => false; // true if need types
  
  @override
  void visitTargetNode(TargetNode node) {
    // Check conditions
    if (!shouldTransform(node)) {
      super.visitTargetNode(node);
      return;
    }
    
    // Generate patch
    yieldPatch(transform(node), node.offset, node.end);
    
    // Continue traversal
    super.visitTargetNode(node);
  }
  
  bool shouldTransform(TargetNode node) {
    // Your matching logic
    return true;
  }
  
  String transform(TargetNode node) {
    // Your transformation logic
    return 'new code';
  }
}

// Runner
void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    filePathsFromGlob(Glob('lib/**/*.dart', recursive: true)),
    MyAstSuggestor().call, // or myTextSuggestor
    args: args,
  );
}
```

---

## Summary Checklist

When generating a codemod from a diff:

- [ ] Analyzed the diff type (insert/delete/replace)
- [ ] Chose appropriate approach (AST vs non-AST)
- [ ] Identified target node type or pattern
- [ ] Added early exit conditions
- [ ] Added checks to avoid no-op patches
- [ ] Used correct offsets (node.offset/node.end)
- [ ] Called super.visitX() for RecursiveAstVisitor
- [ ] Handled null cases
- [ ] Tested edge cases (empty files, already transformed)
- [ ] Created runner script with file selection

This comprehensive guide should enable AI assistants to generate effective, correct codemod scripts from any code diff.
