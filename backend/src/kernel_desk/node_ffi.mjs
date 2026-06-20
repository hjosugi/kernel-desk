import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, openSync, closeSync, readFileSync, readSync, realpathSync, renameSync, statSync, writeFileSync } from "node:fs";
import http from "node:http";
import path from "node:path";

const MAX_REQUEST_BYTES = 1_000_000;
const MAX_SOURCE_BYTES = 512_000;
const MAX_SOURCE_LINES = 1_600;

export function env(name, fallback) {
  const value = process.env[name];
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

export function envInt(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? "", 10);
  return Number.isSafeInteger(value) && value > 0 && value <= 65_535
    ? value
    : fallback;
}

export function queryParam(query, key) {
  return new URLSearchParams(query).get(key) ?? "";
}

export function gitSnapshot(repoRoot) {
  const root = path.resolve(repoRoot);

  if (!existsSync(root)) {
    return JSON.stringify({ error: `Repository path does not exist: ${root}` });
  }

  if (!isGitRepository(root)) {
    return JSON.stringify({
      root,
      isGitRepo: false,
      branch: "",
      remote: "",
      headSummary: "",
      headAuthor: "",
      headDate: "",
      changes: [],
    });
  }

  const branch = runGit(root, ["branch", "--show-current"], "");
  const remote = runGit(root, ["config", "--get", "remote.origin.url"], "");
  const head = runGit(
    root,
    ["log", "-1", "--pretty=format:%h%x1f%s%x1f%an%x1f%cI"],
    "",
  ).split("\u001f");
  const changes = parseGitStatus(
    runGit(
      root,
      ["status", "--porcelain=v1", "--untracked-files=normal"],
      "",
      { preserveLeadingWhitespace: true },
    ),
  );

  return JSON.stringify({
    root,
    isGitRepo: true,
    branch,
    remote,
    headSummary: [head[0], head[1]].filter(Boolean).join(" "),
    headAuthor: head[2] ?? "",
    headDate: head[3] ?? "",
    changes,
  });
}

export function readSource(repoRoot, relativePath) {
  try {
    const resolved = resolveInside(repoRoot, relativePath);
    const info = statSync(resolved.absolutePath);

    if (!info.isFile()) {
      return JSON.stringify({ error: `Not a regular file: ${resolved.relativePath}` });
    }

    const bytesToRead = Math.min(info.size, MAX_SOURCE_BYTES);
    const buffer = Buffer.alloc(bytesToRead);
    const descriptor = openSync(resolved.absolutePath, "r");

    try {
      readSync(descriptor, buffer, 0, bytesToRead, 0);
    } finally {
      closeSync(descriptor);
    }

    const decoded = buffer.toString("utf8");
    const lines = decoded.split(/\r?\n/);
    const visibleLines = lines.slice(0, MAX_SOURCE_LINES);
    const truncated = info.size > bytesToRead || lines.length > MAX_SOURCE_LINES;

    return JSON.stringify({
      path: resolved.relativePath,
      content: visibleLines.join("\n"),
      lineCount: info.size > bytesToRead ? visibleLines.length : lines.length,
      truncated,
    });
  } catch (error) {
    return JSON.stringify({ error: errorMessage(error) });
  }
}

export function loadProgress(dataFile) {
  try {
    const store = readProgressStore(dataFile);
    const items = Object.values(store).sort((left, right) =>
      left.path.localeCompare(right.path),
    );
    return JSON.stringify(items);
  } catch (error) {
    return JSON.stringify({ error: errorMessage(error) });
  }
}

export function saveProgress(dataFile, sourcePath, status, note) {
  try {
    const store = readProgressStore(dataFile);
    const item = {
      path: sourcePath,
      status,
      note,
      updatedAt: new Date().toISOString(),
    };

    store[sourcePath] = item;
    writeProgressStore(dataFile, store);
    return JSON.stringify(item);
  } catch (error) {
    return JSON.stringify({ error: errorMessage(error) });
  }
}

