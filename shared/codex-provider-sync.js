#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

function exists(file) {
  try { return fs.existsSync(file); } catch { return false; }
}

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function timestamp() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return [
    now.getFullYear(),
    pad(now.getMonth() + 1),
    pad(now.getDate()),
    pad(now.getHours()),
    pad(now.getMinutes()),
    pad(now.getSeconds()),
  ].join('');
}

function parseTomlString(text, key) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = text.match(new RegExp(`^\\s*${escaped}\\s*=\\s*"((?:\\\\.|[^"])*)"`, 'm'));
  if (!match) return '';
  return match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}

function readProvider(codexHome) {
  const configFile = path.join(codexHome, 'config.toml');
  const text = fs.readFileSync(configFile, 'utf8');
  return parseTomlString(text, 'model_provider') || 'custom';
}

function walkSessionFiles(root) {
  const files = [];
  if (!exists(root)) return files;
  const stack = [root];
  while (stack.length) {
    const current = stack.pop();
    let entries = [];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const target = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(target);
      else if (entry.isFile() && (/^rollout-.*\.jsonl$/.test(entry.name) || /\.json$/.test(entry.name))) files.push(target);
    }
  }
  return files.sort();
}

function relativeBackupName(codexHome, file) {
  return path.relative(codexHome, file).split(path.sep).join('__');
}

function copyIfExists(file, destDir, label, manifest, dryRun) {
  if (!exists(file)) return;
  const backupPath = path.join(destDir, label);
  manifest.files.push({ target: file, backup: backupPath });
  if (!dryRun) {
    mkdirp(path.dirname(backupPath));
    fs.copyFileSync(file, backupPath);
    try { fs.chmodSync(backupPath, 0o600); } catch {}
  }
}

function createBackup(codexHome, changedSessionFiles, sqliteFiles, dryRun) {
  const id = timestamp();
  const dir = path.join(codexHome, 'backups_state', 'provider-sync', id);
  const manifest = {
    id,
    createdAt: new Date().toISOString(),
    changedSessionFiles: changedSessionFiles.length,
    sqliteFiles: sqliteFiles.length,
    files: [],
  };

  if (!dryRun) mkdirp(dir);
  copyIfExists(path.join(codexHome, 'config.toml'), dir, 'config.toml', manifest, dryRun);

  for (const file of sqliteFiles) {
    const relative = relativeBackupName(codexHome, file);
    copyIfExists(file, dir, path.join('sqlite', relative), manifest, dryRun);
    copyIfExists(`${file}-wal`, dir, path.join('sqlite', `${relative}-wal`), manifest, dryRun);
    copyIfExists(`${file}-shm`, dir, path.join('sqlite', `${relative}-shm`), manifest, dryRun);
  }

  for (const file of changedSessionFiles) {
    const backupPath = path.join(dir, 'sessions', relativeBackupName(codexHome, file));
    manifest.files.push({ target: file, backup: backupPath });
    if (!dryRun) {
      mkdirp(path.dirname(backupPath));
      fs.copyFileSync(file, backupPath);
      try { fs.chmodSync(backupPath, 0o600); } catch {}
    }
  }

  if (!dryRun) {
    fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n', { mode: 0o600 });
  }
  return { id, dir, manifest };
}

function updateProviderFields(value, provider) {
  if (!value || typeof value !== 'object') return 0;
  let changed = 0;
  if (Object.prototype.hasOwnProperty.call(value, 'model_provider') && value.model_provider !== provider) {
    value.model_provider = provider;
    changed += 1;
  }
  for (const item of Object.values(value)) {
    changed += updateProviderFields(item, provider);
  }
  return changed;
}

function preserveLineEnding(text) {
  if (text.endsWith('\r\n')) return '\r\n';
  if (text.endsWith('\n')) return '\n';
  return '';
}

function planJsonlChange(file, text, provider) {
  const lineEnding = preserveLineEnding(text);
  const body = lineEnding ? text.slice(0, -lineEnding.length) : text;
  const lines = body.split(/\r?\n/);
  let changedFields = 0;
  let changedLines = 0;
  const nextLines = lines.map((line) => {
    if (!line) return line;
    let item;
    try {
      item = JSON.parse(line);
    } catch {
      return line;
    }
    const fieldCount = updateProviderFields(item, provider);
    if (!fieldCount) return line;
    changedFields += fieldCount;
    changedLines += 1;
    return JSON.stringify(item);
  });
  if (!changedFields) return null;
  return {
    file,
    changedFields,
    changedLines,
    nextText: `${nextLines.join('\n')}${lineEnding}`,
  };
}

