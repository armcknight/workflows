# shellcheck shell=bash
# Sourced by the scripts beside it. Nothing here runs on its own.

# Prints an error. On GitHub Actions it is an `::error::` annotation, so it
# shows on the run's summary; anywhere else it goes to stderr.
error() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::$*"
  else
    echo "error: $*" >&2
  fi
}

# Prints a warning. On GitHub Actions it is a `::warning::` annotation, so it
# shows on the run's summary; anywhere else it goes to stderr.
warning() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning::$*"
  else
    echo "warning: $*" >&2
  fi
}

# Appends a line of Markdown to the step summary on GitHub Actions. Anywhere
# else it does nothing.
summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}
