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
import 'dart:io';

import 'package:codemod/src/util.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'util_test.mocks.dart';

@GenerateMocks([Stdout])
void main() {
  group('Utils', () {
    group('calculateDiffSize()', () {
      test('returns 10 if stdout does not have a terminal', () {
        final mockStdout = MockStdout();
        when(mockStdout.hasTerminal).thenReturn(false);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 if # of terminal lines is too small', () {
        final mockStdout = MockStdout();
        when(mockStdout.hasTerminal).thenReturn(true);
        when(mockStdout.terminalLines).thenReturn(15);
        expect(calculateDiffSize(mockStdout), 10);
      });

      test('returns 10 less than available # of terminal lines', () {
        final mockStdout = MockStdout();
        when(mockStdout.hasTerminal).thenReturn(true);
        when(mockStdout.terminalLines).thenReturn(50);
        expect(calculateDiffSize(mockStdout), 40);
      });
    });
  });
}
