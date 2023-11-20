// ignore: provide_deprecation_message
@deprecated
String foo = 'foo';

/// Class doc comment.
@Deprecated('2.0.0')
class Bar {
  void method() {}
}

// Not deprecated.
bool baz = true;
