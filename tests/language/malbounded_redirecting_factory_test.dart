// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class A<
    Ta
           extends num // //# 02: continued
    > implements B<Ta>, C<Ta> {}

class B<
    Tb
           extends num // //# 03: continued
    > {
  factory B() = A<Tb>;
}

class C<
    Tc
           extends num // //# 04: continued
    > {
  factory C() = B<Tc>;
}

main() {
  new C<int>();
  new C<String>(); // //# 01: static type warning
  new C<String>(); // //# 02: static type warning, dynamic type error
  new C<String>(); // //# 03: static type warning, dynamic type error
  new C<String>(); // //# 04: static type warning, dynamic type error
}
