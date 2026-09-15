/* Puts the version from the git tag into the files that actually decide what
   an installed copy thinks it is running.
   --------------------------------------------------------------------------
   The tag name only labels the GitHub Release. The version the updater
   compares against lives in src-tauri/tauri.conf.json, so if the two drift
   apart you get a release that every installed copy quietly ignores, because
   it announces itself as the version they already have.

   The release workflow runs this before building, so tagging v1.0.1 is the
   whole ritual. Nothing is committed back — these files are rewritten on the
   build machine only, which is why tauri.conf.json in the repository stays at
   whatever you last wrote there. The tag is the source of truth.

   Run by hand to check what a tag would do:
       node scripts/sync-version.mjs 1.2.3
*/

import { readFileSync, writeFileSync } from 'node:fs';

const raw = process.argv[2] || '';
const version = raw.replace(/^v/, '').trim();

if (!/^\d+\.\d+\.\d+$/.test(version)) {
  console.error(
    `Tag "${raw}" is not a version this can use.\n` +
    `Tags must look like v1.2.3 — three numbers, nothing else. ` +
    `Windows installers and the updater both refuse anything else, ` +
    `so a tag like "v1.1" or "v2.0-beta" would fail later and less clearly.`
  );
  process.exit(1);
}

const CONFIG = 'src-tauri/tauri.conf.json';
const CARGO  = 'src-tauri/Cargo.toml';
const PKG    = 'package.json';

// ---- tauri.conf.json: the one the updater actually reads ----
const config = JSON.parse(readFileSync(CONFIG, 'utf8'));
const was = config.version;
config.version = version;
writeFileSync(CONFIG, JSON.stringify(config, null, 2) + '\n');

// ---- Cargo.toml: only the [package] version, left alone otherwise ----
// The regex is anchored to the start of a line, so `rust-version = ...` and
// the `version = "2"` inside a dependency table are both safely skipped.
const cargo = readFileSync(CARGO, 'utf8');
if (!/^version = "[^"]*"$/m.test(cargo)) {
  console.error(`Could not find the package version line in ${CARGO}. Nothing was changed there.`);
  process.exit(1);
}
writeFileSync(CARGO, cargo.replace(/^version = "[^"]*"$/m, `version = "${version}"`));

// ---- package.json: cosmetic, but keeps the three in step ----
const pkg = JSON.parse(readFileSync(PKG, 'utf8'));
pkg.version = version;
writeFileSync(PKG, JSON.stringify(pkg, null, 2) + '\n');

console.log(`Building version ${version} (files said ${was} before this ran).`);