function planJsonChange(file, text, provider) {
  let item;
  try {
    item = JSON.parse(text);
  } catch {
    return null;
  }
  const changedFields = updateProviderFields(item, provider);
  if (!changedFields) return null;
  const lineEnding = preserveLineEnding(text) || '\n';
  return {
    file,
    changedFields,
    changedLines: 1,
    nextText: `${JSON.stringify(item, null, 2)}${lineEnding}`,
  };
}

function plannedSessionChanges(codexHome, provider) {
  const roots = [
    path.join(codexHome, 'sessions'),
    path.join(codexHome, 'archived_sessions'),
  ];
  const changes = [];
  for (const file of roots.flatMap(walkSessionFiles)) {
    let text = '';
    try { text = fs.readFileSync(file, 'utf8'); } catch { continue; }
    if (!text) continue;
    const change = file.endsWith('.jsonl')
      ? planJsonlChange(file, text, provider)
      : planJsonChange(file, text, provider);
    if (change) changes.push(change);
  }
  return changes;
}

function applySessionChanges(changes, dryRun) {
  for (const change of changes) {
    if (dryRun) continue;
    let mode;
    try { mode = fs.statSync(change.file).mode; } catch { mode = undefined; }
    const tmp = `${change.file}.tmp.${process.pid}`;
    fs.writeFileSync(tmp, change.nextText, 'utf8');
    if (mode) {
      try { fs.chmodSync(tmp, mode); } catch {}
    }
    fs.renameSync(tmp, change.file);
  }
}

function escapeSql(value) {
  return String(value).replace(/'/g, "''");
}

function quoteSqlIdentifier(value) {
  return `"${String(value).replace(/"/g, '""')}"`;
}

function findSqliteFiles(codexHome) {
  const files = [];
  const seen = new Set();
  const add = (file) => {
    if (!/\.(sqlite|sqlite3|db)$/.test(file)) return;
    if (seen.has(file)) return;
    seen.add(file);
    files.push(file);
  };
  const scanDir = (dir) => {
    let entries = [];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const target = path.join(dir, entry.name);
      if (entry.isFile()) add(target);
    }
  };
  scanDir(codexHome);
  scanDir(path.join(codexHome, 'sqlite'));
  return files.sort();
}

function sqliteAvailable(logger) {
  const probe = spawnSync('sqlite3', ['--version'], { encoding: 'utf8' });
  if (probe.error && probe.error.code === 'ENOENT') {
    logger.warn('sqlite3 not found; skipped SQLite provider sync');
    return false;
  }
  return true;
}

function planSqliteChanges(codexHome, provider, logger) {
  if (!sqliteAvailable(logger)) return { status: 'skipped', changed: 0, files: [], updates: [] };
  const updates = [];
  let changed = 0;
  for (const dbFile of findSqliteFiles(codexHome)) {
    const tableResult = spawnSync('sqlite3', [
      dbFile,
      "SELECT DISTINCT m.name FROM sqlite_master AS m JOIN pragma_table_info(m.name) AS p WHERE m.type='table' AND p.name='model_provider';",
    ], { encoding: 'utf8' });
    if (tableResult.status !== 0) {
      logger.warn(`${path.basename(dbFile)} is unavailable or locked; skipped SQLite provider sync for this file`);
      continue;
    }
    const tables = String(tableResult.stdout).split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    for (const table of tables) {
      const tableName = quoteSqlIdentifier(table);
      const countSql = `SELECT COUNT(*) FROM ${tableName} WHERE COALESCE(model_provider, '') <> '${escapeSql(provider)}';`;
      const countResult = spawnSync('sqlite3', [dbFile, countSql], { encoding: 'utf8' });
      if (countResult.status !== 0) {
        logger.warn(`${path.basename(dbFile)} is unavailable or locked; skipped SQLite provider sync for table ${table}`);
        continue;
      }
      const rowCount = Number(String(countResult.stdout).trim() || 0);
      if (!rowCount) continue;
      updates.push({ dbFile, table, changed: rowCount });
      changed += rowCount;
    }
  }
  return {
    status: 'ok',
    changed,
    files: [...new Set(updates.map((item) => item.dbFile))],
    updates,
  };
}

