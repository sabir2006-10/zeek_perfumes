
#!/bin/bash

set -e

echo "Installing Flutter SDK..."

git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  -b stable /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

echo "Checking Flutter version..."
flutter --version

echo "Getting project dependencies..."
flutter pub get

echo "Building Athar Shop for production..."
flutter build web --release

echo "Flutter Web build completed successfully!"
