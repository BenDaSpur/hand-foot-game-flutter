# Security Policy

## Supported versions

Security fixes are applied to the latest `main` branch and the most recent
published release when practical.

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report security issues privately using one of:

1. **GitHub Security Advisories** — [Report a vulnerability](https://github.com/BenDaSpur/hand-foot-game-flutter/security/advisories/new) on this repository <!-- pragma: allowlist secret -->
2. **Email** — ben@spurlock.app with subject line `[Security] Hand & Foot` <!-- pragma: allowlist secret -->

Include as much detail as you can:

- Description of the issue and impact
- Steps to reproduce
- Affected platforms (web, Android, etc.) and app/version if known
- Suggested fix if you have one

We aim to acknowledge reports within a few days and will keep you updated on
status. Please give us a reasonable window to fix and publish a patch before any
public disclosure.

## Scope notes

This is a public game repository. Typical concerns include auth bypass in
multiplayer, exposure of credentials in client builds, or unsafe handling of
game-state import/export. Please do **not** commit or paste real Firebase keys,
service accounts, or `.env` files in issues or pull requests.
