"""Run a Claude Code worker whose only AWS access is a scoped-down copy of ours.

Mints credentials with `aws sts get-scoped-credentials` from the policy, then
runs `claude -p` with them as its only AWS credentials, inside a sandbox that
can't read ~/.aws or reach the instance metadata service, and without the AWS
MCP server.
"""

import argparse
import json
import os
import subprocess
import sys

AWS = "@aws@"
CLAUDE = "@claude@"

AMBIENT_AWS_VARS = [
    "AWS_PROFILE",
    "AWS_DEFAULT_PROFILE",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AWS_CREDENTIAL_EXPIRATION",
    "AWS_CONTAINER_CREDENTIALS_FULL_URI",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI",
    "AWS_CONTAINER_AUTHORIZATION_TOKEN",
    "AWS_WEB_IDENTITY_TOKEN_FILE",
    "AWS_ROLE_ARN",
    "AWS_ROLE_SESSION_NAME",
]

WORKER_SETTINGS = {
    "sandbox": {
        "enabled": True,
        "failIfUnavailable": True,
        "autoAllowBashIfSandboxed": True,
        "allowUnsandboxedCommands": False,
        "filesystem": {"denyRead": ["~/.aws"]},
        "network": {
            "allowedDomains": ["*.amazonaws.com", "*.api.aws"],
            "strictAllowlist": True,
        },
    },
    "permissions": {
        "deny": ["mcp__aws-mcp", "Read(~/.aws/**)", "Edit(~/.aws/**)"],
    },
}


def scoped_credentials(args):
    with open(args.policy) as f:
        policy = json.dumps(json.load(f), separators=(",", ":"))
    command = [
        AWS, "sts", "get-scoped-credentials",
        "--region", args.region,
        "--policy", policy,
        "--scoped-session-description", args.description,
        "--query", "Credentials",
        "--output", "json",
    ]
    if args.duration_seconds:
        command += ["--duration-seconds", str(args.duration_seconds)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"scoped-claude: get-scoped-credentials failed:\n{result.stderr}")
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", required=True, help="scope down policy JSON file")
    parser.add_argument("--region", required=True)
    parser.add_argument("--description", required=True, help="purpose, logged in CloudTrail")
    parser.add_argument("--duration-seconds", type=int)
    parser.add_argument("--permission-mode", default="dontAsk")
    parser.add_argument("claude_args", nargs=argparse.REMAINDER, help="-- then the prompt and any other claude arguments")
    args = parser.parse_args()
    claude_args = args.claude_args[1:] if args.claude_args[:1] == ["--"] else args.claude_args
    if not claude_args:
        parser.error("missing the prompt after --")

    credentials = scoped_credentials(args)

    env = {k: v for k, v in os.environ.items() if k not in AMBIENT_AWS_VARS}
    env.update(
        AWS_ACCESS_KEY_ID=credentials["AccessKeyId"],
        AWS_SECRET_ACCESS_KEY=credentials["SecretAccessKey"],
        AWS_SESSION_TOKEN=credentials["SessionToken"],
        AWS_CREDENTIAL_EXPIRATION=credentials["Expiration"],
        AWS_REGION=args.region,
        AWS_CONFIG_FILE=os.devnull,
        AWS_SHARED_CREDENTIALS_FILE=os.devnull,
        AWS_EC2_METADATA_DISABLED="true",
        PATH=os.pathsep.join([os.path.dirname(AWS), env.get("PATH", "")]),
    )
    devnull = os.open(os.devnull, os.O_RDONLY)
    os.dup2(devnull, sys.stdin.fileno())
    os.execve(
        CLAUDE,
        [
            CLAUDE, "-p",
            "--settings", json.dumps(WORKER_SETTINGS),
            "--permission-mode", args.permission_mode,
            *claude_args,
        ],
        env,
    )


if __name__ == "__main__":
    main()
