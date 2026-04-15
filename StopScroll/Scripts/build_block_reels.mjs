import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const root = process.cwd();
const scriptsDir = path.join(root, 'StopScroll', 'Scripts');
const entry = path.join(scriptsDir, 'block_reels_entry.js');
const output = path.join(scriptsDir, 'block_reels.js');
const outputTmp = path.join(scriptsDir, '.block_reels.tmp.js');
const readableMode = process.argv.includes('--readable') || !process.argv.includes('--minify');
const shouldMinify = process.argv.includes('--minify');

// Strip import lines only — modules are loaded by Swift, not inlined here.
function buildBootstrap(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  return raw
    .replace(/^\s*import\s+[^;]+;\s*$/gm, '')  // remove all import statements
    .replace(/\n{3,}/g, '\n\n')
    .trim() + '\n';
}

const bundle = [
  '// Generated file — bootstrap only. Modules are injected by Swift before this script.',
  buildBootstrap(entry)
].join('\n');

fs.writeFileSync(outputTmp, bundle, 'utf8');

if (readableMode) {
  fs.writeFileSync(output, bundle, 'utf8');
  fs.rmSync(outputTmp, { force: true });
  console.log('Generated readable', output);
  process.exit(0);
}

if (shouldMinify) {
  try {
    execSync('command -v terser', { stdio: 'ignore' });
  } catch {
    fs.rmSync(outputTmp, { force: true });
    console.error('Minify mode requires terser in PATH. Install with: npm i -g terser');
    process.exit(1);
  }
  execSync(`terser "${outputTmp}" -c -m -o "${output}"`, { stdio: 'ignore' });
}

fs.rmSync(outputTmp, { force: true });
console.log('Generated', output);
