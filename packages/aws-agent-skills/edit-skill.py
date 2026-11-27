"""Apply string and section replacements to an unpacked skill.

Takes the skill directory and a JSON file of the form
{"<file>": {"replace": {"<old>": "<new>"}, "sections": {"<heading line>": "<body>"}}}.
A section is everything after its heading up to the next heading of the same
or a higher level. Every string and heading must be present, so the build
fails when upstream changes what an edit targets.
"""

import json
import pathlib
import re
import sys


def replace_section(text, heading, body):
    lines = text.splitlines(keepends=True)
    level = len(heading) - len(heading.lstrip("#"))
    try:
        start = next(i for i, line in enumerate(lines) if line.rstrip("\n") == heading)
    except StopIteration:
        sys.exit(f"heading not found: {heading!r}")
    end = next(
        (
            i
            for i in range(start + 1, len(lines))
            if (m := re.match(r"(#+) ", lines[i])) and len(m.group(1)) <= level
        ),
        len(lines),
    )
    return "".join(lines[: start + 1] + ["\n", body.rstrip("\n") + "\n\n"] + lines[end:])


def main():
    skill = pathlib.Path(sys.argv[1])
    edits = json.loads(pathlib.Path(sys.argv[2]).read_text())
    for name, edit in edits.items():
        path = skill / name
        text = path.read_text()
        for heading, body in edit.get("sections", {}).items():
            text = replace_section(text, heading, body)
        for old, new in edit.get("replace", {}).items():
            if old not in text:
                sys.exit(f"{name}: string not found: {old!r}")
            text = text.replace(old, new)
        path.write_text(text)


if __name__ == "__main__":
    main()
