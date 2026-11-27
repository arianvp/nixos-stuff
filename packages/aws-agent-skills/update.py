"""Pin the AWS agent toolkit skills that `aws configure agent-toolkit` installs."""

import argparse
import json
import pathlib
import urllib.parse
import urllib.request

ENDPOINT = "https://agent-toolkit.us-east-1.api.aws"


def get(path, **query):
    url = f"{ENDPOINT}{path}"
    if query:
        url += "?" + urllib.parse.urlencode(query)
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode()


def list_skills(category):
    query = {"max_results": 100}
    if category:
        query["category_filter"] = category
    while True:
        page = json.loads(get("/api/skills", **query))
        yield from page["skills"]
        if not page.get("nextToken"):
            return
        query["next_token"] = page["nextToken"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--all",
        action="store_true",
        help="pin the whole catalogue instead of the aws-core defaults",
    )
    parser.add_argument(
        "lock",
        nargs="?",
        type=pathlib.Path,
        default=pathlib.Path("packages/aws-agent-skills/skills.json"),
    )
    args = parser.parse_args()

    lock = {}
    for skill in list_skills(None if args.all else "aws-core"):
        name, version = skill["name"], skill["skillVersion"]
        download = f"/skills/{name}/versions/{version}/files/download"
        checksum = get(f"{download}/checksum")
        lock[name] = {"version": version, "sha256": checksum.split()[0].lower()}
        print(f"{name} {version}")

    args.lock.write_text(json.dumps(dict(sorted(lock.items())), indent=2) + "\n")


if __name__ == "__main__":
    main()
