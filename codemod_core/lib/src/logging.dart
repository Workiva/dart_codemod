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

// The logging utility in this file was originally modeled after:
// https://github.com/dart-lang/build/blob/0e79b63c6387adbb7e7f4c4f88d572b1242d24df/build_runner/lib/src/logging/std_io_logging.dart

import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

/// Logger to be used for all error and debug logs in this package.
final Logger logger = Logger('codemod');

/// Returns a listener function for the [Logger.onRecord] stream that writes all
/// [LogRecord]s to the given [sink].
///
/// If [ansiOutputEnabled] is true, logs will be highlighted based on the
/// [Level] using ansi color codes.
///
/// If [verbose] is true, additional information will be included in the log
/// messages including stack traces, logger name, and extra newlines.
void Function(LogRecord) logListener(
  StringSink sink, {
  bool ansiOutputEnabled = false,
  bool verbose = false,
}) =>
    (record) => overrideAnsiOutput(ansiOutputEnabled, () {
          _logListener(record, sink, verbose: verbose);
        });

void _logListener(LogRecord record, StringSink sink, {required bool verbose}) {
  AnsiCode color;
  if (record.level < Level.WARNING) {
    color = cyan;
  } else if (record.level < Level.SEVERE) {
    color = yellow;
  } else {
    color = red;
  }
  final level = color.wrap('[${record.level}]');
  var headerMessage = record.message;
  var blankLineCount = 0;
  if (headerMessage.startsWith('\n')) {
    blankLineCount =
        headerMessage.split('\n').takeWhile((line) => line.isEmpty).length;
    headerMessage = headerMessage.substring(blankLineCount);
  }
  final header = '$level ${_loggerName(record, verbose)}$headerMessage';
  final lines = <Object>[
    ...List.generate(blankLineCount, (index) => ''),
    header,
  ];

  final error = record.error;
  if (error != null) {
    lines.add(error);
  }

  final stack = record.stackTrace;
  if (stack != null && verbose) {
    lines.add(Trace.from(stack).terse);
  }

  sink.writeln(lines.join('\n'));
}

/// Filter out the Logger names known to come from `codemod` and splits the
/// header for levels >= WARNING.
String _loggerName(LogRecord record, bool verbose) {
  const knownNames = [
    'codemod',
  ];
  return verbose || !knownNames.contains(record.loggerName)
      ? '${record.loggerName}: '
      : '';
}
