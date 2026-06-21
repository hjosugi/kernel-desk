import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryUrl = "https://github.com/torvalds/linux.git";
const command = process.argv[2] ?? "help";
const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDirectory, "..");
const envFile = path.join(projectRoot, ".env");
const environment = {
  ...process.env,
  ...readEnvFile(envFile),
};
const repositoryPath = path.resolve(
  environment.LINUX_REPO_PATH ||
    environment.KERNEL_REPO_PATH ||
    path.join(os.homedir(), "src", "linux"),
);

switch (command) {
  case "clone":
    cloneLinux();
    break;

  case "start":
    startKernelDesk({ debugBuild: false });
    break;

  case "dev":
    startKernelDesk({ debugBuild: true });
    break;

  default:
    printUsage();
    process.exit(command === "help" ? 0 : 1);
}

function cloneLinux() {
  if (existsSync(path.join(repositoryPath, ".git"))) {
    console.log(`Linux repository already exists: ${repositoryPath}`);
    console.log("Use `git -C <path> fetch --depth 1 origin` if you want to refresh it.");
    return;
  }

  if (existsSync(repositoryPath)) {
    console.error(`Target path exists but is not a Git repository: ${repositoryPath}`);
    process.exit(1);
  }

  mkdirSync(path.dirname(repositoryPath), { recursive: true });
  run("git", ["clone", "--depth", "1", repositoryUrl, repositoryPath]);
}

function startKernelDesk({ debugBuild }) {
  if (!existsSync(path.join(repositoryPath, ".git"))) {
    console.error(`Linux repository is not cloned yet: ${repositoryPath}`);
    console.error("Run `npm run linux:clone` first, or set LINUX_REPO_PATH/KERNEL_REPO_PATH.");
    process.exit(1);
  }

  if (debugBuild) {
    run(npmCommand(), ["run", "build:frontend:debug"]);
  }

  run(npmCommand(), ["start"], {
    ...environment,
    KERNEL_REPO_PATH: repositoryPath,
  });
}

function run(command_, args, env = process.env) {
  const result = spawnSync(command_, args, {
    env,
    stdio: "inherit",
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function npmCommand() {
  return process.platform === "win32" ? "npm.cmd" : "npm";
}

function readEnvFile(filePath) {
  if (!existsSync(filePath)) {
    return {};
  }

  const values = {};
  const lines = readFileSync(filePath, "utf8").split(/\r?\n/);

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith("#")) {
      continue;
    }

    const separator = line.indexOf("=");
    if (separator <= 0) {
      continue;
    }

    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (!(key in process.env)) {
      values[key] = value;
    }
  }

  return values;
}

function printUsage() {
  console.log(`Usage:
  npm run linux:clone
  npm run linux:start
  npm run linux:dev

Environment:
  LINUX_REPO_PATH=/path/to/linux
  KERNEL_REPO_PATH=/path/to/linux

Default path:
  ${repositoryPath}`);
}
