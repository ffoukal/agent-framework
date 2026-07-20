#!/usr/bin/env bash
# detector: Kotlin/JVM (Gradle or Maven).
# Usage: kotlin.sh <repo_root>
# Exit 0 and print draft sections if detected; exit 1 (no output) otherwise.
# Output is split by @@SECTION:PROJECT@@ / @@SECTION:TESTING@@ / @@SECTION:CODEMAP@@.
set -eu

ROOT="${1:-.}"

GRADLE=0; MAVEN=0
[ -f "$ROOT/build.gradle.kts" ] || [ -f "$ROOT/build.gradle" ] && GRADLE=1
[ -f "$ROOT/pom.xml" ] && MAVEN=1

if [ "$GRADLE" -eq 0 ] && [ "$MAVEN" -eq 0 ]; then
  exit 1
fi

if [ "$GRADLE" -eq 1 ]; then
  BUILD_CMD="./gradlew build"
  TEST_CMD="./gradlew test"
else
  BUILD_CMD="mvn -q -DskipTests package"
  TEST_CMD="mvn test"
fi

# modules from settings.gradle.kts (best-effort)
MODULES=""
if [ -f "$ROOT/settings.gradle.kts" ]; then
  MODULES=$(grep -Eo 'include\(?"[^"]+"' "$ROOT/settings.gradle.kts" 2>/dev/null \
    | sed -E 's/include\(?"//' || true)
fi

# Spring entry point
SPRING=""
if grep -rlq "@SpringBootApplication" "$ROOT" --include='*.kt' --include='*.java' 2>/dev/null; then
  SPRING=$(grep -rl "@SpringBootApplication" "$ROOT" --include='*.kt' --include='*.java' 2>/dev/null | head -5)
fi

echo "@@SECTION:PROJECT@@"
echo "- Stack draft: Kotlin/JVM ($([ "$GRADLE" -eq 1 ] && echo Gradle || echo Maven)). TODO: confirm."
echo "- Build draft: \`$BUILD_CMD\`  <!-- TODO verify -->"
echo "- Test draft: \`$TEST_CMD\`  <!-- TODO verify -->"

echo "@@SECTION:TESTING@@"
echo "- Draft: run tests with \`$TEST_CMD\`  <!-- TODO verify, add integration/e2e -->"

echo "@@SECTION:CODEMAP@@"
if [ -n "$MODULES" ]; then
  echo "- Gradle modules (from settings.gradle.kts) — TODO verify:"
  printf '%s\n' "$MODULES" | sed 's/^/  - /'
else
  echo "- TODO: single-module or modules not detected from settings.gradle.kts."
fi
if [ -n "$SPRING" ]; then
  echo "- Spring entry point(s) (@SpringBootApplication) — TODO verify:"
  printf '%s\n' "$SPRING" | sed "s|$ROOT/||" | sed 's/^/  - /'
fi
