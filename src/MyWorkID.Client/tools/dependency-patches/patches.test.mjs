import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const braces = require('braces');
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));

function withInstalledFixture(check) {
  const fixture = mkdtempSync(join(tmpdir(), 'azd-dependency-patch-'));
  try {
    for (const relative of [
      'tools/dependency-patches/apply.mjs',
      'tools/dependency-patches/safe-depth.cjs',
      'package-lock.json',
      'node_modules/braces/package.json',
      'node_modules/braces/lib/parse.js',
      'node_modules/braces/lib/compile.js',
      'node_modules/braces/lib/expand.js',
      'node_modules/braces/lib/stringify.js',
      'node_modules/braces/lib/safe-depth.js',
    ]) {
      const target = join(fixture, relative);
      mkdirSync(dirname(target), { recursive: true });
      copyFileSync(join(root, relative), target);
    }
    check(fixture, () => spawnSync(process.execPath, [join(fixture, 'tools/dependency-patches/apply.mjs')], { encoding: 'utf8' }));
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

test('installation fails closed if upstream dependency bytes drift', () => {
  withInstalledFixture((fixture, apply) => {
    const changed = join(fixture, 'node_modules/braces/lib/parse.js');
    writeFileSync(changed, readFileSync(changed, 'utf8') + '\n');
    const result = apply();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Unexpected upstream bytes for braces\/lib\/parse\.js/);
  });
});

test('installation is idempotent and rejects a changed mitigation helper', () => {
  withInstalledFixture((fixture, apply) => {
    const files = ['parse.js', 'compile.js', 'expand.js', 'stringify.js', 'safe-depth.js'];
    const before = files.map(file => readFileSync(join(fixture, 'node_modules/braces/lib', file)));
    assert.equal(apply().status, 0);
    files.forEach((file, index) => assert.deepEqual(readFileSync(join(fixture, 'node_modules/braces/lib', file)), before[index]));
    writeFileSync(join(fixture, 'node_modules/braces/lib/safe-depth.js'), 'changed helper');
    const result = apply();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Unexpected safe-depth helper bytes/);
  });
});

test('installation rejects unreviewed locked copies and installed versions', () => {
  withInstalledFixture((fixture, apply) => {
    const lockPath = join(fixture, 'package-lock.json');
    const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
    lock.packages['node_modules/example/node_modules/braces'] = { version: '3.0.3' };
    writeFileSync(lockPath, JSON.stringify(lock));
    assert.match(apply().stderr, /Unexpected braces dependency layout or version/);
    delete lock.packages['node_modules/example/node_modules/braces'];
    lock.packages['node_modules/braces'].version = '3.0.4';
    writeFileSync(lockPath, JSON.stringify(lock));
    assert.match(apply().stderr, /Unexpected braces dependency layout or version/);
    lock.packages['node_modules/braces'].version = '3.0.3';
    writeFileSync(lockPath, JSON.stringify(lock));
    writeFileSync(join(fixture, 'node_modules/braces/package.json'), '{"version":"3.0.4"}');
    assert.match(apply().stderr, /Unexpected braces dependency layout or version/);
  });
});

test('ordinary brace patterns retain compile and expansion behavior', () => {
  assert.deepEqual(braces('{alpha,beta}'), ['(alpha|beta)']);
  assert.deepEqual(braces('{alpha,beta}', { expand: true }), ['alpha', 'beta']);
});

test('input parsing bounds nesting before recursive walkers run', () => {
  assert.throws(() => braces.parse('{a,'.repeat(129) + 'b' + '}'.repeat(129)), /nesting exceeds the safe limit/);
  assert.throws(() => braces.parse('('.repeat(129) + ')'.repeat(129)), /nesting exceeds the safe limit/);
});

test('direct AST compile, expand, and stringify reject unsafe depth without stack exhaustion', () => {
  let ast = { type: 'text', value: 'x' };
  for (let i = 0; i < 12000; i += 1) ast = { type: 'root', nodes: [ast] };
  for (const operation of ['compile', 'expand', 'stringify']) {
    assert.throws(() => braces[operation](ast), /AST size exceeds the safe limit/);
  }
});

test('bounded nested patterns and supplied ASTs preserve ordinary behavior', () => {
  const ast = braces.parse('{a,{b,c}}');
  assert.equal(braces.compile(ast), '(a|(b|c))');
  assert.deepEqual(braces.expand(ast), ['a', 'b', 'c']);
  assert.equal(braces.stringify(ast), '{a,{b,c}}');
});

test('direct AST walkers reject cycles and oversized trees', () => {
  const cyclic = { type: 'root', nodes: [] };
  cyclic.nodes.push(cyclic);
  const wide = { type: 'root', nodes: Array.from({ length: 20001 }, () => ({ type: 'text', value: 'x' })) };
  for (const operation of ['compile', 'expand', 'stringify']) {
    assert.throws(() => braces[operation](cyclic), /Cyclic braces AST/);
    assert.throws(() => braces[operation](wide), /AST size exceeds the safe limit/);
  }
});
