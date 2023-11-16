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

import 'dart:io';
import 'dart:math' as math;

import 'package:codemod_core/codemod_core.dart';
import 'package:io/ansi.dart';

import 'constants.dart';

/// Finds overlapping patches and prompts the user to decide how to handle them.
///
/// The user can either skip the patch and continue running the codemod, or
/// choose to quit the codemod.
List<Patch> promptToHandleOverlappingPatches(Iterable<Patch> patches) {
  final skippedPatches = <Patch>[];
  final sortedPatches = patches.toList()..sort();

  int? lastEdgeOffset = 0;
  late Patch prev;
  for (final patch in sortedPatches) {
    // If lastEdgeOffset is null, then the previous patch had no end offset,
    // which means it implicitly extends to the end of file. In that case, any
    // subsequent patch will overlap. Otherwise we just check if the next patch
    // starts before the previous one ended.
    if (lastEdgeOffset == null || patch.startOffset < lastEdgeOffset) {
      stdout.writeln(
          'A patch that overlaps with a previous patch applied was found. '
          'Do you want to skip this patch, or quit the codemod?\n'
          'Previous patch:\n'
          '  $prev\n'
          '  Updated text: ${prev.updatedText}\n'
          'Overlapping patch:\n'
          '  $patch\n'
          '  Updated text: ${patch.updatedText}\n'
          '(s = skip this patch and apply the rest [default],\n'
          'q = quit)');

      var choice = prompt('sq', 's');

      if (choice == 's') {
        skippedPatches.add(patch);
      }

      if (choice == 'q') {
        // Returns the current list of skipped patches without adding the current
        // patch, as the user has opted to quit the codemod. When `applyPatches`
        // is called without the overlapping patch removed, it will throw an
        // exception, but guarantee that other patches and skipped patches up to
        // the current one are still applied.
        return skippedPatches;
      }
    }
    lastEdgeOffset = patch.endOffset;
    prev = patch;
  }
  return skippedPatches;
}

/// Returns the number of lines that a patch diff should be constrained to.
/// Based on the stdout terminal size if available, or a sane default if not.
int calculateDiffSize(Stdout stdout) {
  return stdout.hasTerminal
      // Try to leave some room at the bottom of the terminal for user prompts.
      ? math.max(10, stdout.terminalLines - 10)
      // Sane default when there is no terminal.
      : 10;
}

/// Prompts the user to select an action via stdin.
///
/// [letters] is the string of valid one-letter responses. In other words, if
/// [letters] is `yn` then the two valid responses are `y` and `n`.
///
/// [defaultChoice] will be returned if non-null and the user returns without
/// entering anything.
String prompt([String letters = 'yn', String? defaultChoice]) {
  while (true) {
    final response = stdin.readLineSync();
    if (response == null || response.length > 1) {
      stdout.writeln('Come again? (only enter a single character)');
      continue;
    }
    if (response.isNotEmpty && letters.contains(response)) {
      return response;
    }
    if (defaultChoice != null && response.isEmpty) {
      return defaultChoice;
    }
    stdout.writeln('Come again?');
  }
}

/// Returns a character sequence that "clears" the terminal.
///
/// If ansi output is enabled, the ansi escape code for clearing the terminal
/// will be returned. Otherwise, several newlines will be returned to achieve
/// roughly the same effect.
String terminalClear() {
  return ansiOutputEnabled ? '$ansiClearScreen$ansiCursorHome' : '\n' * 8;
}
