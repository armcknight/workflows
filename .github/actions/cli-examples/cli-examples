#!/usr/bin/env bash
# The output of a PR's CLI change: commands run on the base branch and on the PR.
#
#   cli-examples commands <product>
#     Print one JSON object per command, {line, argv}, for each line of each
#     `<!-- cli-examples: … -->` marker in $PR_BODY (the PR description). A line
#     is one command, split as a POSIX shell would split its words, but with no
#     shell: no pipes, redirections, variables or globs. A leading `$ ` is
#     dropped. The first word must be <product>; other lines are skipped with a
#     warning. At most $MAX_COMMANDS commands.
#
#   cli-examples build <product> <package-dir> [<build-arg>...]
#     Build <product> of the package in <package-dir> with `swift build`, with
#     each <build-arg>, and print the path of the executable. The build's output
#     goes to stderr.
#
#   cli-examples run <binary> <workdir> <commands-file> <out-dir>
#     Run each command in <commands-file> in <workdir>, with <binary> in place
#     of its first word, no stdin and a $TIMEOUT-second limit. Write its stdout
#     and stderr, ANSI escapes removed, to <out-dir>/<n>.out and its exit status
#     to <out-dir>/<n>.status. A command that fails is a result, not an error.
#
#   cli-examples report <commands-file> <base-out-dir> <head-out-dir> <sha> <comment-file>
#     Write a PR comment to <comment-file>: for each command, a diff of the base
#     output against the PR output, and the PR output. Leave <base-out-dir>
#     empty ("") when the base branch did not build.
#
# Needs GITHUB_REPOSITORY, GITHUB_SERVER_URL and GITHUB_RUN_ID (report).

set -euo pipefail

MAX_COMMANDS=20
TIMEOUT=60
# Per output, so one noisy command cannot push the others out of the comment.
MAX_LINES=200
MAX_BYTES=10000
# GitHub refuses a comment longer than 65536 characters.
MAX_COMMENT_BYTES=60000

commands() {
  local product="$1"
  # The description is text anyone who can edit the PR writes; it is only
  # ever split into words here, never given to a shell.
  printf '%s' "${PR_BODY:-}" | PRODUCT="$product" MAX="$MAX_COMMANDS" python3 -I -c '
import json, os, re, shlex, sys
product, limit, count = os.environ["PRODUCT"], int(os.environ["MAX"]), 0
for block in re.findall(r"<!--\s*cli-examples:(.*?)-->", sys.stdin.read(), re.S):
    for line in block.splitlines():
        line = line.strip()
        if line.startswith("$ "):
            line = line[2:].strip()
        if not line:
            continue
        try:
            argv = shlex.split(line)
        except ValueError as error:
            print(f"::warning::Skipped `{line}`: {error}.", file=sys.stderr)
            continue
        if not argv or argv[0] != product:
            print(f"::warning::Skipped `{line}`: it does not start with `{product}`.", file=sys.stderr)
            continue
        if count == limit:
            print(f"::warning::Only the first {limit} commands run.", file=sys.stderr)
            sys.exit(0)
        print(json.dumps({"line": line, "argv": argv}))
        count += 1
'
}

build() {
  local product="$1" dir="$2" bin_path
  shift 2
  cd "$dir"
  swift build --product "$product" "$@" >&2
  bin_path=$(swift build --show-bin-path "$@")
  printf '%s/%s\n' "$bin_path" "$product"
}

run() {
  local binary="$1" workdir="$2" commands_file="$3" out="$4"
  local n=0 json status arg
  local -a argv
  mkdir -p "$out"
  while IFS= read -r json; do
    n=$((n + 1))
    # One argument per line: a line of the description holds no newline.
    argv=()
    while IFS= read -r arg; do argv+=("$arg"); done < <(jq -r '.argv[1:][]' <<< "$json")
    echo "Running: $(jq -r .line <<< "$json")"
    set +e
    # alarm survives exec, so the command itself gets SIGALRM at the limit.
    # exec, so bash's own "Alarm clock" notice stays out of the output.
    (cd "$workdir" && NO_COLOR=1 TERM=dumb COLUMNS=100 \
      exec perl -e 'alarm shift; exec @ARGV or die "exec: $!\n"' "$TIMEOUT" "$binary" ${argv[@]+"${argv[@]}"}) \
      < /dev/null > "$out/$n.raw" 2>&1
    status=$?
    set -e
    perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\e\][^\a]*\a//g; s/\r$//' "$out/$n.raw" > "$out/$n.out"
    rm "$out/$n.raw"
    echo "$status" > "$out/$n.status"
  done < "$commands_file"
}

