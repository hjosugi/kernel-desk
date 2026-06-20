import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDirectory, "..");
const backendRoot = path.join(projectRoot, "backend");
const envFile = path.join(projectRoot, ".env");
const command = process.platform === "win32" ? "gleam.exe" : "gleam";

const environment = {
  ...process.env,
  ...readEnvFile(envFile),
};

const child = spawn(command, ["run"], {
  cwd: backendRoot,
  env: environment,
  stdio: "inherit",
});

child.on("error", (error) => {
  console.error(`Failed to start Gleam: ${error.message}`);
  console.error("Install Gleam 1.17 or use mise before running npm start.");
  process.exitCode = 1;
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }

  process.exitCode = code ?? 1;
});

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
