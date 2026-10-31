import { readFileSync, readdirSync, statSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

function swiftFiles(path) {
  return statSync(path).isDirectory()
    ? readdirSync(path).flatMap((name) => swiftFiles(join(path, name)))
    : path.endsWith(".swift") ? [path] : [];
}

// Matched per file, not per line, so a modifier chain split over lines cannot hide.
function problems(path) {
  const found = [];
  readFileSync(path, "utf8").split("\n").forEach((line, i) => {
    const code = line.replace(/"AppleAccentColor"/g, "").replace(/^\s*\/\/.*$/, "");
    // Any accent colour that is not AppColors.brand: SwiftUI's, AppKit's, or the system's.
    if (/accentColor|controlAccentColor/.test(code)) found.push(`${path}:${i + 1} accent color other than AppColors.brand`);
    if (/\bNSPopover\b/.test(code)) found.push(`${path}:${i + 1} NSPopover`);
    // This app has no links or plain clickable surfaces, so a pointing hand is
    // always a switch or a control that should keep the system cursor.
    if (/pointingHand|pointerStyle\(\.link\)/.test(code)) found.push(`${path}:${i + 1} pointing hand cursor`);
  });
  return found;
}

// Positive control: every rule has to fire on a fixture before its silence means anything.
const dir = mkdtempSync(join(tmpdir(), "brand-"));
const fixture = join(dir, "Control.swift");
writeFileSync(fixture, [
  "let a = Color.accentColor",
  "let b = Color(nsColor: .controlAccentColor)",
  "let c = NSPopover()",
  "Toggle(\"\", isOn: $on)",
  "    .cursor(.pointingHand)",
].join("\n"));
const controlHits = problems(fixture).length;
rmSync(dir, { recursive: true, force: true });
if (controlHits !== 4) {
  console.log(`FAIL scanner control (${controlHits} of 4 rules fired)`);
  process.exit(1);
}

const root = "Sources/ImperatorHotCorners";
const all = swiftFiles(root).flatMap(problems);
if (!readFileSync(join(root, "AppDelegate.swift"), "utf8").includes('set(0, forKey: "AppleAccentColor")')) {
  all.push("AppDelegate.swift does not set AppleAccentColor");
}
if (all.length) {
  console.log(all.map((p) => `FAIL ${p}`).join("\n"));
  process.exit(1);
}
console.log("BRAND_OK");
