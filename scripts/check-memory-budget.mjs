import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function evaluateFootprint(report, pid, budgetBytes = 150_000_000) {
  const errors = [];
  if (!Number.isSafeInteger(pid) || pid <= 0) errors.push('A positive exact PID is required');
  if (!Number.isSafeInteger(budgetBytes) || budgetBytes <= 0) errors.push('Invalid byte budget');
  if (report.unit !== 'byte' || report['bytes per unit'] !== 1) errors.push('Input is not measured in bytes');
  if (!Array.isArray(report.samples) || !report.samples.length) errors.push('No samples');
  const readings = [];
  for (const [index, sample] of (Array.isArray(report.samples) ? report.samples : []).entries()) {
    if (sample.errors?.length || sample.warnings?.length) errors.push(`Sample ${index}: measurement errors/warnings`);
    const processes = sample.processes?.filter(process => process.pid === pid) ?? [];
    if (processes.length !== 1) { errors.push(`Sample ${index}: exact PID missing or duplicated`); continue; }
    const process = processes[0];
    const physical = process.auxiliary?.phys_footprint;
    const peak = process.auxiliary?.phys_footprint_peak;
    if (![physical, peak, process.footprint].every(value => Number.isSafeInteger(value) && value > 0)) {
      errors.push(`Sample ${index}: physical footprint or lifetime peak unavailable`); continue;
    }
    if (peak < physical) errors.push(`Sample ${index}: inconsistent peak`);
    readings.push({ physicalBytes: Math.max(physical, process.footprint), lifetimePeakBytes: peak });
  }
  const maximumPhysicalBytes = readings.length ? Math.max(...readings.map(item => item.physicalBytes)) : null;
  const maximumLifetimePeakBytes = readings.length ? Math.max(...readings.map(item => item.lifetimePeakBytes)) : null;
  return { pid, budgetBytes, sampleCount: readings.length, maximumPhysicalBytes, maximumLifetimePeakBytes,
    errors, passed: errors.length === 0 && readings.length > 0 && maximumPhysicalBytes <= budgetBytes && maximumLifetimePeakBytes <= budgetBytes,
    scope: 'Only these observations and this process lifetime peak. Does not certify every scenario, subprocess or future run.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const [file, pid] = process.argv.slice(2);
  if (!file || !/^[1-9]\d*$/.test(pid || '')) throw Error('Usage: node scripts/check-memory-budget.mjs FOOTPRINT_JSON EXACT_PID');
  const result = evaluateFootprint(JSON.parse(await fs.readFile(file, 'utf8')), Number(pid));
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) process.exitCode = 1;
}
