import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, extname } from "node:path";
import { tmpdir } from "node:os";

// Every text file git would ship: tracked plus untracked-but-not-ignored, so a
// local tool folder that .gitignore excludes never fails the gate.
const dash = new RegExp(`[${String.fromCharCode(0x2013)}${String.fromCharCode(0x2014)}]`);
const binary = new Set([".png", ".icns", ".zip", ".jpg", ".webp", ".car"]);

function files() {
  return execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], { encoding: "utf8" })
    .split("\n")
    .filter((path) => path && existsSync(path) && !binary.has(extname(path)));
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

const all = files();
const hits = all.flatMap(scan);
if (hits.length) {
  console.log(hits.map((h) => `FAIL dash at ${h}`).join("\n"));
  process.exit(1);
}
console.log(`scanned ${all.length} files`);
console.log("DASHES_OK");
