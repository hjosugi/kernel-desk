import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  gitSnapshot,
  loadProgress,
  readSource,
  saveProgress,
} from "../backend/src/kernel_desk/node_ffi.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDirectory, "..");
const sampleRoot = path.join(projectRoot, "sample", "linux-mini");
const temporaryRoot = mkdtempSync(path.join(os.tmpdir(), "kernel-desk-"));

try {
  const source = JSON.parse(readSource(sampleRoot, "init/main.c"));
  assert.equal(source.path, "init/main.c");
  assert.equal(source.truncated, false);
  assert.match(source.content, /start_kernel/);

  const blocked = JSON.parse(readSource(sampleRoot, "../README.md"));
  assert.equal(typeof blocked.error, "string");

  const progressFile = path.join(temporaryRoot, "data", "progress.json");
  const saved = JSON.parse(
    saveProgress(progressFile, "init/main.c", "reading", "Trace start_kernel()."),
  );
  assert.equal(saved.path, "init/main.c");
  assert.equal(saved.status, "reading");

  const loaded = JSON.parse(loadProgress(progressFile));
  assert.equal(loaded.length, 1);
  assert.equal(loaded[0].note, "Trace start_kernel().");

  const repository = path.join(temporaryRoot, "repository");
  mkdirSync(repository);
  execFileSync("git", ["init", "--initial-branch=main", repository], {
    stdio: "ignore",
  });
  writeFileSync(path.join(repository, "README.md"), "# Local test repository\n");
  execFileSync("git", ["-C", repository, "add", "README.md"], { stdio: "ignore" });
  execFileSync(
    "git",
    [
      "-C",
      repository,
      "-c",
      "user.name=KernelDesk Test",
      "-c",
      "user.email=kernel-desk@example.invalid",
      "commit",
      "-m",
      "Initial commit",
    ],
    { stdio: "ignore" },
  );

  const snapshot = JSON.parse(gitSnapshot(repository));
  assert.equal(snapshot.isGitRepo, true);
  assert.equal(snapshot.branch, "main");
  assert.match(snapshot.headSummary, /Initial commit/);
  assert.deepEqual(snapshot.changes, []);

  writeFileSync(path.join(repository, "README.md"), "# Changed repository\n");
  const changedSnapshot = JSON.parse(gitSnapshot(repository));
  assert.equal(changedSnapshot.changes.length, 1);
  assert.equal(changedSnapshot.changes[0].path, "README.md");

  console.log("KernelDesk local verification passed.");
} finally {
  rmSync(temporaryRoot, { recursive: true, force: true });
}
