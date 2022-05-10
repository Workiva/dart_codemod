FROM google/dart:2 as build
WORKDIR /build/
ADD pubspec.yaml /build/
RUN dart pub get
FROM scratch
