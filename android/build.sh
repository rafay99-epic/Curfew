#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"

first_dir() {
  for d in "$@"; do
    if [ -d "$d" ]; then echo "$d"; return; fi
  done
  echo "$1"
}

export JAVA_HOME="${JAVA_HOME:-$(first_dir /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home "$ROOT/.toolchain/jdk")}"
export ANDROID_HOME="${ANDROID_HOME:-$(first_dir "$HOME/Library/Android/sdk" "$ROOT/.toolchain/android-sdk")}"
export PATH="$JAVA_HOME/bin:$PATH"
echo "sdk.dir=$ANDROID_HOME" > local.properties

case "${1:-}" in
  "") tasks=(testDebugUnitTest assembleRelease bundleRelease) ;;
  quick) tasks=(assembleRelease bundleRelease) ;;
  *) exec ./gradlew --console=plain "$@" ;;
esac

if [ ! -f key.properties ]; then
  echo "build.sh: android/key.properties is missing (storeFile, storePassword, keyAlias, keyPassword). Release builds need the upload key." >&2
  exit 1
fi

./gradlew --console=plain "${tasks[@]}"
mkdir -p "$ROOT/dist"
cp app/build/outputs/apk/release/app-release.apk "$ROOT/dist/Curfew.apk"
cp app/build/outputs/bundle/release/app-release.aab "$ROOT/dist/Curfew.aab"
ls -l "$ROOT/dist/Curfew.apk" "$ROOT/dist/Curfew.aab"
