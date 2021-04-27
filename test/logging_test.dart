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

@TestOn('vm')
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

import 'package:codemod/src/logging.dart';

import 'util.dart';

const codemodLoggerName = 'codemod';
const otherLoggerName = 'other';

void main() {
  group('logListener()', () {
    late StringBuffer output;

    setUp(() {
      output = StringBuffer();
    });

    test('writes logs', () {
      final listener = logListener(output, ansiOutputEnabled: false);
      listener(LogRecord(Level.INFO, 'test', otherLoggerName));
      expect(output.toString().split('\n'), [
        '[INFO] other: test',
        '',
      ]);
    });

    test('filters out the `codemod` logger name', () {
      final listener = logListener(output, ansiOutputEnabled: false);
      listener(LogRecord(Level.INFO, 'test', codemodLoggerName));
      expect(output.toString().split('\n'), [
        '[INFO] test',
        '',
      ]);
    });

    test('includes errors', () {
      final listener = logListener(output, ansiOutputEnabled: false);
      final error = Exception('error');
      listener(LogRecord(Level.WARNING, 'test', codemodLoggerName, error));
      expect(output.toString().split('\n'), [
        '[WARNING] test',
        '$error',
        '',
      ]);
    });

    test('omits stack traces by default', () {
      final listener = logListener(output, ansiOutputEnabled: false);
      final error = Exception('error');
      final stackTrace = StackTrace.current;
      listener(LogRecord(
          Level.WARNING, 'test', codemodLoggerName, error, stackTrace));
      expect(output.toString().split('\n'), [
        '[WARNING] test',
        '$error',
        '',
      ]);
    });

    group('ansiOutputEnabled=true', () {
      overrideAnsiOutput(true, () {
        testWithAnsi('highlights severe log level in red', () {
          final listener = logListener(output, ansiOutputEnabled: true);
          listener(LogRecord(Level.SEVERE, 'test', codemodLoggerName));
          expect(output.toString().split('\n'), [
            '${red.wrap('[SEVERE]')} test',
            '',
          ]);
        });

        testWithAnsi('highlights warning log level in yellow', () {
          final listener = logListener(output, ansiOutputEnabled: true);
          listener(LogRecord(Level.WARNING, 'test', codemodLoggerName));
          expect(output.toString().split('\n'), [
            '${yellow.wrap('[WARNING]')} test',
            '',
          ]);
        });

        testWithAnsi('highlights all other log levels in cyan', () {
          final listener = logListener(output, ansiOutputEnabled: true);
          listener(LogRecord(Level.INFO, 'test', codemodLoggerName));
          expect(output.toString().split('\n'), [
            '${cyan.wrap('[INFO]')} test',
            '',
          ]);
        });
      });
    });

    group('verbose=true', () {
      test('does not filter out the `codemod` logger name', () {
        final listener =
            logListener(output, ansiOutputEnabled: false, verbose: true);
        listener(LogRecord(Level.INFO, 'test', codemodLoggerName));
        expect(output.toString().split('\n'), [
          '[INFO] codemod: test',
          '',
        ]);
      });

      test('includes terse stack traces', () {
        final listener =
            logListener(output, ansiOutputEnabled: false, verbose: true);
        final error = Exception('error');
        final stackTrace = StackTrace.current;
        final terseStackTrace = Trace.from(stackTrace).terse;
        listener(LogRecord(
            Level.WARNING, 'test', codemodLoggerName, error, stackTrace));
        final result = output.toString();
        expect(result, contains('[WARNING] codemod: test\n'));
        expect(result, contains('$error\n'));
        expect(result, contains(terseStackTrace.toString()));
      });
    });
  });
}
