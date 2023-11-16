FROM dart:2.18 as build
WORKDIR /build/
ADD pubspec.yaml /build/
RUN dart pub get
FROM scratch
