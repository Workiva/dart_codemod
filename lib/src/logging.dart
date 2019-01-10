// TODO: license

// Originally copied from https://github.com/dart-lang/build/blob/0e79b63c6387adbb7e7f4c4f88d572b1242d24df/build_runner/lib/src/logging/std_io_logging.dart

// Copyright 2016, the Dart project authors. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//     * Neither the name of Google Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'dart:convert';
import 'dart:io';

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
Function(LogRecord) logListener(
        {bool ansiOutputEnabled, IOSink sink, bool verbose}) =>
    (record) => overrideAnsiOutput(ansiOutputEnabled == true, () {
          _logListener(record, sink: sink, verbose: verbose ?? false);
        });

void _logListener(LogRecord record, {IOSink sink, bool verbose}) {
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
  final lines = blankLineCount > 0
      ? (List<Object>.generate(blankLineCount, (_) => '')..add(header))
      : <Object>[header];

  if (record.error != null) {
    lines.add(record.error);
  }

  if (record.stackTrace != null && verbose) {
    lines.add(Trace.from(record.stackTrace).terse);
  }

  final message = StringBuffer(lines.join('\n'));

  // We always add an extra newline at the end of each message, so it
  // isn't multiline unless we see > 2 lines.
  final multiLine = LineSplitter.split(message.toString()).length > 2;

  if (record.level > Level.INFO || !ansiOutputEnabled || multiLine || verbose) {
    // Add an extra line to the output so the last line isn't written over.
    message.writeln('');
  }

  stderr.write(message);
}

/// Filter out the Logger names known to come from `codemod` and splits the
/// header for levels >= WARNING.
String _loggerName(LogRecord record, bool verbose) {
  final knownNames = const [
    'codemod',
  ];
  final maybeSplit = record.level >= Level.WARNING ? '\n' : '';
  return verbose || !knownNames.contains(record.loggerName)
      ? '${record.loggerName}:$maybeSplit'
      : '';
}
