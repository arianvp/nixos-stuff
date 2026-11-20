import { type Change, changes, jj, trackedBookmarks } from "./jj.ts";
import { revset } from "./stack.ts";

/** The user's mutable changes from trunk up to `rev`, plus everything stacked on top of them. */
export function syncable(rev: string): Change[] {
  return changes(`((trunk()..(${rev}))::) & mine() & mutable()`);
}

/**
 * Brings the stack up to date after GitHub merged or rebased part of it. Fetching adopts
 * GitHub's rebases of commits you have not touched since you pushed them. A change you
 * did edit comes back divergent, and converge merges the two versions into one. A merge
 * that drops change IDs (squash, merge commit) leaves the stack on the old commits, so
 * it is rebased onto trunk, dropping changes that trunk already contains. Only bookmarks
 * already on the remote are pushed: changes stacked on top that were never submitted
 * keep their bookmarks local.
 */
export function sync(stack: Pick<Change, "changeId">[], remote: string): void {
  jj("git", "fetch", "--remote", remote);
  if (stack.length === 0) return;
  const left = `(${revset(stack)}) & mutable()`;
  const divergent = `(${left}) & divergent()`;
  if (changes(divergent).length > 0) jj("converge", "--no-interactive", "-r", divergent);
  const behind = `roots(${left}) ~ trunk()+`;
  if (changes(behind).length > 0) jj("rebase", "-s", behind, "-d", "trunk()", "--skip-emptied");
  const tracked = trackedBookmarks(remote);
  const pushed = changes(left).flatMap((c) => c.bookmarks.filter((b) => tracked.has(b)));
  if (pushed.length > 0) jj("git", "push", "--remote", remote, ...pushed.flatMap((b) => ["-b", `exact:${b}`]));
}
