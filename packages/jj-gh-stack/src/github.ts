import { execFileSync } from "node:child_process";
import { Octokit } from "@octokit/core";
import { remoteUrl } from "./jj.ts";

export interface Repo {
  octokit: Octokit;
  owner: string;
  repo: string;
  defaultBranch: string;
  mergeMethod: MergeMethod;
}

export type MergeMethod = "rebase" | "merge" | "squash";

export interface PullRequest {
  number: number;
  title: string;
  body: string;
  base: string;
  headSha: string;
}

export interface Stack {
  number: number;
  /** Open PRs in the stack, bottom first; merged ones are left out. */
  open: number[];
}

function token(): string {
  return (
    process.env.GITHUB_TOKEN ??
    execFileSync("gh", ["auth", "token"], { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] }).trim()
  );
}

export async function connect(remote: string): Promise<Repo> {
  const match = remoteUrl(remote).match(/github\.com[:/]([^/]+)\/(.+?)(?:\.git)?$/);
  if (!match) throw new Error(`remote ${remote} is not a GitHub repository`);
  const [, owner, repo] = match;
  const octokit = new Octokit({ auth: token() });
  const { data } = await octokit.request("GET /repos/{owner}/{repo}", { owner, repo });
  return { octokit, owner, repo, defaultBranch: data.default_branch, mergeMethod: mergeMethod(data) };
}

/** Prefers rebase, which lands one commit per change as jj shows the stack. */
function mergeMethod(settings: {
  allow_rebase_merge?: boolean;
  allow_merge_commit?: boolean;
  allow_squash_merge?: boolean;
}): MergeMethod {
  if (settings.allow_rebase_merge) return "rebase";
  if (settings.allow_merge_commit) return "merge";
  if (settings.allow_squash_merge) return "squash";
  throw new Error("the repository allows no merge method");
}

export async function findPullRequest({ octokit, owner, repo }: Repo, branch: string): Promise<PullRequest | undefined> {
  const { data } = await octokit.request("GET /repos/{owner}/{repo}/pulls", {
    owner,
    repo,
    state: "open",
    head: `${owner}:${branch}`,
  });
  const pr = data[0];
  return pr && { number: pr.number, title: pr.title, body: pr.body ?? "", base: pr.base.ref, headSha: pr.head.sha };
}

export async function findStack({ octokit, owner, repo }: Repo, pr: number): Promise<Stack | undefined> {
  const { data } = await octokit.request("GET /repos/{owner}/{repo}/stacks", { owner, repo, pull_request: pr });
  const stack = data[0];
  return (
    stack && {
      number: stack.number,
      open: stack.pull_requests.filter((p) => p.merged_at === null).map((p) => p.number),
    }
  );
}
