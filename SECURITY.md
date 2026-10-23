# Security policy

Cavaleiro Dev Skills ships skills that coding agents follow with access to a
terminal and your files, a SessionStart hook that runs on every session, small
helper scripts, and a local web server (the brainstorming visual companion).
A flaw here runs on many machines, so security reports are taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.** Report privately through GitHub:

1. Go to the repository's **Security** tab.
2. Select **Report a vulnerability** (private vulnerability reporting), or open the form directly at <https://github.com/cavaleiro-ai/cavaleiro-dev-skills/security/advisories/new>.

Include the affected file and line, the harness (Claude Code, Codex, Cursor, OpenCode, and so on) and its version, steps to reproduce, and the impact you expect. Redact secrets, tokens, and private code.

## What is in scope

- **Hooks and plugin entry points** — `hooks/session-start`, `hooks/run-hook.cmd`, the OpenCode, Pi, and Hermes plugins: command injection, unsafe path resolution (for example, picking up a `bash` from the current directory), or output that breaks the harness's JSON contract in an exploitable way.
- **Helper scripts** under `skills/*/scripts/` and `scripts/` — unsafe temporary files, shell injection through plan file names or arguments, writes outside the intended workspace.
- **The visual companion server** (`skills/brainstorming/scripts/server.cjs`) — authentication bypass, binding to non-loopback interfaces without being asked, path traversal, or cross-site issues.
- **Skill instructions** that would lead an agent to leak secrets, run destructive commands, push, publish, or delete work without your human partner's approval, or weaken a safety check — for example, a cleanup step that deletes files git does not track.
- **Fork safety** — anything in this repository that would publish, push, or open pull requests under another project's identity.

## What is out of scope

- Vulnerabilities in the harnesses themselves (Claude Code, Codex, Cursor, OpenCode, and others) or in models. Report those to their vendors.
- Code an agent wrote in your own project while following these skills.

## What to expect

This is a community-maintained project, so timelines are best effort:

- Acknowledgement of your report within **7 days**.
- An initial assessment, and a plan or a request for more information, within **14 days**.
- A fix in `main` and a published advisory crediting you (unless you prefer to stay anonymous) once the issue is resolved.

## Supported versions

Only the latest release and the `main` branch receive security fixes.

## Telemetry note

By default the brainstorming visual companion loads a logo image from the
original authors' website, with the plugin version in the URL. See
[Visual companion telemetry](README.md#visual-companion-telemetry) for what is
sent and how to turn it off.
