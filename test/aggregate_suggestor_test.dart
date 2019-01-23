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
import 'package:codemod/codemod.dart';
import 'package:mockito/mockito.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

class BaseSuggestor implements Suggestor {
  @override
  bool shouldSkip(_) => false;

  @override
  Iterable<Patch> generatePatches(_) sync* {}
}

class AlwaysSkips extends BaseSuggestor {
  @override
  bool shouldSkip(_) => true;

  @override
  Iterable<Patch> generatePatches(_) => [ShouldBeSkippedPatch()];
}

class FooSuggestor extends BaseSuggestor {
  @override
  Iterable<Patch> generatePatches(_) => [FooPatch()];
}

class BarSuggestor extends BaseSuggestor {
  @override
  Iterable<Patch> generatePatches(_) => [BarPatch()];
}

class MockPatch extends Mock implements Patch {}

class FooPatch extends MockPatch {}

class BarPatch extends MockPatch {}

class ShouldBeSkippedPatch extends MockPatch {}

void main() {
  group('AggregateSuggestor', () {
    test('accepts a list of Suggestors', () {
      final foo = BaseSuggestor();
      final bar = BaseSuggestor();
      final aggregate = AggregateSuggestor([foo, bar]);
      expect(aggregate.aggregatedSuggestors, [foo, bar]);
    });

    test('accepts an iterable of Suggestors', () {
      final foo = BaseSuggestor();
      final bar = BaseSuggestor();
      final aggregate = AggregateSuggestor([foo, bar].map((s) => s));
      expect(aggregate.aggregatedSuggestors, [foo, bar]);
    });

    test('shouldSkip() always returns false', () {
      final aggregate = AggregateSuggestor([AlwaysSkips()]);
      expect(aggregate.shouldSkip(''), isFalse);
    });

    group('generatePatches()', () {
      test('skips suggestors that return true from shouldSkip()', () {
        final aggregate = AggregateSuggestor([
          AlwaysSkips(),
          FooSuggestor(),
        ]);
        final sourceFile = SourceFile.fromString('test');
        final patches = aggregate.generatePatches(sourceFile);
        expect(patches, hasLength(1));
        expect(patches.single, TypeMatcher<FooPatch>());
      });

      test('should yield patches from each suggestor', () {
        final aggregate = AggregateSuggestor([
          FooSuggestor(),
          BarSuggestor(),
        ]);
        final sourceFile = SourceFile.fromString('test');
        final patches = aggregate.generatePatches(sourceFile).toList();
        expect(patches, hasLength(2));
        expect(patches[0], TypeMatcher<FooPatch>());
        expect(patches[1], TypeMatcher<BarPatch>());
      });
    });
  });
}
