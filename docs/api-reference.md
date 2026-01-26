# API Reference

Complete API documentation for the `codemod` package.

## Core Types

### Suggestor

```dart
typedef Suggestor = Stream<Patch> Function(FileContext context);
```

A function that takes a `FileContext` and returns a `Stream<Patch>`. This is the core abstraction for code transformations.

**Parameters:**
- `context` - The `FileContext` for the file being processed

**Returns:**
- A `Stream<Patch>` containing all patches to apply to the file

**Example:**
```dart
Stream<Patch> mySuggestor(FileContext context) async* {
  // Generate patches
  yield Patch('new text', 0, 10);
}
```

## Core Functions

### runInteractiveCodemod

```dart
Future<int> runInteractiveCodemod(
  Iterable<String> filePaths,
  Suggestor suggestor, {
  Iterable<String> args = const [],
  bool defaultYes = false,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
})
```

Runs a codemod interactively, showing diffs and prompting the user for each patch.

**Parameters:**
- `filePaths` - List of file paths to process
- `suggestor` - The suggestor function to run
- `args` - Command-line arguments (optional)
- `defaultYes` - If true, default action is "yes" (optional, default: false)
- `additionalHelpOutput` - Additional help text to display (optional)
- `changesRequiredOutput` - Message to show when changes are required in fail-on-changes mode (optional)

**Returns:**
- Exit code (0 for success, non-zero for errors)

**Example:**
```dart
exitCode = await runInteractiveCodemod(
  ['lib/foo.dart', 'lib/bar.dart'],
  mySuggestor,
  args: args,
);
```

### runInteractiveCodemodSequence

```dart
Future<int> runInteractiveCodemodSequence(
  Iterable<String> filePaths,
  Iterable<Suggestor> suggestors, {
  Iterable<String> args = const [],
  bool defaultYes = false,
  String? additionalHelpOutput,
  String? changesRequiredOutput,
})
```

Runs multiple suggestors sequentially on the same set of files.

**Parameters:**
- `filePaths` - List of file paths to process
- `suggestors` - List of suggestors to run in sequence
- `args` - Command-line arguments (optional)
- `defaultYes` - If true, default action is "yes" (optional)
- `additionalHelpOutput` - Additional help text (optional)
- `changesRequiredOutput` - Message for fail-on-changes mode (optional)

**Returns:**
- Exit code (0 for success, non-zero for errors)

**Example:**
```dart
exitCode = await runInteractiveCodemodSequence(
  filePaths,
  [suggestor1, suggestor2, suggestor3],
  args: args,
);
```

### aggregate

```dart
Suggestor aggregate(Iterable<Suggestor> suggestors)
```

Combines multiple suggestors into a single suggestor that yields all patches from all suggestors.

**Parameters:**
- `suggestors` - List of suggestors to combine

**Returns:**
- A single `Suggestor` that combines all input suggestors

**Example:**
```dart
final combined = aggregate([
  licenseHeaderInserter,
  deprecationRemover,
  versionUpdater,
]);
```

## Core Classes

### FileContext

Provides access to file contents and analyzed formats.

#### Properties

- `String path` - Absolute path to the file
- `String relativePath` - Path relative to the root directory
- `String root` - Root directory path
- `String sourceText` - Contents of the file
- `SourceFile sourceFile` - Source file representation for span references

#### Methods

##### getUnresolvedUnit()

```dart
CompilationUnit getUnresolvedUnit()
```

Returns the unresolved AST for the file. Fast but doesn't include type information.

**Returns:**
- `CompilationUnit` - The parsed but unresolved AST

**Throws:**
- `ArgumentError` if the file has parse errors

##### getResolvedUnit()

```dart
Future<ResolvedUnitResult?> getResolvedUnit()
```

Returns the fully resolved AST for the file. Slower but includes type information.

**Returns:**
- `ResolvedUnitResult?` - The resolved AST result, or null if resolution fails

##### getResolvedLibrary()

```dart
Future<ResolvedLibraryResult?> getResolvedLibrary()
```

Returns the fully resolved library result, including `LibraryElement`.

**Returns:**
- `ResolvedLibraryResult?` - The resolved library result, or null if resolution fails

### Patch

Represents a change to a source file.

#### Constructor

```dart
Patch(String updatedText, int startOffset, [int? endOffset])
```

**Parameters:**
- `updatedText` - Text to insert/replace (empty string for deletion)
- `startOffset` - Start offset in the file
- `endOffset` - End offset (optional, defaults to startOffset for insertion, or end of file if null)

#### Properties

- `String updatedText` - Text to write
- `int startOffset` - Start offset
- `int? endOffset` - End offset

#### Types of Patches

- **Insertion**: `startOffset == endOffset`, non-empty `updatedText`
- **Deletion**: `startOffset < endOffset`, empty `updatedText`
- **Replacement**: `startOffset < endOffset`, non-empty `updatedText`

### SourcePatch

A `Patch` associated with a `SourceFile`, with additional rendering utilities.

#### Constructor

```dart
SourcePatch(SourceFile sourceFile, SourceSpan sourceSpan, String updatedText)
SourcePatch.from(Patch patch, SourceFile sourceFile)
```

#### Properties

- `SourceFile sourceFile` - The source file
- `SourceSpan sourceSpan` - The span being modified
- `String updatedText` - Text to write
- `bool isNoop` - True if patch makes no changes
- `int startLine` - 0-based start line number
- `int endLine` - 0-based end line number
- `int startOffset` - Start offset
- `int endOffset` - End offset

