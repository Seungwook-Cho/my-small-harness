#!/usr/bin/env node
// Context Monitor Hook (PostToolUse)
// Reads bridge file and injects warnings when context is running low

const fs = require('fs');
const path = require('path');
const os = require('os');

const WARN_THRESHOLD = 35;    // remaining <= 35% -> WARNING
const CRIT_THRESHOLD = 25;    // remaining <= 25% -> CRITICAL
const DEBOUNCE_INTERVAL = 5;  // warn every N tool uses
const STALE_SECONDS = 60;     // ignore bridge file older than this

function getSeverity(remainingPct) {
  // remainingPct here is the RAW remaining from the API
  // Convert to usable remaining (same formula as statusline)
  const AUTOCOMPACT_BUFFER = 16.5;
  const usableRemaining = Math.max(0, (remainingPct - AUTOCOMPACT_BUFFER) / (100 - AUTOCOMPACT_BUFFER) * 100);

  if (usableRemaining <= CRIT_THRESHOLD) return 'CRITICAL';
  if (usableRemaining <= WARN_THRESHOLD) return 'WARNING';
  return null;
}

function readBridgeFile(sessionId) {
  const bridgePath = path.join(os.tmpdir(), `claude-ctx-${sessionId}.json`);
  try {
    const data = JSON.parse(fs.readFileSync(bridgePath, 'utf8'));
    const now = Math.floor(Date.now() / 1000);
    if (now - data.timestamp > STALE_SECONDS) return null;
    return data;
  } catch {
    return null;
  }
}

function readDebounceState(sessionId) {
  const statePath = path.join(os.tmpdir(), `claude-ctx-${sessionId}-warned.json`);
  try {
    return JSON.parse(fs.readFileSync(statePath, 'utf8'));
  } catch {
    return { tool_use_count: 0, last_severity: null, last_warned_at: -DEBOUNCE_INTERVAL };
  }
}

function writeDebounceState(sessionId, state) {
  const statePath = path.join(os.tmpdir(), `claude-ctx-${sessionId}-warned.json`);
  try {
    fs.writeFileSync(statePath, JSON.stringify(state), 'utf8');
  } catch {
    // silent
  }
}

function buildMessage(severity, usedPct, remainingPct) {
  const AUTOCOMPACT_BUFFER = 16.5;
  const usableRemaining = Math.max(0, (remainingPct - AUTOCOMPACT_BUFFER) / (100 - AUTOCOMPACT_BUFFER) * 100);
  const usableRemainingRound = Math.round(usableRemaining);
  const usedRound = Math.round(100 - usableRemaining);

  if (severity === 'CRITICAL') {
    return `CONTEXT CRITICAL: Usage at ${usedRound}%. Remaining: ${usableRemainingRound}%. Context is nearly exhausted. Inform the user that context is low and ask how they want to proceed.`;
  }
  return `CONTEXT WARNING: Usage at ${usedRound}%. Remaining: ${usableRemainingRound}%. Be aware that context is getting limited. Avoid unnecessary exploration or starting new complex work.`;
}

function main() {
  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { raw += chunk; });
  process.stdin.on('end', () => {
    try {
      const input = JSON.parse(raw);
      const sessionId = input?.session_id;
      if (!sessionId) { process.exit(0); return; }

      const bridge = readBridgeFile(sessionId);
      if (!bridge) { process.exit(0); return; }

      const severity = getSeverity(bridge.remaining_percentage);
      if (!severity) { process.exit(0); return; }

      // Debounce logic
      const state = readDebounceState(sessionId);
      state.tool_use_count += 1;

      const escalated = state.last_severity === 'WARNING' && severity === 'CRITICAL';
      const shouldWarn = escalated || (state.tool_use_count - state.last_warned_at >= DEBOUNCE_INTERVAL);

      if (shouldWarn) {
        state.last_severity = severity;
        state.last_warned_at = state.tool_use_count;
        writeDebounceState(sessionId, state);

        const msg = buildMessage(severity, bridge.used_pct, bridge.remaining_percentage);
        const output = {
          hookSpecificOutput: {
            hookEventName: 'PostToolUse',
            additionalContext: msg
          }
        };
        process.stdout.write(JSON.stringify(output));
      } else {
        state.last_severity = severity;
        writeDebounceState(sessionId, state);
      }
    } catch {
      // silent failure
    }
  });
}

main();
