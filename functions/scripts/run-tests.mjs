import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const filters = process.argv.slice(2);
const unsafeFilter = filters.find(
  (filter) => !/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(filter),
);
if (unsafeFilter !== undefined) {
  process.stderr.write(`Unsafe test filter: ${unsafeFilter}\n`);
  process.exitCode = 2;
} else {
  const firebaseCLI = resolve(
    process.cwd(),
    "node_modules/firebase-tools/lib/bin/firebase.js",
  );
  const innerCommand = ["npm", "run", "test:unit"]
    .concat(filters.length === 0 ? [] : ["--", ...filters])
    .join(" ");
  const result = spawnSync(
    process.execPath,
    [
      firebaseCLI,
      "emulators:exec",
      "--config",
      "../firebase.json",
      "--project",
      "demo-tmi",
      "--only",
      "firestore,storage",
      innerCommand,
    ],
    { stdio: "inherit" },
  );
  process.exitCode = result.status ?? 1;
}
