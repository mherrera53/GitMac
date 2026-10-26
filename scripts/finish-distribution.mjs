import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [candidateArgument, submissionID, profile] = process.argv.slice(2);
if (!candidateArgument || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(submissionID || '') || !profile) {
  throw Error('Usage: node scripts/finish-distribution.mjs CANDIDATE_DIRECTORY SUBMISSION_UUID KEYCHAIN_PROFILE');
}
const directory = await fs.realpath(path.resolve(root, candidateArgument));
const allowed = await fs.realpath(path.join(root, 'build/DistributionCandidates'));
if (!directory.startsWith(allowed + path.sep)) throw Error('Only a separate local candidate may be finalized');
const preparation = JSON.parse(await fs.readFile(path.join(directory, 'preparation.json'), 'utf8'));
const app = path.join(directory, 'GitMac.app');
const input = path.join(directory, 'GitMac-notary-input.zip');
const output = path.join(directory, 'GitMac-arm64-notarized.zip');
const hash = async file => crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');
const run = (command, args) => execFileSync(command, args, { encoding: 'utf8', timeout: 120000 });
if (await hash(input) !== preparation.archiveSHA256) throw Error('Submitted archive no longer matches its recorded digest');
if (await hash(path.join(app, 'Contents/MacOS/GitMac')) !== preparation.signedBinarySHA256) throw Error('Candidate binary changed after submission');
try { await fs.access(output); throw Error('Final archive already exists; refuse to overwrite it'); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
const signature = spawnSync('/usr/bin/codesign', ['-dvv', app], { encoding: 'utf8', timeout: 30000 });
if (signature.status !== 0 || !signature.stderr.includes(`TeamIdentifier=${preparation.teamIdentifier}\n`)) {
  throw Error('Candidate signing team does not match its preparation');
}
// Liveness and state are checked together; no global termination is performed.
spawnSync('/usr/bin/pgrep', ['-x', 'notarytool'], { encoding: 'utf8' });
const info = JSON.parse(run('xcrun', ['notarytool', 'info', submissionID, '--keychain-profile', profile, '--output-format', 'json']));
if (info.id !== submissionID || info.status !== 'Accepted') throw Error('Apple has not accepted this submission');
const notaryLog = JSON.parse(run('xcrun', ['notarytool', 'log', submissionID, '--keychain-profile', profile]));
await fs.writeFile(path.join(directory, 'notary-log.json'), JSON.stringify(notaryLog, null, 2) + '\n');
if (notaryLog.jobId !== submissionID || notaryLog.sha256?.toLowerCase() !== preparation.archiveSHA256) {
  throw Error('Apple log does not attest to this exact submitted archive');
}
run('xcrun', ['stapler', 'staple', app]);
run('xcrun', ['stapler', 'validate', app]);
run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', app]);
const gatekeeper = spawnSync('/usr/sbin/spctl', ['--assess', '--type', 'execute', '--verbose=4', app], { encoding: 'utf8', timeout: 120000 });
if (gatekeeper.status !== 0) throw Error(`Gatekeeper assessment failed: ${gatekeeper.stderr}`);
run('/usr/bin/ditto', ['-c', '-k', '--keepParent', app, output]);
const digest = await hash(output);
await fs.writeFile(output + '.sha256', `${digest}  ${path.basename(output)}\n`);
const report = { date: new Date().toISOString(), submissionID, status: info.status,
  inputSHA256: preparation.archiveSHA256, appleLogSHA256: notaryLog.sha256,
  app, archive: output, archiveSHA256: digest, staplingValidated: true, strictSignatureValidated: true,
  gatekeeper: gatekeeper.stderr.trim(), teamIdentifier: preparation.teamIdentifier,
  scope: 'Technical arm64 candidate; no installation, upgrade, clean-Mac, UI or complete roadmap approval.' };
await fs.writeFile(path.join(directory, 'distribution.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
