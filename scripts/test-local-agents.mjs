import assert from 'node:assert/strict';
import { validateJobs, validateLocalModel, validateProposal } from './local-agents.mjs';

const job = { id: 'test-owner', role: 'implementer', instruction: 'test', readFiles: ['file.swift'], writeFiles: ['file.swift'] };
const source = { path: 'file.swift', sha256: 'a'.repeat(64), content: 'original text\n' };
const edit = { path: source.path, sha256: source.sha256, old: 'original', new: 'changed' };
let checks = 0;
function check(label, action) { action(); checks++; console.log('PASS ' + label); }
check('valid ownership', () => validateJobs([job]));
check('overlapping ownership rejected', () => assert.throws(() => validateJobs([job, { ...job, id: 'other' }])));
check('traversal rejected', () => assert.throws(() => validateJobs([{ ...job, readFiles: ['../secret'], writeFiles: [] }])));
check('credentials rejected', () => assert.throws(() => validateJobs([{ ...job, readFiles: ['.env.production'], writeFiles: [] }])));
check('reviewer cannot edit', () => assert.throws(() => validateJobs([{ ...job, role: 'reviewer' }])));
check('local weights required', () => validateLocalModel({ name: 'qwen3-coder:30b', digest: 'b'.repeat(64), size: 18e9 }));
check('cloud alias rejected', () => assert.throws(() => validateLocalModel({ name: 'qwen3-coder:30b', digest: 'b'.repeat(64), size: 18e9, remote_model: 'cloud-model' })));
check('thin alias rejected', () => assert.throws(() => validateLocalModel({ name: 'qwen3-coder:30b', digest: 'b'.repeat(64), size: 388 })));
check('valid exact proposal', () => assert.equal(validateProposal({ edits: [edit], findings: [] }, job, [source]).get(source.path), 'changed text\n'));
check('stale hash rejected', () => assert.throws(() => validateProposal({ edits: [{ ...edit, sha256: 'stale' }], findings: [] }, job, [source])));
check('outside ownership rejected', () => assert.throws(() => validateProposal({ edits: [{ ...edit, path: '/tmp/foreign' }], findings: [] }, job, [source])));
check('ambiguous replacement rejected', () => assert.throws(() => validateProposal({ edits: [edit], findings: [] }, job, [{ ...source, content: 'original original' }])));
check('empty replacement rejected', () => assert.throws(() => validateProposal({ edits: [{ ...edit, new: '' }], findings: [] }, job, [source])));
check('malformed response rejected', () => assert.throws(() => validateProposal({ edits: [] }, job, [source])));
check('full-file rewrite rejected', () => assert.throws(() => validateProposal({ edits: [{ ...edit, old: 'x'.repeat(4001) }], findings: [] }, job, [source])));
check('unselected anchor rejected', () => assert.throws(() => validateProposal({ edits: [edit], findings: [] }, { ...job, editAnchors: ['different'] }, [source])));
console.log(`LOCAL_AGENT_CHECKS: ${checks} passed`);
