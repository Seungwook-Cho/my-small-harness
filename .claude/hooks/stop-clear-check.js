#!/usr/bin/env node
// stop-clear-check.js
// Checks if a BIG task is fully complete (all checkboxes checked in tasks.md).
// If so, outputs a /clear recommendation. Runs as Stop hook — no Claude context consumed.

const fs = require('fs');
const path = require('path');

const projectDir = process.env.CLAUDE_PROJECT_DIR || '.';
const activeDir = path.join(projectDir, 'dev', 'active');

// Skip if no active directory
if (!fs.existsSync(activeDir)) {
  process.exit(0);
}

// Find tasks.md files in active directories
let dirs;
try {
  dirs = fs.readdirSync(activeDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);
} catch {
  process.exit(0);
}

for (const dir of dirs) {
  const tasksPath = path.join(activeDir, dir, 'tasks.md');
  if (!fs.existsSync(tasksPath)) continue;

  const content = fs.readFileSync(tasksPath, 'utf8');
  const totalMatches = content.match(/^- \[[ x]\]/gm);
  const doneMatches = content.match(/^- \[x\]/gm);

  const total = totalMatches ? totalMatches.length : 0;
  const done = doneMatches ? doneMatches.length : 0;

  if (total > 0 && total === done) {
    console.log(`[CLEAR] BIG task "${dir}" complete (${done}/${total}). /dev-docs-update then /clear recommended.`);
  }
}
