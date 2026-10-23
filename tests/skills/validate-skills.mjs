#!/usr/bin/env node
// Static checks for the skills library and the plugin manifests that ship it.
//
// Zero dependencies, so it runs anywhere Node runs (CI, Windows, a fresh
// clone). Each rule names the failure it guards against; the report lists
// every violation, then exits 1 if there was any.
//
// Usage: node tests/skills/validate-skills.mjs [REPO_ROOT]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(process.argv[2] ?? path.join(here, '..', '..'));
const skillsDir = path.join(root, 'skills');
const problems = [];
let checks = 0;

const rel = (p) => path.relative(root, p).split(path.sep).join('/');
const report = (rule, where, message) => problems.push(`[${rule}] ${where}: ${message}`);
const readText = (p) => fs.readFileSync(p, 'utf8');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

// Split markdown into lines tagged with whether they sit inside a code fence.
function markdownLines(text) {
  let fence = null;
  return text.split(/\r?\n/).map((line, i) => {
    const m = line.match(/^\s*(`{3,}|~{3,})/);
    let inFence = fence !== null;
    if (m) {
      if (fence === null) {
        fence = m[1][0];
        inFence = true;
      } else if (m[1][0] === fence) {
        fence = null;
        inFence = true;
      }
    }
    return { line, number: i + 1, inFence };
  });
}

function frontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!m) return null;
  const fields = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) fields[kv[1]] = kv[2].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }
  return fields;
}

// --- skill frontmatter -----------------------------------------------------
// The directory name is the skill id every harness registers and every
// `superpowers:<name>` reference uses; a frontmatter name that drifts from it
// registers a second, unreachable id on some harnesses.
const skillNames = fs.readdirSync(skillsDir, { withFileTypes: true })
  .filter((e) => e.isDirectory())
  .map((e) => e.name)
  .sort();

for (const name of skillNames) {
  const file = path.join(skillsDir, name, 'SKILL.md');
  checks++;
  if (!fs.existsSync(file)) {
    report('skill-file', `skills/${name}`, 'directory has no SKILL.md');
    continue;
  }
  const fm = frontmatter(readText(file));
  if (!fm) {
    report('frontmatter', rel(file), 'missing --- frontmatter block');
    continue;
  }
  if (fm.name !== name) report('frontmatter', rel(file), `name "${fm.name}" does not match directory "${name}"`);
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(fm.name ?? '')) report('frontmatter', rel(file), `name "${fm.name}" is not lowercase-hyphenated`);
  if ((fm.name ?? '').length > 64) report('frontmatter', rel(file), 'name is longer than 64 characters');
  if (!fm.description) report('frontmatter', rel(file), 'description is missing or empty');
  else if (fm.description.length > 1024) report('frontmatter', rel(file), `description is ${fm.description.length} characters (limit 1024)`);
}

// --- cross references --------------------------------------------------------
const markdownFiles = walk(skillsDir).filter((p) => p.endsWith('.md'));
const docFiles = [
  path.join(root, 'README.md'),
  path.join(root, 'AGENTS.md'),
  ...walk(path.join(root, 'docs')).filter((p) => p.endsWith('.md') && !/[\\/]docs[\\/](superpowers|plans)[\\/]/.test(p)),
].filter((p) => fs.existsSync(p));

// `superpowers:<skill>` must name a skill that exists. "skill-name" is the
// documented placeholder.
for (const file of [...markdownFiles, ...docFiles]) {
  for (const { line, number } of markdownLines(readText(file))) {
    for (const m of line.matchAll(/superpowers:([a-z0-9-]+)/g)) {
      checks++;
      if (m[1] !== 'skill-name' && !skillNames.includes(m[1])) {
        report('skill-ref', `${rel(file)}:${number}`, `superpowers:${m[1]} names no skill`);
      }
    }
  }
}

// Relative markdown links in skills must resolve. anthropic-best-practices.md
// is a reference copy whose links illustrate a hypothetical skill layout.
const illustrativeLinks = new Set(['skills/writing-skills/anthropic-best-practices.md']);
for (const file of markdownFiles) {
  if (illustrativeLinks.has(rel(file))) continue;
  for (const { line, number, inFence } of markdownLines(readText(file))) {
    if (inFence) continue;
    for (const m of line.matchAll(/\]\(([^)\s]+)\)/g)) {
      const target = m[1].split('#')[0];
      if (!target || /^[a-z]+:/i.test(target)) continue;
      checks++;
      if (!fs.existsSync(path.resolve(path.dirname(file), target))) {
        report('link', `${rel(file)}:${number}`, `link target ${m[1]} does not exist`);
      }
    }
  }
}

// --- helper scripts run from the project worktree (#2525) ---------------------
// The SDD and executing-plans helpers run git and resolve PLAN_FILE in the
// current directory. A bare `scripts/<helper>` (or one relative to another
// skill) only resolves when the agent cds into the plugin's own directory —
// where git then reads the plugin's checkout instead of the project. Every
// mention must therefore be anchored at <skill-dir>.
const gitHelpers = ['sdd-workspace', 'task-brief', 'review-package', 'task-start', 'task-done'];
const helperRe = new RegExp(`(\\S*?)scripts/(${gitHelpers.join('|')})\\b`, 'g');
for (const file of markdownFiles) {
  for (const { line, number } of markdownLines(readText(file))) {
    for (const m of line.matchAll(helperRe)) {
      checks++;
      const prefix = m[1].replace(/^[`(\[]+/, '');
      if (!/^<skill-dir>\/(\.\.\/(subagent-driven-development|executing-plans)\/)?$/.test(prefix)) {
        report('helper-path', `${rel(file)}:${number}`, `"${m[0]}" is not anchored at <skill-dir>/; run helpers by path from the project worktree`);
      }
    }
  }
}

// --- manifests ------------------------------------------------------------------
const jsonFiles = [
  'package.json',
  'gemini-extension.json',
  '.version-bump.json',
  'hooks/hooks.json',
  'hooks/hooks-cursor.json',
  '.agents/plugins/marketplace.json',
  '.antigravity-plugin/plugin.json',
  '.claude-plugin/marketplace.json',
  '.claude-plugin/plugin.json',
  '.codex-plugin/plugin.json',
  '.cursor-plugin/plugin.json',
  '.devin-plugin/plugin.json',
  '.kimi-plugin/plugin.json',
  '.muse-plugin/marketplace.json',
  '.muse-plugin/plugin.json',
];
const manifests = {};
for (const file of jsonFiles) {
  checks++;
  try {
    manifests[file] = JSON.parse(readText(path.join(root, file)));
  } catch (err) {
    report('json', file, err.code === 'ENOENT' ? 'missing' : `invalid JSON: ${err.message}`);
  }
}

// The plugin id is what users install (`superpowers@...`); it never changes.
for (const file of jsonFiles.filter((f) => /plugin\.json$/.test(f) || f === 'gemini-extension.json' || f === 'package.json')) {
  checks++;
  if (manifests[file] && manifests[file].name !== 'superpowers') {
    report('plugin-id', file, `name is "${manifests[file].name}", expected "superpowers"`);
  }
}

// Paths a manifest hands to a harness must exist.
function expectPath(file, value, label) {
  if (typeof value !== 'string' || !value) return;
  checks++;
  if (!fs.existsSync(path.join(root, value))) report('manifest-path', file, `${label} points at missing ${value}`);
}
const m = manifests;
expectPath('package.json', m['package.json']?.main, 'main');
for (const p of m['package.json']?.pi?.extensions ?? []) expectPath('package.json', p, 'pi.extensions');
for (const p of m['package.json']?.pi?.skills ?? []) expectPath('package.json', p, 'pi.skills');
expectPath('gemini-extension.json', m['gemini-extension.json']?.contextFileName, 'contextFileName');
expectPath('.antigravity-plugin/plugin.json', m['.antigravity-plugin/plugin.json']?.logo, 'logo');
expectPath('.codex-plugin/plugin.json', m['.codex-plugin/plugin.json']?.skills, 'skills');
expectPath('.codex-plugin/plugin.json', m['.codex-plugin/plugin.json']?.interface?.composerIcon, 'interface.composerIcon');
expectPath('.codex-plugin/plugin.json', m['.codex-plugin/plugin.json']?.interface?.logo, 'interface.logo');
expectPath('.cursor-plugin/plugin.json', m['.cursor-plugin/plugin.json']?.skills, 'skills');
expectPath('.cursor-plugin/plugin.json', m['.cursor-plugin/plugin.json']?.hooks, 'hooks');
expectPath('.kimi-plugin/plugin.json', m['.kimi-plugin/plugin.json']?.skills, 'skills');
const kimiBootstrap = m['.kimi-plugin/plugin.json']?.sessionStart?.skill;
if (kimiBootstrap) expectPath('.kimi-plugin/plugin.json', `skills/${kimiBootstrap}/SKILL.md`, 'sessionStart.skill');

// Muse lists skills one by one: a new skill directory must be added there.
const museSkills = m['.muse-plugin/plugin.json']?.capabilities?.skills ?? [];
for (const skill of museSkills) expectPath('.muse-plugin/plugin.json', skill.path, `skill ${skill.id}`);
for (const name of skillNames) {
  checks++;
  if (!museSkills.some((s) => s.id === name)) report('muse-skills', '.muse-plugin/plugin.json', `skill ${name} is not listed`);
}

// A bash script handed to `sh` breaks wherever /bin/sh is dash (#2528).
for (const hook of m['.muse-plugin/plugin.json']?.capabilities?.hooks ?? []) {
  const [interpreter, script] = hook.command ?? [];
  if (!script) continue;
  checks++;
  const scriptPath = path.join(root, script);
  if (!fs.existsSync(scriptPath)) {
    report('hook', '.muse-plugin/plugin.json', `hook ${hook.id} runs missing ${script}`);
    continue;
  }
  const shebang = readText(scriptPath).split(/\r?\n/, 1)[0];
  if (/\bbash\b/.test(shebang) && interpreter !== 'bash') {
    report('hook', '.muse-plugin/plugin.json', `hook ${hook.id} runs bash script ${script} with "${interpreter}"`);
  }
}

// Every hook command must reference a script that exists.
for (const file of ['hooks/hooks.json', 'hooks/hooks-cursor.json']) {
  const text = JSON.stringify(m[file] ?? {});
  for (const ref of text.matchAll(/hooks\/(run-hook\.cmd)\\?"?\s+([a-z0-9-]+)/g)) {
    expectPath(file, `hooks/${ref[1]}`, 'hook wrapper');
    expectPath(file, `hooks/${ref[2]}`, 'hook script');
  }
}

// Declared versions stay in sync (what scripts/bump-version.sh --check does,
// without needing jq/yq).
const versions = new Map();
for (const { path: file, field } of m['.version-bump.json']?.files ?? []) {
  checks++;
  let value;
  if (file.endsWith('.json')) {
    value = field.split('.').reduce((obj, key) => obj?.[key], manifests[file] ?? JSON.parse(readText(path.join(root, file))));
  } else {
    const yamlLine = readText(path.join(root, file)).split(/\r?\n/).find((l) => l.startsWith(`${field}:`));
    value = yamlLine?.slice(field.length + 1).trim().replace(/^(["'])(.*)\1$/, '$2');
  }
  versions.set(file, value);
}
if (new Set(versions.values()).size > 1) {
  report('versions', '.version-bump.json', `declared versions drift: ${[...versions].map(([f, v]) => `${f}=${v}`).join(', ')}`);
}

// --- result -----------------------------------------------------------------------
if (problems.length) {
  console.log(problems.join('\n'));
  console.log(`\n${problems.length} problem(s) in ${checks} checks`);
  process.exit(1);
}
console.log(`validate-skills: ${checks} checks passed (${skillNames.length} skills)`);
