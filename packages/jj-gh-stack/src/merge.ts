import { setTimeout as sleep } from "node:timers/promises";
import { type Repo, findPullRequest } from "./github.ts";
import type { Entry } from "./stack.ts";

/**
 * Merges the PR of the stack's top change, and with it every PR below. GitHub goes
 * through the merge queue when the base branch has one. Pinning `sha` to the local
 * commit makes GitHub merge exactly what jj shows, or refuse.
 */
export async function merge(gh: Repo, stack: Entry[]): Promise<void> {
  const { octokit, owner, repo, mergeMethod } = gh;
  const top = stack[stack.length - 1];
  const pr = await findPullRequest(gh, top.branch);
  if (!pr) throw new Error(`${top.branch} has no open PR; run submit first`);
  if (pr.headSha !== top.commitId) throw new Error(`#${pr.number} is not at ${top.commitId.slice(0, 12)}; run submit first`);

  const pull_number = pr.number;
  const response = await octokit
    .request("PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge-async", {
      owner,
      repo,
      pull_number,
      sha: top.commitId,
      merge_method: mergeMethod,
    })
    .catch((error) => {
      if (error.status === 409) return error.response;
      throw error;
    });
  const uuid: string | undefined = response.data.details?.uuid ?? response.data.uuid;
  console.log(`requested merge of #${pull_number}`);

  let result = response.data;
  while (uuid && result.status === "pending") {
    await sleep(2000);
    ({ data: result } = await octokit.request("GET /repos/{owner}/{repo}/pulls/{pull_number}/merge-async/{uuid}", {
      owner,
      repo,
      pull_number,
      uuid,
    }));
  }
  if (result.status === "failed") throw new Error(`GitHub could not merge #${pull_number}: ${result.details?.message}`);

  if (result.status === "enqueued") console.log(`#${pull_number} is in the merge queue`);
  for (;;) {
    const { data } = await octokit.request("GET /repos/{owner}/{repo}/pulls/{pull_number}", { owner, repo, pull_number });
    if (data.merged) break;
    if (data.state === "closed") throw new Error(`#${pull_number} was closed without merging`);
    await sleep(5000);
  }
  console.log(`merged #${pull_number}`);
}
