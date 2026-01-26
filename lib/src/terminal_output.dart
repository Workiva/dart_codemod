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

import 'package:io/ansi.dart';

/// Enhanced terminal output utilities with colors, icons, and better formatting.
class TerminalOutput {
  final bool _ansiEnabled;
  final Stdout _stdout;
  final Stdout _stderr;

  TerminalOutput({
    required bool ansiEnabled,
    required Stdout stdout,
    required Stdout stderr,
  }) : _ansiEnabled = ansiEnabled,
       _stdout = stdout,
       _stderr = stderr;

  /// Writes a success message with green color and checkmark icon.
  void success(String message) {
    if (_ansiEnabled) {
      _stdout.writeln('${green.wrap('✓')} ${green.wrap(message)}');
    } else {
      _stdout.writeln('[OK] $message');
    }
  }

  /// Writes an error message with red color and X icon.
  void error(String message) {
    if (_ansiEnabled) {
      _stderr.writeln('${red.wrap('✗')} ${red.wrap(message)}');
    } else {
      _stderr.writeln('[ERROR] $message');
    }
  }

  /// Writes a warning message with yellow color and warning icon.
  void warning(String message) {
    if (_ansiEnabled) {
      _stderr.writeln('${yellow.wrap('⚠')} ${yellow.wrap(message)}');
    } else {
      _stderr.writeln('[WARNING] $message');
    }
  }

  /// Writes an info message with blue color and info icon.
  void info(String message) {
    if (_ansiEnabled) {
      _stdout.writeln('${blue.wrap('ℹ')} ${blue.wrap(message)}');
    } else {
      _stdout.writeln('[INFO] $message');
    }
  }

  /// Writes a section header with bold formatting.
  void section(String title) {
    if (_ansiEnabled) {
      _stdout.writeln('');
      _stdout.writeln('${styleBold.wrap(title)}');
      _stdout.writeln('${styleBold.wrap('─' * title.length)}');
    } else {
      _stdout.writeln('');
      _stdout.writeln(title);
      _stdout.writeln('─' * title.length);
    }
  }

  /// Writes a subtitle with dim formatting.
  void subtitle(String text) {
    if (_ansiEnabled) {
      _stdout.writeln('${styleDim.wrap(text)}');
    } else {
      _stdout.writeln(text);
    }
  }

  /// Writes a highlighted text (for important information).
  void highlight(String text) {
    if (_ansiEnabled) {
      _stdout.writeln('${cyan.wrap(text)}');
    } else {
      _stdout.writeln(text);
    }
  }

  /// Writes a progress message with spinner icon.
  void progress(String message) {
    if (_ansiEnabled) {
      _stdout.write('${cyan.wrap('⟳')} ${cyan.wrap(message)}...\r');
    } else {
      _stdout.write('[PROGRESS] $message...\r');
    }
  }

  /// Clears the progress line.
  void clearProgress() {
    _stdout.write('\r${' ' * 80}\r');
  }

  /// Writes a key-value pair with proper formatting.
  void keyValue(String key, String value, {bool highlightValue = false}) {
    if (_ansiEnabled) {
      final formattedKey = styleDim.wrap('$key:');
      final formattedValue = highlightValue ? cyan.wrap(value) : value;
      _stdout.writeln('  $formattedKey $formattedValue');
    } else {
      _stdout.writeln('  $key: $value');
    }
  }

  /// Writes a list item with bullet point.
  void listItem(String item, {bool isError = false}) {
    if (_ansiEnabled) {
      final bullet = isError ? red.wrap('•') : cyan.wrap('•');
      _stdout.writeln('  $bullet $item');
    } else {
      _stdout.writeln('  • $item');
    }
  }

  /// Writes a separator line.
  void separator() {
    if (_ansiEnabled) {
      _stdout.writeln(styleDim.wrap('─' * 60));
    } else {
      _stdout.writeln('─' * 60);
    }
  }

  /// Writes a formatted prompt with clear instructions.
  void prompt(String message, {String? defaultChoice}) {
    if (_ansiEnabled) {
      final promptText = styleBold.wrap(message);
      if (defaultChoice != null) {
        _stdout.write('$promptText ${styleDim.wrap('[$defaultChoice]')} ');
      } else {
        _stdout.write('$promptText ');
      }
    } else {
      if (defaultChoice != null) {
        _stdout.write('$message [$defaultChoice] ');
      } else {
        _stdout.write('$message ');
      }
    }
  }

  /// Writes a formatted help text with proper indentation.
  void helpText(String text) {
    if (_ansiEnabled) {
      _stdout.writeln('  ${styleDim.wrap(text)}');
    } else {
      _stdout.writeln('  $text');
    }
  }

  /// Writes a formatted code block.
  void codeBlock(String code) {
    if (_ansiEnabled) {
      _stdout.writeln('  ${styleDim.wrap('┌─')}');
      for (final line in code.split('\n')) {
        _stdout.writeln('  ${styleDim.wrap('│')} $line');
      }
      _stdout.writeln('  ${styleDim.wrap('└─')}');
    } else {
      _stdout.writeln('  ┌─');
      for (final line in code.split('\n')) {
        _stdout.writeln('  │ $line');
      }
      _stdout.writeln('  └─');
    }
  }

  /// Writes a formatted table row.
  void tableRow(List<String> cells, {List<bool>? highlight}) {
    if (_ansiEnabled) {
      final formattedCells = <String>[];
      for (var i = 0; i < cells.length; i++) {
        final cell = cells[i];
        if (highlight != null && i < highlight.length && highlight[i]) {
          formattedCells.add(cyan.wrap(cell) ?? cell);
        } else {
          formattedCells.add(cell);
        }
      }
      _stdout.writeln('  ${formattedCells.join('  │  ')}');
    } else {
      _stdout.writeln('  ${cells.join('  │  ')}');
    }
  }

  /// Writes a formatted header for a table.
  void tableHeader(List<String> headers) {
    if (_ansiEnabled) {
      final formattedHeaders = headers
          .map((h) => styleBold.wrap(h))
          .join('  │  ');
      _stdout.writeln('  $formattedHeaders');
      _stdout.writeln('  ${'─' * (formattedHeaders.length + 4)}');
    } else {
      _stdout.writeln('  ${headers.join('  │  ')}');
      _stdout.writeln('  ${'─' * 60}');
    }
  }

  /// Writes a note with special formatting.
  void note(String message) {
    if (_ansiEnabled) {
      _stdout.writeln('');
      _stdout.writeln('${yellow.wrap('NOTE:')} ${yellow.wrap(message)}');
      _stdout.writeln('');
    } else {
      _stdout.writeln('');
      _stdout.writeln('NOTE: $message');
      _stdout.writeln('');
    }
  }

  /// Writes a tip with special formatting.
  void tip(String message) {
    if (_ansiEnabled) {
      _stdout.writeln('');
      _stdout.writeln('${cyan.wrap('💡 TIP:')} ${cyan.wrap(message)}');
      _stdout.writeln('');
    } else {
      _stdout.writeln('');
      _stdout.writeln('TIP: $message');
      _stdout.writeln('');
    }
  }
}