export function startServer(port, staticRoot, handler) {
  const resolvedStaticRoot = path.resolve(staticRoot);

  const server = http.createServer((request, response) => {
    const chunks = [];
    let receivedBytes = 0;
    let requestTooLarge = false;

    request.on("data", (chunk) => {
      receivedBytes += chunk.length;
      if (receivedBytes <= MAX_REQUEST_BYTES) {
        chunks.push(chunk);
      } else {
        requestTooLarge = true;
      }
    });

    request.on("end", () => {
      try {
        const requestUrl = new URL(
          request.url ?? "/",
          `http://${request.headers.host ?? "127.0.0.1"}`,
        );

        if (requestTooLarge) {
          sendResponse(response, 413, "application/json; charset=utf-8", JSON.stringify({
            error: "Request body is too large.",
          }));
          return;
        }

        if (requestUrl.pathname.startsWith("/api/") || request.method === "OPTIONS") {
          const body = Buffer.concat(chunks).toString("utf8");
          const encodedResponse = handler(
            request.method ?? "GET",
            requestUrl.pathname,
            requestUrl.searchParams.toString(),
            body,
          );
          const parsedResponse = JSON.parse(encodedResponse);

          sendResponse(
            response,
            Number(parsedResponse.status) || 500,
            parsedResponse.contentType || "application/json; charset=utf-8",
            typeof parsedResponse.body === "string" ? parsedResponse.body : "",
          );
          return;
        }

        serveStatic(response, resolvedStaticRoot, requestUrl.pathname);
      } catch (error) {
        sendResponse(
          response,
          500,
          "application/json; charset=utf-8",
          JSON.stringify({ error: errorMessage(error) }),
        );
      }
    });

    request.on("error", (error) => {
      sendResponse(
        response,
        400,
        "application/json; charset=utf-8",
        JSON.stringify({ error: errorMessage(error) }),
      );
    });
  });

  server.listen(port, "127.0.0.1", () => {
    console.log(`KernelDesk is running at http://127.0.0.1:${port}`);
  });

  return undefined;
}

function isGitRepository(root) {
  try {
    return runGit(root, ["rev-parse", "--is-inside-work-tree"], "false") === "true";
  } catch {
    return false;
  }
}

function runGit(root, args, fallback, options = {}) {
  try {
    const output = execFileSync("git", ["-C", root, ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 5_000,
      maxBuffer: 2_000_000,
    });

    return options.preserveLeadingWhitespace
      ? output.trimEnd()
      : output.trim();
  } catch {
    return fallback;
  }
}

function parseGitStatus(rawStatus) {
  if (rawStatus.length === 0) {
    return [];
  }

  return rawStatus
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      const rawPath = line.slice(3);
      const renamedPath = rawPath.includes(" -> ")
        ? rawPath.split(" -> ").at(-1)
        : rawPath;

      return {
        code: line.slice(0, 2).trim() || "?",
        path: renamedPath ?? rawPath,
      };
    });
}

function resolveInside(rootPath, relativePath) {
  if (typeof relativePath !== "string" || relativePath.trim().length === 0) {
    throw new Error("Source path cannot be empty.");
  }

  if (path.isAbsolute(relativePath)) {
    throw new Error("Use a repository-relative path, not an absolute path.");
  }

  const realRoot = realpathSync(path.resolve(rootPath));
  const candidate = path.resolve(realRoot, relativePath);
  const realCandidate = realpathSync(candidate);
  const relative = path.relative(realRoot, realCandidate);

  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error("The requested path is outside the configured repository.");
  }

  return {
    absolutePath: realCandidate,
    relativePath: relative.split(path.sep).join("/"),
  };
}

function readProgressStore(dataFile) {
  const absolutePath = path.resolve(dataFile);

  if (!existsSync(absolutePath)) {
    return {};
  }

  const raw = readFileSync(absolutePath, "utf8");
  if (raw.trim().length === 0) {
    return {};
  }

  const parsed = JSON.parse(raw);
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
    throw new Error("Progress data must be a JSON object.");
  }

  return parsed;
}

function writeProgressStore(dataFile, store) {
  const absolutePath = path.resolve(dataFile);
  const directory = path.dirname(absolutePath);
  const temporaryPath = `${absolutePath}.${process.pid}.tmp`;

  mkdirSync(directory, { recursive: true });
  writeFileSync(temporaryPath, `${JSON.stringify(store, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, absolutePath);
}

function serveStatic(response, staticRoot, requestPath) {
  const requestedFile = requestPath === "/" ? "index.html" : requestPath.slice(1);
  let absolutePath = path.resolve(staticRoot, requestedFile);
  const relative = path.relative(staticRoot, absolutePath);

  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    sendResponse(response, 403, "text/plain; charset=utf-8", "Forbidden");
    return;
  }

  if (!existsSync(absolutePath) || !statSync(absolutePath).isFile()) {
    absolutePath = path.join(staticRoot, "index.html");
  }

  if (!existsSync(absolutePath) || !statSync(absolutePath).isFile()) {
    sendResponse(
      response,
      503,
      "text/plain; charset=utf-8",
      "Frontend is not built. Run: npm run build:frontend",
    );
    return;
  }

  const body = readFileSync(absolutePath);
  sendResponse(response, 200, contentTypeFor(absolutePath), body);
}

function sendResponse(response, status, contentType, body) {
  if (response.headersSent) {
    return;
  }

  response.statusCode = status;
  response.setHeader("Content-Type", contentType);
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Headers", "content-type");
  response.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  response.end(body);
}

function contentTypeFor(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case ".html":
      return "text/html; charset=utf-8";
    case ".js":
    case ".mjs":
      return "text/javascript; charset=utf-8";
    case ".css":
      return "text/css; charset=utf-8";
    case ".json":
      return "application/json; charset=utf-8";
    case ".svg":
      return "image/svg+xml";
    default:
      return "application/octet-stream";
  }
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}
