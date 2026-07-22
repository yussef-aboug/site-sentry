#!/usr/bin/env node
// SiteSentry guard -- PreToolUse hook for Bash commands.
//
// Deterministic tripwire: blocks catastrophic commands even if the model is
// confused or manipulated by injected instructions. Exit code 2 = block the
// tool call and surface stderr to the agent. Last line of defense, not a
// substitute for the runbooks.
//
// Written in Node (not bash) on purpose: Claude Code bundles Node, so this
// fires identically on Windows, macOS, and Linux. A bash hook silently no-ops
// on Windows (no interpreter), disabling the tripwire exactly where you cannot
// see it. Do NOT convert this back to a .sh file.
'use strict';

var fs = require('fs');

// Read ALL of stdin synchronously and robustly. A naive readFileSync(0) throws
// EAGAIN when stdin is a non-blocking pipe (intermittent, platform-dependent),
// which would make the guard fail OPEN. Loop over readSync, retrying EAGAIN,
// until EOF -- so we always see the full command before deciding.
function readStdin() {
  var chunks = [];
  var buf = Buffer.alloc(65536);
  while (true) {
    var n;
    try {
      n = fs.readSync(0, buf, 0, buf.length, null);
    } catch (e) {
      if (e.code === 'EAGAIN') { continue; }   // data not ready yet -> retry
      if (e.code === 'EOF') { break; }          // Windows can signal EOF here
      break;                                    // any other error: stop reading
    }
    if (n === 0) break;                          // clean EOF
    chunks.push(Buffer.from(buf.slice(0, n)));
  }
  return Buffer.concat(chunks).toString('utf8');
}

var input = readStdin();

var cmd = '';
try {
  var data = JSON.parse(input);
  cmd = (data && data.tool_input && data.tool_input.command) || '';
} catch (e) {
  cmd = input; // fall back to raw payload if it is not valid JSON
}

if (!cmd) process.exit(0);

// Forbidden patterns (case-insensitive), matched against the FULL command
// string so they catch it even when wrapped in a stdin pipe, e.g.
// printf 'cd x && wp db reset --yes\nexit\n' | ssh alias
var patterns = [
  /rm\s+-[a-z]*r[a-z]*f/i,                            // recursive force delete
  /wp\s+db\s+reset/i,                                 // wipe all tables
  /wp\s+db\s+drop/i,                                  // drop the database
  /wp\s+db\s+clean/i,
  /wp\s+site\s+empty/i,                               // delete all content
  /drop\s+(database|table)/i,                         // raw SQL drops
  /truncate\s+table/i,
  /wp\s+post\s+delete\b[\s\S]*--force[\s\S]*--all/i,  // bulk post delete
  /wp\s+post\s+delete\b[\s\S]*--all[\s\S]*--force/i,
  /mkfs/i,                                            // format a filesystem
  /\bdd\s+if=/i,                                      // raw disk writes
  /:\(\)\s*\{[\s\S]*\}\s*;\s*:/,                      // fork bomb
  /chmod\s+-R\s+777/i,                                // world-writable everything
  />\s*wp-config\.php/i,                               // overwrite site config
  /wp\s+user\s+delete\b[\s\S]*--all/i                 // delete all users
];

for (var i = 0; i < patterns.length; i++) {
  if (patterns[i].test(cmd)) {
    process.stderr.write(
      'BLOCKED by SiteSentry guard: command matches forbidden pattern (' + patterns[i] + ').\n' +
      'If this is genuinely needed, the human operator must run it manually.\n'
    );
    process.exit(2);
  }
}

process.exit(0);
