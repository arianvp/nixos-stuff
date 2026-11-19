import { type Change, changes, pushBookmarkName } from "./jj.ts";

export interface Entry extends Change {
  branch: string;
  title: string;
  body: string;
}

/** The working copy, or its parent when the working copy is an empty, undescribed scratch commit. */
export const DEFAULT_REV = 'coalesce(@ ~ (empty() & description(exact:"")), @-)';

/**
 * The changes from trunk up to `rev`, oldest first. They have to be a straight line of
 * the user's own mutable, described changes: that is what a GitHub stack can represent.
 */
export function resolve(rev: string): Entry[] {
  const stack = changes(`trunk()..(${rev})`);
  if (stack.length === 0) throw new Error(`nothing between trunk() and ${rev}`);

  const foreign = changes(`trunk()..(${rev}) ~ (mine() & mutable())`);
  if (foreign.length > 0) {
    throw new Error(`not your own mutable changes: ${foreign.map((c) => c.changeId.slice(0, 8)).join(", ")}`);
  }

  return stack.map((change, i) => {
    if (change.parents.length !== 1 || (i > 0 && change.parents[0] !== stack[i - 1].commitId)) {
      throw new Error(`${change.changeId.slice(0, 8)} is not a single straight line on top of trunk()`);
    }
    const [title, ...rest] = change.description.trim().split("\n");
    if (!title) throw new Error(`${change.changeId.slice(0, 8)} has no description`);
    return {
      ...change,
      branch: change.bookmarks[0] ?? pushBookmarkName(change.changeId),
      title,
      body: rest.join("\n").trim(),
    };
  });
}

/** A revset naming the stack's changes by change ID, so it survives rewrites and abandons. */
export function revset(stack: Pick<Change, "changeId">[]): string {
  return stack.map((c) => `present(change_id(${c.changeId}))`).join(" | ");
}
