#!/usr/bin/env bash
# Generates a classpath file for jdtls from a Bazel target.
# Usage: bazel-jdtls-classpath.sh <workspace_root> <bazel_target>
# Outputs the path to the cached classpath file (one JAR per line).

WORKSPACE_ROOT="$1"
BAZEL_TARGET="$2"

CACHE_DIR="${HOME}/.cache/nvim/jdtls-bazel"
CACHE_KEY=$(printf '%s:%s' "$WORKSPACE_ROOT" "$BAZEL_TARGET" | md5 -q)
CACHE_FILE="${CACHE_DIR}/${CACHE_KEY}"
LOG_FILE="${CACHE_DIR}/build.log"

mkdir -p "$CACHE_DIR"

log()  { echo "$1" >> "$LOG_FILE"; }
die()  { echo "[bazel-jdtls] ERROR: $1" >> "$LOG_FILE"; echo "[bazel-jdtls] ERROR: $1" >&2; exit 1; }

# Truncate log and record start
echo "[bazel-jdtls] started at $(date)" > "$LOG_FILE"
log "[bazel-jdtls] workspace : $WORKSPACE_ROOT"
log "[bazel-jdtls] target    : $BAZEL_TARGET"

# Ensure java/bazel are in PATH (sdkman, etc.)
# shellcheck source=/dev/null
source "${HOME}/.zshrc" 2>/dev/null || true

log "[bazel-jdtls] PATH: $PATH"
log "[bazel-jdtls] bazel: $(command -v bazel 2>&1)"

cd "$WORKSPACE_ROOT" || die "could not cd to $WORKSPACE_ROOT"

log "[bazel-jdtls] running: bazel info execution_root"
EXEC_ROOT=$(bazel info execution_root 2>>"$LOG_FILE") \
  || die "bazel info execution_root failed (exit $?)"
log "[bazel-jdtls] exec root: $EXEC_ROOT"

log "[bazel-jdtls] building $BAZEL_TARGET"
bazel build "$BAZEL_TARGET" 2>>"$LOG_FILE" \
  || die "bazel build failed (exit $?)"

log "[bazel-jdtls] querying classpath …"
bazel cquery "deps(${BAZEL_TARGET})" \
  --output=starlark \
  --starlark:expr='"\n".join([f.path for k,v in providers(target).items() if "JavaInfo" in k for f in v.compile_jars.to_list()])' \
  2>>"$LOG_FILE" \
  | grep '\.jar$' \
  | sort -u \
  | sed "s|^|${EXEC_ROOT}/|" \
  > "$CACHE_FILE"

[ -s "$CACHE_FILE" ] || die "cquery produced no JARs"

log "[bazel-jdtls] done — $(wc -l < "$CACHE_FILE") JARs written to $CACHE_FILE"
echo "$CACHE_FILE"
