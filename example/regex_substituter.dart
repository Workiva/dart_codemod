import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

/// Pattern that matches a dependency version constraint line for the `codemod`
/// package, with the first capture group being the constraint.
final RegExp pattern = RegExp(r'''^\s*codemod:\s*([\d\s"'<>=^.]+)$''');

/// The version constraint that `codemod` entries should be updated to.
const String targetConstraint = '^1.0.0';

class RegexSubstituter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) => false;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    for (final match in pattern.allMatches(contents)) {
      final line = match.group(0);
      final constraint = match.group(1);
      final updated = line.replaceFirst(constraint, targetConstraint);

      yield Patch(
        sourceFile,
        sourceFile.span(match.start, match.end),
        updated,
      );
    }
  }
}

void main(List<String> args) => runInteractiveCodemod(
      FileQuery.single('pubspec.yaml'),
      RegexSubstituter(),
      args: args,
    );
