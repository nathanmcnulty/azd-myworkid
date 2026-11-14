'use strict';

// Bound recursive walkers even when callers supply an AST directly.
const MAX_DEPTH = 128;
const MAX_NODES = 20000;

function assertSafeDepth(ast) {
  const stack = [{ node: ast, depth: 0 }];
  const seen = new Set();
  while (stack.length > 0) {
    const { node, depth } = stack.pop();
    if (!node || typeof node !== 'object') continue;
    if (seen.has(node)) throw new RangeError('Cyclic braces AST');
    seen.add(node);
    if (seen.size > MAX_NODES || depth > MAX_DEPTH) {
      throw new RangeError('Brace pattern nesting or AST size exceeds the safe limit');
    }
    if (Array.isArray(node.nodes)) {
      for (const child of node.nodes) stack.push({ node: child, depth: depth + 1 });
    }
  }
}

assertSafeDepth.MAX_DEPTH = MAX_DEPTH;
module.exports = assertSafeDepth;
