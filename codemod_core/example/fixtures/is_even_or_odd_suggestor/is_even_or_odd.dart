// ignore_for_file: use_is_even_rather_than_modulo
// Change to isEven

bool foo = (250 + 2) % 2 == 0;

// Change to isOdd
bool bar = (250 + 2) % 2 == 1;

// No changes, not int modulus
bool baz = 25.0 % 2 == 0;
