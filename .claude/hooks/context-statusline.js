#!/usr/bin/env node
// Context Statusline Hook
// Works as both statusLine command and Notification hook
// Shows: model | task | dir ctx [bar] NN% | rate NN%

const fs = require('fs');
const path = require('path');
const os = require('os');

const AUTOCOMPACT_BUFFER = 16.5;

const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const ORANGE = '\x1b[38;5;208m';
const RED_BLINK = '\x1b[31;5m';
const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

function getColor(pct) {
  if (pct < 50) return GREEN;
  if (pct < 65) return YELLOW;
  if (pct < 80) return ORANGE;
  return RED_BLINK;
}

function buildProgressBar(usedPct) {
  const clamped = Math.max(0, Math.min(100, usedPct));
  const filled = Math.round(clamped / 10);
  const empty = 10 - filled;
  const color = getColor(clamped);
  const skull = clamped >= 80 ? ' \u2620\uFE0F' : '';
  return `${color}[${'█'.repeat(filled)}${'░'.repeat(empty)}] ${Math.round(clamped)}%${skull}${RESET}`;
}

function getCurrentTask(sessionId) {
  try {
    const todosDir = path.join(os.homedir(), '.claude', 'todos');
    const files = fs.readdirSync(todosDir);
    const match = files.find(f => f.startsWith(sessionId));
    if (!match) return '';
    const todos = JSON.parse(fs.readFileSync(path.join(todosDir, match), 'utf8'));
    if (!Array.isArray(todos)) return '';
    const active = todos.find(t => t.status === 'in_progress');
    if (active && active.activeForm) return active.activeForm;
    if (active && active.content) return active.content;
    return '';
  } catch {
    return '';
  }
}

function writeBridgeFile(sessionId, remainingPct, usedPct) {
  const bridgePath = path.join(os.tmpdir(), `claude-ctx-${sessionId}.json`);
  const tmpPath = bridgePath + '.tmp';
  const data = JSON.stringify({
    session_id: sessionId,
    remaining_percentage: remainingPct,
    used_pct: usedPct,
    timestamp: Math.floor(Date.now() / 1000)
  });
  try {
    fs.writeFileSync(tmpPath, data, 'utf8');
    fs.renameSync(tmpPath, bridgePath);
  } catch {
    // silent
  }
}

function formatRateLimit(rateLimits) {
  if (!rateLimits) return '';
  const fiveHr = rateLimits.five_hour;
  if (fiveHr && fiveHr.used_percentage != null) {
    const pct = Math.round(fiveHr.used_percentage);
    const color = getColor(pct);

    let timerStr = '';
    if (fiveHr.resets_at) {
      const now = Math.floor(Date.now() / 1000);
      const remaining = Math.max(0, fiveHr.resets_at - now);
      const h = Math.floor(remaining / 3600);
      const m = Math.floor((remaining % 3600) / 60);
      if (remaining <= 0) {
        timerStr = ` | reset: now`;
      } else if (h > 0) {
        timerStr = ` | reset in ${h}H ${m}M`;
      } else {
        timerStr = ` | reset in ${m}M`;
      }
    }

    return `${color}plan session ${pct}%${RESET}${timerStr}`;
  }
  return '';
}

function main() {
  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { raw += chunk; });
  process.stdin.on('end', () => {
    try {
      const input = JSON.parse(raw);
      const sessionId = input.session_id || 'unknown';
      const model = (input.model && input.model.display_name) || 'claude';
      const remainingPct = input.context_window && input.context_window.remaining_percentage;
      const currentDir = (input.workspace && input.workspace.current_dir) || input.cwd || process.cwd();

      // Context usage
      let usedPct = 0;
      if (remainingPct != null) {
        const usableRemaining = Math.max(0, (remainingPct - AUTOCOMPACT_BUFFER) / (100 - AUTOCOMPACT_BUFFER) * 100);
        usedPct = Math.round(100 - usableRemaining);
      }

      // Bridge file
      writeBridgeFile(sessionId, remainingPct, usedPct);

      // Task
      const task = getCurrentTask(sessionId);

      // Build parts
      const parts = [];
      parts.push(model);
      if (task) parts.push(task);

      const bar = buildProgressBar(usedPct);
      parts.push(`current context ${bar}`);

      // Rate limit (5hr)
      const rateStr = formatRateLimit(input.rate_limits);
      if (rateStr) parts.push(rateStr);

      process.stdout.write(parts.join(' | '));
    } catch {
      process.stdout.write('ctx [--]');
    }
  });
}

main();
