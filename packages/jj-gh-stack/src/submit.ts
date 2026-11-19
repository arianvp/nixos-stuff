import { type PullRequest, type Repo, findPullRequest, findStack } from "./github.ts";
import { descriptions, jj } from "./jj.ts";
import type { Entry } from "./stack.ts";

interface Options {
  remote: string;
  dryRun: boolean;
  forceDescription: boolean;
}

const normalize = (text: string) => text.replace(/\r\n/g, "\n").trim();
const list = (numbers: number[]) => numbers.map((n) => `#${n}`).join(" ← ");

/**
 * Whether a PR's title or body may be overwritten with the change's description:
 * only when it still holds text jj wrote, so edits made on GitHub are never lost.
 */
function updatable(onGitHub: string, wanted: string, history: string[], force: boolean): boolean {
  return normalize(onGitHub) !== normalize(wanted) && (force || history.some((h) => normalize(h) === normalize(onGitHub)));
}

/**
 * Pushes the stack, then makes its PRs and its GitHub stack match it. Safe to run again.
 *
 * The order matters. GitHub refuses to change the base of a stacked PR, and it marks a PR
 * merged (and deletes its branch) the moment its base branch contains its head. So when
 * the stack was reordered, the GitHub stack is dissolved and every PR whose base moves is
 * parked on trunk before anything is pushed.
 */
export async function submit(gh: Repo, stack: Entry[], { remote, dryRun, forceDescription }: Options): Promise<void> {
  const { octokit, owner, repo } = gh;
  /** Does what `plan` says, or only says it on a dry run; `run` returns what it did. */
  const act = async (plan: string, run: () => Promise<string>) => {
    console.log(dryRun ? `would ${plan}` : await run());
  };
  const setBase = async (pr: PullRequest, base: string) => {
    await act(`retarget #${pr.number} onto ${base}`, async () => {
      await octokit.request("PATCH /repos/{owner}/{repo}/pulls/{pull_number}", { owner, repo, pull_number: pr.number, base });
      return `retargeted #${pr.number} onto ${base}`;
    });
    pr.base = base;
  };

  const bases = stack.map((_, i) => (i === 0 ? gh.defaultBranch : stack[i - 1].branch));
  const prs: (PullRequest | undefined)[] = await Promise.all(stack.map((c) => findPullRequest(gh, c.branch)));
  const known = prs.find((pr) => pr !== undefined);
  let ghStack = known && (await findStack(gh, known.number));

  // A stack survives only if its open PRs sit at the same positions as in ours.
  if (ghStack && !ghStack.open.every((n, i) => i >= stack.length || prs[i]?.number === n)) {
    const { number } = ghStack;
    await act(`dissolve stack ${number}, which is in a different order`, async () => {
      await octokit.request("POST /repos/{owner}/{repo}/stacks/{stack_number}/unstack", { owner, repo, stack_number: number });
      return `dissolved stack ${number}, which was in a different order`;
    });
    ghStack = undefined;
  }

  for (const [i, pr] of prs.entries()) {
    if (pr && pr.base !== bases[i] && pr.base !== gh.defaultBranch) await setBase(pr, gh.defaultBranch);
  }

  jj(
    "git",
    "push",
    "--remote",
    remote,
    ...stack.flatMap((c) => (c.bookmarks.length > 0 ? ["-b", c.branch] : ["-c", c.changeId])),
    ...(dryRun ? ["--dry-run"] : []),
  );

  for (const [i, change] of stack.entries()) {
    const pr = prs[i];
    if (!pr) {
      await act(`open a PR for ${change.branch} onto ${bases[i]}`, async () => {
        const { data } = await octokit.request("POST /repos/{owner}/{repo}/pulls", {
          owner,
          repo,
          head: change.branch,
          base: bases[i],
          title: change.title,
          body: change.body,
        });
        prs[i] = { number: data.number, title: data.title, body: data.body ?? "", base: bases[i], headSha: data.head.sha };
        return `opened #${data.number} onto ${bases[i]}: ${data.html_url}`;
      });
      continue;
    }

    if (pr.base !== bases[i]) await setBase(pr, bases[i]);

    const history = descriptions(change.changeId).map((d) => d.trim().split("\n"));
    const update: { title?: string; body?: string } = {};
    if (updatable(pr.title, change.title, history.map(([title]) => title ?? ""), forceDescription)) update.title = change.title;
    if (updatable(pr.body, change.body, history.map(([, ...rest]) => rest.join("\n")), forceDescription)) update.body = change.body;
    for (const field of ["title", "body"] as const) {
      if (normalize(pr[field]) !== normalize(change[field]) && update[field] === undefined) {
        console.warn(`#${pr.number}: ${field} was edited on GitHub; keeping it (--force-description overwrites)`);
      }
    }
    const fields = Object.keys(update).join(" and ");
    if (fields) {
      await act(`update the ${fields} of #${pr.number}`, async () => {
        await octokit.request("PATCH /repos/{owner}/{repo}/pulls/{pull_number}", { owner, repo, pull_number: pr.number, ...update });
        return `updated the ${fields} of #${pr.number}`;
      });
    }
  }

  if (stack.length < 2) return;
  const numbers = prs.flatMap((pr) => (pr ? [pr.number] : []));
  if (numbers.length < stack.length) {
    console.log(`would stack the ${stack.length} PRs once they exist`);
    return;
  }

  if (!ghStack) {
    await act(`stack ${list(numbers)}`, async () => {
      await octokit.request("POST /repos/{owner}/{repo}/stacks", { owner, repo, pull_requests: numbers });
      return `stacked ${list(numbers)}`;
    });
  } else if (ghStack.open.length < numbers.length) {
    const { number, open } = ghStack;
    const added = numbers.slice(open.length);
    await act(`add ${list(added)} to stack ${number}`, async () => {
      await octokit.request("POST /repos/{owner}/{repo}/stacks/{stack_number}/add", {
        owner,
        repo,
        stack_number: number,
        pull_requests: added,
      });
      return `added ${list(added)} to stack ${number}`;
    });
  }
}