report() {
  local commands_file="$1" base="$2" head="$3" sha="$4" comment="$5"
  local run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  local n=0 json line head_status base_status section
  section=$(mktemp)
  {
    printf 'CLI examples for commit `%s` ([run](%s)): the commands this PR'"'"'s description names, run on the base branch and on this PR.\n' "${sha::7}" "$run_url"
    if [ -z "$base" ]; then
      printf '\n> [!NOTE]\n> The base branch did not build, so there is no output to compare with.\n'
    fi
  } > "$comment"

  while IFS= read -r json; do
    n=$((n + 1))
    line=$(jq -r .line <<< "$json")
    head_status=$(cat "$head/$n.status")
    {
      printf '\n#### %s\n\n' "$(code "$line")"
      if [ -n "$base" ]; then
        base_status=$(cat "$base/$n.status")
        if cmp -s "$base/$n.out" "$head/$n.out" && [ "$base_status" = "$head_status" ]; then
          printf 'No change in the output%s.\n\n' "$(status_note "$head_status")"
        else
          if [ "$base_status" != "$head_status" ]; then
            printf 'Exit status: %s on the base branch, %s on this PR.\n\n' \
              "$(status_text "$base_status")" "$(status_text "$head_status")"
          fi
          if cmp -s "$base/$n.out" "$head/$n.out"; then
            printf 'No change in the output.\n\n'
          else
            diff -u --label base --label PR "$base/$n.out" "$head/$n.out" | clip | block diff || true
            printf '\n'
          fi
        fi
      fi
      printf '<details%s><summary>Output on this PR (%s)</summary>\n\n' \
        "$([ -n "$base" ] || printf ' open')" "$(status_text "$head_status")"
      clip < "$head/$n.out" | block text
      printf '\n</details>\n'
    } > "$section"
    if [ $(( $(wc -c < "$comment") + $(wc -c < "$section") )) -gt "$MAX_COMMENT_BYTES" ]; then
      printf '\n> [!WARNING]\n> The comment is full. See the [run](%s) for the remaining commands.\n' "$run_url" >> "$comment"
      break
    fi
    cat "$section" >> "$comment"
  done < "$commands_file"
  rm "$section"
}

# Standard input, cut to MAX_LINES lines and MAX_BYTES bytes, with a note when
# it was cut.
clip() {
  MAX_LINES="$MAX_LINES" MAX_BYTES="$MAX_BYTES" perl -e '
    local $/; my $text = <STDIN> // "";
    my ($lines, $bytes) = (($text =~ tr/\n//), length $text);
    if ($lines <= $ENV{MAX_LINES} && $bytes <= $ENV{MAX_BYTES}) { print $text; exit }
    my @kept = (split /^/, $text)[0 .. $ENV{MAX_LINES} - 1];
    print substr(join("", grep { defined } @kept), 0, $ENV{MAX_BYTES});
    print "\n[… cut: $lines lines, $bytes bytes in all]\n";
  '
}

# Standard input as a fenced code block in language $1, with a fence longer
# than any run of backticks in it.
block() {
  local text fence='```' longest
  text=$(cat)
  [ -n "$text" ] || text="(no output)"
  longest=$(printf '%s' "$text" | perl -ne '$m = length($1) > $m ? length($1) : $m while /(`+)/g; END { print $m + 0 }')
  while [ "${#fence}" -le "$longest" ]; do fence+='`'; done
  printf '%s%s\n%s\n%s\n' "$fence" "$1" "$text" "$fence"
}

# $1 as inline code, safe for any backticks in it.
code() {
  local fence='`' longest
  longest=$(printf '%s' "$1" | perl -ne '$m = length($1) > $m ? length($1) : $m while /(`+)/g; END { print $m + 0 }')
  if [ "$longest" -eq 0 ]; then
    printf '`%s`' "$1"
    return
  fi
  while [ "${#fence}" -le "$longest" ]; do fence+='`'; done
  printf '%s %s %s' "$fence" "$1" "$fence"
}

status_text() {
  case "$1" in
    0) printf 'exit 0' ;;
    142) printf 'timed out after %ss' "$TIMEOUT" ;;
    *) printf 'exit %s' "$1" ;;
  esac
}

status_note() {
  [ "$1" = 0 ] || printf ' (%s)' "$(status_text "$1")"
}

case "${1:-}" in
  commands) shift; commands "$@" ;;
  build) shift; build "$@" ;;
  run) shift; run "$@" ;;
  report) shift; report "$@" ;;
  *) echo "usage: cli-examples commands <product> | build <product> <package-dir> [<build-arg>...] | run <binary> <workdir> <commands-file> <out-dir> | report <commands-file> <base-out-dir> <head-out-dir> <sha> <comment-file>" >&2; exit 2 ;;
esac
