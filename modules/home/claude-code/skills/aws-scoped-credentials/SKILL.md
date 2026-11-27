---
name: aws-scoped-credentials
description: Hand AWS work to another agent with only the permissions that task needs, by writing a scope down policy for it and running the task with `scoped-claude`. Subagents started with the Agent tool have no AWS access.
when_to_use: Delegating any task that calls AWS (AWS CLI, SDKs, Terraform, CDK) to a subagent or worker; an AWS call or AWS MCP tool in a subagent being denied with "Subagents have no AWS access"; scoped-claude failing with InsufficientSessionLifetime, PackedPolicyTooLarge, MalformedPolicyDocument or InvalidSubjectCredentials.
allowed-tools: Bash(scoped-claude *) Skill(aws-iam)
compatibility: Requires AWS CLI 2.42.0 or later for `aws sts get-scoped-credentials`.
---

# Delegating AWS work with scoped credentials

Subagents started with the Agent tool get **no** AWS access: a hook clears
their AWS configuration and denies the AWS MCP server. To give AWS work to
another agent, run it as a `scoped-claude` worker instead. Its only AWS
credentials come from `aws sts get-scoped-credentials` with a policy you write
for that one task.

## Steps

1. **Work out what AWS access the task needs**, then write a scope down
   policy for exactly that with the **`aws-iam`** skill. Follow its
   `references/aws-iam-policy-generation.md` as for any identity-based
   policy, then apply the rules in [Scope down policies](#scope-down-policies).
   Save it to a file.
2. **Run the task:**

   ```sh
   scoped-claude \
     --policy policy.json \
     --region us-east-1 \
     --description "report-status-job" \
     -- "The task for the worker, with everything it needs to know"
   ```

   - `--description` is logged in CloudTrail, which can't tell the worker
     apart from you otherwise, because it keeps your identity.
   - `--duration-seconds` shortens its credentials; by default they expire
     with yours.
   - `--permission-mode` defaults to `dontAsk`: sandboxed Bash runs, but any
     tool call that would need approval is refused. Pass `acceptEdits` if
     the worker has to edit files.
   - Anything after `--` goes to `claude -p`, for example `--max-turns 20`.
   - The worker is a separate `claude -p` session that starts without this
     conversation's context, so the prompt must be self-contained. It prints
     its final answer on stdout. Long tasks can outlast the Bash timeout, so
     run those in the background.
3. **If it fails before the worker starts**, `scoped-claude` prints AWS's
   error. Fix the policy and run it again. See
   [reference.md](reference.md#errors).

The worker runs in a sandbox that can't read `~/.aws`, can only reach AWS
endpoints, can't reach the instance metadata service, and has no AWS MCP
server. Its own credentials can be narrowed again by running `scoped-claude`
inside it, if its policy allows `sts:GetScopedCredentials`.

## Scope down policies

On top of what `aws-iam` says:

- **At most 2,048 characters.** When IAM Policy Autopilot generates the
  policy, add `--max-policy-size 2048
  --allow-overpermissive-wildcards-to-limit-total-output-size 2048`, then
  narrow the wildcards it introduced back to what the task needs.
- **Permissions can only shrink.** The worker gets the intersection of your
  permissions and the policy, so an `Allow` with `NotAction` is a safe way to
  keep everything except a few dangerous actions:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "NotAction": [
        "iam:*", "organizations:*", "account:*", "sts:AssumeRole*",
        "s3:DeleteBucket", "ec2:TerminateInstances",
        "rds:DeleteDBInstance", "dynamodb:DeleteTable"
      ],
      "Resource": "*"
    }]
  }
  ```

- **Allow `sts:GetScopedCredentials`** only if the worker must hand narrower
  credentials to its own workers. A session can carry at most 3 scope down
  policies.

## Requirements

- Your own session needs **temporary** AWS credentials (`aws login`, SSO, an
  assumed role). IAM user keys and root are rejected; for an IAM user, run
  `aws sts get-session-token` first.
- `sts:GetScopedCredentials` must be allowed for your session.

For parameter limits, response fields, errors and quotas, see
[reference.md](reference.md).