#### Methods

##### renderDiff(int numRowsToPrint)

```dart
String renderDiff(int numRowsToPrint)
```

Returns a multi-line string diff representation of the patch.

**Parameters:**
- `numRowsToPrint` - Maximum number of lines to include

**Returns:**
- Formatted diff string with context

##### renderRange()

```dart
String renderRange()
```

Returns the line range of the patch (e.g., `"./lib/foo.dart:10-12"`).

**Returns:**
- String representation of the patch location

### AstVisitingSuggestor

A mixin that makes it easy to write suggestors using the AST visitor pattern.

#### Usage

```dart
class MySuggestor extends GeneralizingAstVisitor<void>
    with AstVisitingSuggestor {
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Process method declarations
    yieldPatch('new code', node.offset, node.end);
  }
}
```

#### Methods

##### shouldResolveAst(FileContext context)

```dart
bool shouldResolveAst(FileContext context) => false;
```

Override to return `true` if you need resolved AST (for type information).

##### shouldSkip(FileContext context)

```dart
bool shouldSkip(FileContext context) => false;
```

Override to skip processing certain files.

##### yieldPatch(String updatedText, int startOffset, [int? endOffset])

```dart
void yieldPatch(String updatedText, int startOffset, [int? endOffset])
```

Generate a patch. Only callable within visitor methods.

**Parameters:**
- `updatedText` - Text to insert/replace
- `startOffset` - Start offset
- `endOffset` - End offset (optional)

#### Properties

- `FileContext context` - Current file context (only available in visitor methods)

### FileFilter

Filters file paths based on include/exclude patterns.

#### Constructor

```dart
FileFilter(FileFilterConfig config)
```

#### Methods

##### shouldInclude(String filePath)

```dart
bool shouldInclude(String filePath)
```

Checks if a file path should be included.

**Returns:**
- `true` if the file should be included

##### filterFiles(Iterable<String> filePaths)

```dart
Iterable<String> filterFiles(Iterable<String> filePaths)
```

Filters a list of file paths.

**Returns:**
- Filtered list of file paths

### FileFilterConfig

Configuration for file filtering.

#### Constructor

```dart
const FileFilterConfig({
  List<String> includePatterns = const [],
  List<String> excludePatterns = const [],
  bool ignoreHidden = true,
  bool ignoreDartHidden = true,
})
```

#### Properties

- `List<String> includePatterns` - Glob patterns for files to include
- `List<String> excludePatterns` - Glob patterns for files to exclude
- `bool ignoreHidden` - Whether to ignore hidden files
- `bool ignoreDartHidden` - Whether to ignore Dart-specific hidden files

#### Factory

##### fromMap(Map<String, dynamic> map)

```dart
factory FileFilterConfig.fromMap(Map<String, dynamic> map)
```

Creates a config from a map (e.g., from YAML).

### CodemodStats

Statistics about codemod execution.

#### Properties

- `int filesProcessed` - Number of files processed
- `int filesModified` - Number of files modified
- `int patchesSuggested` - Number of patches suggested
- `int patchesApplied` - Number of patches applied
- `int patchesSkipped` - Number of patches skipped
- `int patchesIgnored` - Number of patches ignored (via ignore comments)
- `int errors` - Number of errors encountered
- `DateTime? startTime` - Start time
- `DateTime? endTime` - End time
- `Duration? duration` - Execution duration

#### Methods

##### reset()

```dart
void reset()
```

Resets all statistics.

##### getSummary()

```dart
String getSummary()
```

Returns a formatted summary string.

## Utility Functions

### filePathsFromGlob

```dart
Iterable<String> filePathsFromGlob(Glob glob, {bool? ignoreHiddenFiles})
```

Returns file paths matched by a glob pattern.

**Parameters:**
- `glob` - Glob pattern
- `ignoreHiddenFiles` - Whether to ignore hidden files (default: true)

**Returns:**
- Iterable of file paths

### isHiddenFile / isNotHiddenFile

```dart
bool isHiddenFile(File file)
bool isNotHiddenFile(File file)
```

Check if a file is hidden (starts with `.`).

### isDartHiddenFile / isNotDartHiddenFile

```dart
bool isDartHiddenFile(File file)
bool isNotDartHiddenFile(File file)
```

Check if a file is a Dart-specific hidden file (`.packages`, `.dart_tool`).

### filterIgnoredPatches

```dart
List<SourcePatch> filterIgnoredPatches(
  List<SourcePatch> patches,
  String sourceText,
)
```

Filters out patches that should be ignored based on ignore comments.

**Parameters:**
- `patches` - List of patches to filter
- `sourceText` - Source file text

**Returns:**
- Filtered list of patches

### shouldIgnorePatch

```dart
bool shouldIgnorePatch(SourcePatch patch, String sourceText)
```

Checks if a patch should be ignored based on ignore comments.

**Returns:**
- `true` if the patch should be ignored

## Testing Utilities

See `package:codemod/test.dart` for testing utilities:

- `fileContextForTest(String name, String sourceText)` - Create a test file context
- `expectSuggestorGeneratesPatches(Suggestor, FileContext, dynamic)` - Assert suggestor output
- `PackageContextForTest` - Test suggestors that need resolved AST
