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

// ignore_for_file: must_be_immutable

@TestOn('vm')
import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';

import 'aggregate_suggestor_test.mocks.dart';

@override
Stream<Patch> fooSuggestor(_) async* {
  yield FooPatch();
}

@override
Stream<Patch> barSuggestor(_) async* {
  yield BarPatch();
}

class FooPatch extends MockPatch {}

class BarPatch extends MockPatch {}

class ShouldBeSkippedPatch extends MockPatch {}

@GenerateMocks([Patch])
void main() {
  test('aggregate should yield patches from each suggestor', () async {
    final suggestor = aggregate([fooSuggestor, barSuggestor]);
    final context = await fileContextForTest('test.dart', 'test');
    expect(
        suggestor(context), emitsInOrder([isA<FooPatch>(), isA<BarPatch>()]));
  });
}
