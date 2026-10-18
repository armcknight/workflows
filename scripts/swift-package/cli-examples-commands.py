"""The commands in a PR description's `<!-- cli-examples: … -->` markers.

  python3 -I cli-examples-commands.py <product> <max-commands> < <pr-body>

Print one JSON object per command, {line, argv}, for each line of each marker
in standard input. A line is one command, split as a POSIX shell would split
its words, but with no shell. A leading `$ ` is dropped. The first word must be
<product>; other lines are skipped with a warning. At most <max-commands>
commands. Run by `cli-examples.sh commands`.
"""

import json
import re
import shlex
import sys

product, limit, count = sys.argv[1], int(sys.argv[2]), 0
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
