const path = require('path');
const os = require('os');
const fs = require('fs');
const { spawn } = require('child_process');

const provider = normalizeProvider(process.env.AI_PROVIDER || 'codex');
const model = (process.env.AI_MODEL || '').trim() || (provider === 'claude' ? 'claude-sonnet-4-6' : 'gpt-5.4');
const thinking = provider === 'codex' || /^(1|true|yes|on)$/i.test((process.env.AI_THINKING || '').trim());
const prompt = (process.env.COMMIT_MSG || '').replace(/\\n/g, '\n');
const formatPath = path.join(__dirname, 'format.md');
const formatPrompt = fs.existsSync(formatPath) ? fs.readFileSync(formatPath, 'utf8').trim() : '';
const codexPrompt = formatPrompt ? `${prompt}\n\nEk talimatlar:\n${formatPrompt}` : prompt;

const flog = fs.createWriteStream(path.join(__dirname, 'flog.txt'), { flags: 'w' });
const log = fs.createWriteStream(path.join(__dirname, 'log.txt'), { flags: 'w' });
const claudeDebugPath = path.join(__dirname, 'claude-debug.log');
const claudeMcpPath = path.join(__dirname, 'mcps.json');

function normalizeProvider(value) {
  const normalized = (value || '').trim().toLowerCase();
  if (normalized === 'codex' || normalized === 'claude') {
    return normalized;
  }

  throw new Error(`Desteklenmeyen AI provider: ${value}`);
}

function decodeUnicodeEscapes(text) {
  return text.replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)));
}

function writeLogText(text) {
  if (!text) {
    return;
  }

  log.write(text);
  process.stdout.write(text.endsWith('\n') ? text : `${text}\n`);
}

function copyClaudeDebugLog() {
  if (!fs.existsSync(claudeDebugPath)) {
    return;
  }

  const debugText = fs.readFileSync(claudeDebugPath);
  if (debugText.length) {
    flog.write('\n[claude-debug.log]\n');
    flog.write(debugText);
    if (debugText[debugText.length - 1] !== 10) {
      flog.write('\n');
    }
  }

  fs.unlinkSync(claudeDebugPath);
}

function buildClaudeMcpConfigPath() {
  if (!fs.existsSync(claudeMcpPath)) {
    return '';
  }

  JSON.parse(fs.readFileSync(claudeMcpPath, 'utf8'));
  return claudeMcpPath;
}

function configureCodex() {
  if (!process.env.CODEX_TOKEN) {
    throw new Error('AI_PROVIDER=codex icin CODEX_TOKEN gerekli.');
  }

  const codexDir = path.join(os.homedir(), '.codex');
  if (!fs.existsSync(codexDir)) {
    fs.mkdirSync(codexDir, { recursive: true });
  }

  fs.writeFileSync(
    path.join(codexDir, 'config.toml'),
    `model = "${model}"
model_reasoning_effort = "xhigh"

ask_for_approval = "never"
sandbox = "danger-full-access"

[windows]
sandbox = "elevated"

[projects.'${process.cwd()}']
trust_level = "trusted"`
  );

  fs.writeFileSync(path.join(codexDir, 'auth.json'), process.env.CODEX_TOKEN);
}

function runClaude() {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new Error('AI_PROVIDER=claude icin ANTHROPIC_API_KEY gerekli.');
  }

  return new Promise((resolve, reject) => {
    const mcpConfigPath = buildClaudeMcpConfigPath();
    const args = [
      '-p',
      '--model',
      model,
      '--effort',
      'high',
      '--permission-mode',
      'bypassPermissions',
      '--dangerously-skip-permissions',
    ];

    if (mcpConfigPath) {
      args.push('--mcp-config', mcpConfigPath, '--strict-mcp-config');
    }

    if (formatPrompt) {
      args.push('--append-system-prompt-file', formatPath);
    }

    const child = spawn(
      'claude',
      args,
      {
        cwd: process.cwd(),
        stdio: ['pipe', 'pipe', 'pipe'],
        env: thinking ? {
          ...process.env,
        } : {
          ...process.env,
          CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING: '1',
          MAX_THINKING_TOKENS: '0'
        },
      }
    );

    let stdout = '';

    child.stdout.on('data', (data) => {
      flog.write(data);
      stdout += data.toString();
    });

    child.stdin.end(prompt);

    child.stderr.on('data', (data) => {
      flog.write(data);
      process.stderr.write(data.toString());
    });

    child.on('error', reject);
    child.on('close', (code) => {
      copyClaudeDebugLog();

      if (stdout.trim()) {
        writeLogText(stdout.trim());
      }

      if (code !== 0) {
        reject(new Error(`Claude process exited with code ${code}`));
        return;
      }

      resolve();
    });
  });
}

function runCodex() {
  configureCodex();

  return new Promise((resolve, reject) => {
    const child = spawn(
      'codex',
      ['exec', '--dangerously-bypass-approvals-and-sandbox', '--json', codexPrompt],
      { cwd: process.cwd() }
    );

    let buffer = '';

    child.stdout.on('data', (data) => {
      flog.write(data);
      buffer += data.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop();

      for (const line of lines) {
        if (!line.trim()) {
          continue;
        }

        try {
          const action = JSON.parse(line);
          if (action.item?.type === 'agent_message') {
            writeLogText(decodeUnicodeEscapes(action.item.text));
          }
        } catch (error) {
          flog.write(`\nJSON parse hatasi: ${error.message}\n`);
        }
      }
    });

    child.stderr.on('data', (data) => {
      flog.write(data);
      process.stderr.write(data.toString());
    });

    child.on('error', reject);
    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Codex process exited with code ${code}`));
        return;
      }

      resolve();
    });
  });
}

(async () => {
  if (provider === 'claude') {
    await runClaude();
    return;
  }

  await runCodex();
})()
  .catch((error) => {
    const message = error?.stack || error?.message || String(error);
    flog.write(`${message}\n`);
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  })
  .finally(() => {
    flog.end();
    log.end();
  });
