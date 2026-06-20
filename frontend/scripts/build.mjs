import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const frontendRoot = resolve(scriptDir, "..");
const outputDir = resolve(frontendRoot, "../backend/priv/static");
const optimize = process.argv.includes("--optimize");
const npx = process.platform === "win32" ? "npx.cmd" : "npx";

mkdirSync(outputDir, { recursive: true });

const args = [
  "--no-install",
  "elm",
  "make",
  "src/Main.elm",
  `--output=${join(outputDir, "app.js")}`,
];

if (optimize) {
  args.push("--optimize");
}

const result = spawnSync(npx, args, {
  cwd: frontendRoot,
  stdio: "inherit",
});

if (result.error) {
  throw result.error;
}

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

copyFileSync(
  join(frontendRoot, "public/index.html"),
  join(outputDir, "index.html"),
);
copyFileSync(
  join(frontendRoot, "public/styles.css"),
  join(outputDir, "styles.css"),
);

console.log(`Elm frontend built in ${optimize ? "optimized" : "debug"} mode.`);
