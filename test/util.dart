import 'package:io/ansi.dart';
import 'package:test/test.dart';

/// Defines a test and wraps the [body] in a call to [overrideAnsiOutput] that
/// forces ANSI output to be enabled. This allows the test to verify that
/// certain output is highlighted correctly even when running in environments
/// where ANSI output would normally be disabled (like CI).
void testWithAnsi(String description, body()) {
  test(description, () => overrideAnsiOutput(true, body));
}
