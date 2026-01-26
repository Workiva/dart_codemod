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

/// Statistics about codemod execution.
class CodemodStats {
  /// Number of files processed.
  int filesProcessed = 0;

  /// Number of files modified.
  int filesModified = 0;

  /// Number of patches suggested.
  int patchesSuggested = 0;

  /// Number of patches applied.
  int patchesApplied = 0;

  /// Number of patches skipped.
  int patchesSkipped = 0;

  /// Number of patches ignored (via ignore comments).
  int patchesIgnored = 0;

  /// Number of errors encountered.
  int errors = 0;

  /// Start time of codemod execution.
  DateTime? startTime;

  /// End time of codemod execution.
  DateTime? endTime;

  /// Duration of codemod execution.
  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  /// Resets all statistics.
  void reset() {
    filesProcessed = 0;
    filesModified = 0;
    patchesSuggested = 0;
    patchesApplied = 0;
    patchesSkipped = 0;
    patchesIgnored = 0;
    errors = 0;
    startTime = null;
    endTime = null;
  }

  /// Returns a summary string of the statistics.
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Codemod Statistics:');
    buffer.writeln('  Files processed: $filesProcessed');
    buffer.writeln('  Files modified: $filesModified');
    buffer.writeln('  Patches suggested: $patchesSuggested');
    buffer.writeln('  Patches applied: $patchesApplied');
    buffer.writeln('  Patches skipped: $patchesSkipped');
    buffer.writeln('  Patches ignored: $patchesIgnored');
    if (errors > 0) {
      buffer.writeln('  Errors: $errors');
    }
    if (duration != null) {
      buffer.writeln('  Duration: ${duration!.inSeconds}s');
    }
    return buffer.toString();
  }
}
