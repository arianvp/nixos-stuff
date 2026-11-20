import { execFileSync } from "node:child_process";

export interface Change {
  commitId: string;
  changeId: string;
  parents: string[];
  description: string;
  bookmarks: string[];
}

/** jj exited with an error, which it has already printed. */
export class JjFailed extends Error {}

function run(...args: Parameters<typeof execFileSync>): string {
  try {
    return String(execFileSync(...args) ?? "");
  } catch (error) {
    if (error instanceof Error && "status" in error) throw new JjFailed();
    throw error;
  }
}

/** Runs jj with its own progress and messages going straight to the terminal. */
export function jj(...args: string[]): void {
  run("jj", args, { stdio: "inherit" });
}

/** Runs jj and returns what it prints, for templates meant to be parsed. */
export function query(...args: string[]): string {
  return run("jj", ["--color=never", "--no-pager", ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
}

/** The changes in a revset, oldest first. */
export function changes(revset: string): Change[] {
  const template = 'json(self) ++ "\\t" ++ json(local_bookmarks.map(|b| b.name())) ++ "\\n"';
  return query("log", "--no-graph", "--reversed", "-r", revset, "-T", template)
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [commit, bookmarks] = line.split("\t");
      const c = JSON.parse(commit);
      return {
        commitId: c.commit_id,
        changeId: c.change_id,
        parents: c.parents,
        description: c.description,
        bookmarks: JSON.parse(bookmarks),
      };
    });
}

/** Every description a change has had, current one included. */
export function descriptions(changeId: string): string[] {
  return query("evolog", "--no-graph", "-r", changeId, "-T", 'json(commit.description()) ++ "\\n"')
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

/** The branch name `jj git push -c` would create for a change. */
export function pushBookmarkName(changeId: string): string {
  const template = query("config", "get", "templates.git_push_bookmark").trim();
  return query("log", "--no-graph", "-r", changeId, "-T", template).trim();
}

/** Local bookmarks that track a bookmark on `remote`. */
export function trackedBookmarks(remote: string): Set<string> {
  const template = 'if(!remote, name ++ "\\n")';
  const names = query("--quiet", "bookmark", "list", "--tracked", "--remote", remote, "-T", template);
  return new Set(names.split("\n").filter(Boolean));
}

export function remoteUrl(remote: string): string {
  const line = query("git", "remote", "list")
    .split("\n")
    .find((l) => l.startsWith(`${remote} `));
  if (!line) throw new Error(`jj has no git remote named ${remote}`);
  return line.slice(remote.length + 1).trim();
}
