import { type Change, changes, jj } from "./jj.ts";
import { revset } from "./stack.ts";

/** The user's mutable changes from trunk up to `rev`, plus everything stacked on top of them. */
export function syncable(rev: string): Change[] {
  return changes(`((trunk()..(${rev}))::) & mine() & mutable()`);
}

/**
 * Brings the stack up to date after GitHub merged or rebased part of it. Fetching adopts
 * GitHub's rebases of commits you have not touched since you pushed them. A change you
 * did edit comes back divergent, and converge merges the two versions into one.
 */
export function sync(stack: Pick<Change, "changeId">[], remote: string): void {
  jj("git", "fetch", "--remote", remote);
  if (stack.length === 0) return;
  const left = `(${revset(stack)}) & mutable()`;
  if (changes(left).length === 0) return;
  jj("converge", "--no-interactive", "-r", left);
  jj("rebase", "-s", `roots(${left})`, "-d", "trunk()", "--skip-emptied");
  if (changes(left).length > 0) jj("git", "push", "--remote", remote, "-r", left);
}
