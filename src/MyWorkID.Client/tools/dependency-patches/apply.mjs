import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const hash = (content) => createHash('sha256').update(content).digest('hex').toUpperCase();

// Review every locked copy before applying this version-specific mitigation.
const lock = JSON.parse(readFileSync(resolve(root, 'package-lock.json'), 'utf8'));
const copies = Object.entries(lock.packages).filter(([path]) => /(^|\/)node_modules\/braces$/.test(path));
if (copies.length !== 1 || copies[0][0] !== 'node_modules/braces' || copies[0][1].version !== '3.0.3'
    || JSON.parse(readFileSync(resolve(root, 'node_modules/braces/package.json'), 'utf8')).version !== '3.0.3') {
  throw new Error('Unexpected braces dependency layout or version; review the dependency update before installing.');
}

function patch(relativePath, expectedSha, patchedSha, replacements) {
  const path = resolve(root, 'node_modules', relativePath);
  const original = readFileSync(path);
  const observedSha = hash(original);
  if (observedSha === patchedSha) return;
  if (observedSha !== expectedSha) {
    throw new Error(`Unexpected upstream bytes for ${relativePath}; review the dependency update before installing.`);
  }
  let updated = original.toString('utf8');
  for (const [before, after] of replacements) {
    const start = updated.indexOf(before);
    if (start < 0 || updated.indexOf(before, start + before.length) >= 0) {
      throw new Error(`Dependency patch anchor missing or repeated: ${relativePath}`);
    }
    updated = updated.slice(0, start) + after + updated.slice(start + before.length);
  }
  const patched = Buffer.from(updated);
  if (hash(patched) !== patchedSha) throw new Error(`Unexpected patch result for ${relativePath}.`);
  writeFileSync(path, patched);
}

const safeDepthSource = readFileSync(new URL('./safe-depth.cjs', import.meta.url));
const safeDepthTarget = resolve(root, 'node_modules/braces/lib/safe-depth.js');
try {
  if (hash(readFileSync(safeDepthTarget)) !== hash(safeDepthSource)) {
    throw new Error('Unexpected safe-depth helper bytes in installed braces package.');
  }
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  writeFileSync(safeDepthTarget, safeDepthSource);
}

patch('braces/lib/parse.js', 'E572166565F15FA6AD9865AE49D678218E32AABFD1B3720F6D0D43D39800D310', '3153D4A7BCC9F982BD454E8A972936D1F0E4CAF09428434FCD58FAC464C35A0C', [
  ["const stringify = require('./stringify');", "const stringify = require('./stringify');\nconst assertSafeDepth = require('./safe-depth');"],
  ["    if (value === CHAR_LEFT_PARENTHESES) {\n      block = push", "    if (value === CHAR_LEFT_PARENTHESES) {\n      if (stack.length >= assertSafeDepth.MAX_DEPTH) throw new RangeError('Brace pattern nesting exceeds the safe limit');\n      block = push"],
  ["    if (value === CHAR_LEFT_CURLY_BRACE) {\n      depth++;", "    if (value === CHAR_LEFT_CURLY_BRACE) {\n      if (stack.length >= assertSafeDepth.MAX_DEPTH) throw new RangeError('Brace pattern nesting exceeds the safe limit');\n      depth++;"],
]);

for (const [file, expectedSha, patchedSha, entry] of [
  ['compile.js', 'DC98F22EEE3D511785D92A00758D5F0D48EFED5F5813BDECC2DE430C529B5C9F', '3667F863B7DC526243B627B6B9297664B16B5AF6324DFA10DD5B20CBE99999BD', 'const compile = (ast, options = {}) => {'],
  ['expand.js', '41CCC196EBFA7B7781A634E721EB744E4E7BCB54CBA427A7E3D6806A1B9E58F7', '71DAB2EF8D6C7BD64E6CE1DD1A4FADEFBB10F9EA18F5221ED670DCBC60DED047', 'const expand = (ast, options = {}) => {'],
  ['stringify.js', '379F22D77BFA1478341CCD49C5E4267464AABCBBA03558BAB332AAC23FC6F23A', '7272AC2E8BA9A10C732B1B616EBE573814BB895C0C4E68314E97F9B224875985', 'module.exports = (ast, options = {}) => {'],
]) {
  patch(`braces/lib/${file}`, expectedSha, patchedSha, [
    ["const utils = require('./utils');", "const utils = require('./utils');\nconst assertSafeDepth = require('./safe-depth');"],
    [entry, `${entry}\n  assertSafeDepth(ast);`],
  ]);
}

console.log('Verified local dependency security patches for braces 3.0.3.');