function applySqliteChanges(plan, provider, dryRun, logger) {
  if (dryRun || !plan.updates?.length) return { status: plan.status, changed: plan.changed };
  let changed = 0;
  for (const update of plan.updates) {
    const tableName = quoteSqlIdentifier(update.table);
    const sql = `UPDATE ${tableName} SET model_provider = '${escapeSql(provider)}' WHERE COALESCE(model_provider, '') <> '${escapeSql(provider)}';`;
    const result = spawnSync('sqlite3', [update.dbFile, sql], { encoding: 'utf8' });
    if (result.status !== 0) {
      logger.warn(`${path.basename(update.dbFile)} is unavailable or locked; skipped SQLite provider sync for table ${update.table}`);
      continue;
    }
    changed += update.changed;
  }
  return { status: plan.status, changed };
}

function defaultLogger(quiet = false) {
  return {
    info: (message) => { if (!quiet) console.log(`[INFO] ${message}`); },
    ok: (message) => { if (!quiet) console.log(`[OK] ${message}`); },
    warn: (message) => { if (!quiet) console.warn(`[WARN] ${message}`); },
  };
}

function syncProviderHistory(options = {}) {
  const codexHome = options.codexHome || process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
  const dryRun = Boolean(options.dryRun);
  const logger = options.logger || defaultLogger(Boolean(options.quiet));
  const configFile = path.join(codexHome, 'config.toml');

  if (!exists(configFile) && !options.provider) {
    logger.warn(`Codex config not found; skipped provider history sync: ${configFile}`);
    return { provider: '', rolloutChanged: 0, sqliteChanged: 0, backupDir: '' };
  }

  const provider = options.provider || readProvider(codexHome);
  const changes = plannedSessionChanges(codexHome, provider);
  const sqlitePlan = planSqliteChanges(codexHome, provider, logger);
  const shouldBackup = changes.length > 0 || sqlitePlan.files.length > 0;
  const backup = shouldBackup ? createBackup(codexHome, changes.map((item) => item.file), sqlitePlan.files, dryRun) : null;

  applySessionChanges(changes, dryRun);
  const sqlite = applySqliteChanges(sqlitePlan, provider, dryRun, logger);

  const action = dryRun ? 'would sync' : 'synced';
  const changedFields = changes.reduce((total, item) => total + item.changedFields, 0);
  logger.ok(`${action} provider history to "${provider}": session_files=${changes.length}, session_fields=${changedFields}, sqlite=${sqlite.changed}`);
  if (backup) {
    logger.info(`${dryRun ? 'Would create' : 'Created'} provider-sync backup: ${backup.dir}`);
  }

  return {
    provider,
    rolloutChanged: changes.length,
    sessionFilesChanged: changes.length,
    sessionFieldsChanged: changedFields,
    sqliteChanged: sqlite.changed,
    sqliteStatus: sqlite.status,
    backupDir: backup ? backup.dir : '',
  };
}

function parseArgs(argv) {
  const args = { codexHome: '', dryRun: false, json: false, quiet: false, provider: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    if (item === '--codex-home') { args.codexHome = argv[++i] || ''; continue; }
    if (item === '--provider') { args.provider = argv[++i] || ''; continue; }
    if (item === '--dry-run') { args.dryRun = true; continue; }
    if (item === '--json') { args.json = true; continue; }
    if (item === '--quiet') { args.quiet = true; continue; }
    if (item === '-h' || item === '--help') {
      console.log('Usage: node shared/codex-provider-sync.js [--codex-home DIR] [--provider NAME] [--dry-run] [--json]');
      process.exit(0);
    }
    throw new Error(`Unknown option: ${item}`);
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const result = syncProviderHistory({
    codexHome: args.codexHome || undefined,
    provider: args.provider || undefined,
    dryRun: args.dryRun,
    quiet: args.json || args.quiet,
  });
  if (args.json) console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`[WARN] Provider history sync skipped: ${err.message}`);
    process.exit(0);
  }
}

module.exports = { syncProviderHistory };
