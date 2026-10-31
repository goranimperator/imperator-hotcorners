import { readFileSync, readdirSync, statSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join, extname } from "node:path";
import { tmpdir } from "node:os";

// Every text file in the repo, not a list that can fall behind.
const dash = new RegExp(`[${String.fromCharCode(0x2013)}${String.fromCharCode(0x2014)}]`);
const skipDirs = new Set([".git", ".build", ".swiftpm", "build", "dist", "graphify-out", ".unlazy", ".claude"]);
const binary = new Set([".png", ".icns", ".zip", ".jpg", ".webp", ".car"]);

function files(path) {
  const info = statSync(path);
  if (!info.isDirectory()) return binary.has(extname(path)) ? [] : [path];
  return readdirSync(path)
    .filter((name) => !skipDirs.has(name) && name !== ".DS_Store")
    .flatMap((name) => files(join(path, name)));
}

function scan(path) {
  return readFileSync(path, "utf8").split("\n")
    .flatMap((line, i) => (dash.test(line) ? [`${path}:${i + 1}`] : []));
}

// Positive control: the scanner has to flag a known em dash before its silence means anything.
const dir = mkdtempSync(join(tmpdir(), "dashes-"));
const fixture = join(dir, "control.txt");
writeFileSync(fixture, `a ${String.fromCharCode(0x2014)} b\n`);
const controlHit = scan(fixture).length === 1;
rmSync(dir, { recursive: true, force: true });
if (!controlHit) {
  console.log("FAIL scanner control");
  process.exit(1);
}

const all = files(".");
const hits = all.flatMap(scan);
if (hits.length) {
  console.log(hits.map((h) => `FAIL dash at ${h}`).join("\n"));
  process.exit(1);
}
console.log(`scanned ${all.length} files`);
console.log("DASHES_OK");
