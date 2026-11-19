import { parseArgs } from "node:util";
import { connect } from "./github.ts";
import { JjFailed } from "./jj.ts";
import { merge } from "./merge.ts";
import { DEFAULT_REV, resolve } from "./stack.ts";
import { submit } from "./submit.ts";
import { sync, syncable } from "./sync.ts";

const usage = `usage: jj stack <submit|merge|sync> [REV] [--remote NAME] [--dry-run] [--force-description]

  submit  push trunk()..REV, open or update one PR per change, and stack them on GitHub
  merge   merge REV's PR and everything below it, then sync
  sync    fetch, converge divergent changes, rebase onto trunk() and push`;

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    remote: { type: "string", default: "origin" },
    "dry-run": { type: "boolean", default: false },
    "force-description": { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
});

const [command, rev = DEFAULT_REV] = positionals;
const { remote } = values;

try {
  if (values.help || !command) {
    console.log(usage);
  } else if (command === "submit") {
    await submit(await connect(remote), resolve(rev), {
      remote,
      dryRun: values["dry-run"],
      forceDescription: values["force-description"],
    });
  } else if (command === "merge") {
    const above = syncable(rev);
    await merge(await connect(remote), resolve(rev));
    sync(above, remote);
  } else if (command === "sync") {
    // No validation: after a fetch elsewhere the stack may already be divergent, which sync fixes.
    sync(syncable(rev), remote);
  } else {
    throw new Error(`unknown command ${command}\n\n${usage}`);
  }
} catch (error) {
  if (!(error instanceof JjFailed)) console.error(`jj stack: ${error instanceof Error ? error.message : error}`);
  process.exitCode = 1;
}
