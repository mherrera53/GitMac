import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// This prepares a separate local candidate; it never submits, publishes,
// installs, edits entitlements or signs the original build product.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const identity = process.argv[2];
if (!/^[0-9A-Fa-f]{40}$/.test(identity || '')) throw Error('Supply the exact Developer ID certificate fingerprint');
const buildLog = process.argv[3] && path.resolve(root, process.argv[3]);
if (!buildLog || !(await fs.readFile(buildLog, 'utf8')).includes('** BUILD SUCCEEDED **')) {
  throw Error('Supply a completed Release build gate log as the second argument; never package while the build is running');
}
const source = path.join(root, 'build/Build/Products/Release/GitMac.app');
const identities = execFileSync('security', ['find-identity', '-v', '-p', 'codesigning'], { encoding: 'utf8' });
const selected = identities.split('\n').find(line => line.includes(identity.toUpperCase()));
if (!selected?.includes('Developer ID Application:')) throw Error('A valid Developer ID Application identity is required');
const run = (command, args) => execFileSync(command, args, { encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
const hash = async file => crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');
const parent = path.join(root, 'build/DistributionCandidates');
await fs.mkdir(parent, { recursive: true });
const directory = await fs.mkdtemp(path.join(parent, 'candidate-'));
const app = path.join(directory, 'GitMac.app');
const sourceBinary = path.join(source, 'Contents/MacOS/GitMac');
const sourceHash = await hash(sourceBinary);
run('/usr/bin/ditto', [source, app]);
const binaries = [], bundles = [];
async function walk(directory) {
  for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) {
      const target = await fs.realpath(file);
      if (!target.startsWith(app + path.sep)) throw Error('Candidate contains an escaping symbolic link');
    } else if (entry.isDirectory()) {
      await walk(file);
      if (/\.(framework|app|xpc)$/.test(entry.name)) bundles.push(file);
    } else if (entry.isFile()) {
      const handle = await fs.open(file, 'r');
      const magic = Buffer.alloc(4);
      try { await handle.read(magic, 0, 4, 0); } finally { await handle.close(); }
      if (['cffaedfe', 'cefaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca'].includes(magic.toString('hex'))) binaries.push(file);
    }
  }
}
await walk(app);
const bundleIdentifier = run('/usr/bin/plutil', ['-extract', 'CFBundleIdentifier', 'raw', '-o', '-', path.join(app, 'Contents/Info.plist')]).trim();
if (!/^[A-Za-z0-9.-]+$/.test(bundleIdentifier)) throw Error('Invalid app bundle identifier');
const inventory = [];
for (const file of binaries) {
  const architecture = run('/usr/bin/lipo', ['-archs', file]).trim();
  if (!architecture.split(/\s+/).includes('arm64')) throw Error('Candidate contains a binary without arm64');
  inventory.push({ path: path.relative(app, file), architecture, beforeSHA256: await hash(file) });
}
await fs.writeFile(path.join(directory, 'inventory-before-signing.json'), JSON.stringify(inventory, null, 2) + '\n');
for (const target of [...binaries, ...bundles, app]) {
  const args = ['--force', '--sign', identity, '--options', 'runtime', '--timestamp'];
  if (target === app) args.push('--identifier', bundleIdentifier, '--entitlements', path.join(root, 'GitMac/GitMac.entitlements'));
  run('/usr/bin/codesign', [...args, target]);
}
run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', app]);
const details = spawnSync('/usr/bin/codesign', ['-dvv', app], { encoding: 'utf8', timeout: 30000 });
const signature = details.stderr || '';
if (details.status !== 0 || !signature.includes('runtime') || !signature.includes(`Identifier=${bundleIdentifier}\n`)
    || !/TeamIdentifier=[A-Z0-9]{10}/.test(signature)) throw Error('Signed candidate metadata is incomplete');
const zip = path.join(directory, 'GitMac-notary-input.zip');
run('/usr/bin/ditto', ['-c', '-k', '--keepParent', app, zip]);
if (await hash(sourceBinary) !== sourceHash) throw Error('Original build product changed while preparing candidate');
const report = { date: new Date().toISOString(), directory, app, zip, identity, bundleIdentifier, buildLog,
  teamIdentifier: signature.match(/TeamIdentifier=([A-Z0-9]{10})/)[1], hardenedRuntime: true,
  sourceBinarySHA256: sourceHash, signedBinarySHA256: await hash(path.join(app, 'Contents/MacOS/GitMac')),
  archiveSHA256: await hash(zip), binaries: inventory.map(item => item.path),
  originalBuildProductPreserved: true, signatureVerified: true, notarization: 'not submitted',
  limitation: 'Technical candidate only; no launch, clean-Mac, upgrade or roadmap functional approval.' };
await fs.writeFile(path.join(directory, 'preparation.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
