// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// To run this example:
///     $ cd example
///     $ dart regex_substituter.dart
library dart_codemod.example.regex_substituter;

import 'package:codemod_core/codemod_core.dart';

/// Pattern that matches a dependency version constraint line for the `codemod`
/// package, with the first capture group being the constraint.
final RegExp pattern = RegExp(
  r'''^\s*codemod:\s*([\d\s"'<>=^.]+)\s*$''',
  multiLine: true,
);

/// The version constraint that `codemod` entries should be updated to.
const String targetConstraint = '^1.0.0';

Stream<Patch> regexSubstituter(FileContext context) async* {
  for (final match in pattern.allMatches(context.sourceText)) {
    final line = match.group(0)!;
    final constraint = match.group(1)!;
    final updated = '${line.replaceFirst(constraint, targetConstraint)}\n';

    yield Patch(updated, match.start, match.end);
  }
}
