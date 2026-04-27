# msi-jinni-dist

Public distribution channel for **MSI AI Jinni**.

## Purpose

This repository is a write-only distribution endpoint. It hosts the Windows desktop installer artifacts (`win-unpacked/` zip + `docker-compose.yml`) that the MSI Jinni Launcher downloads on end-user machines.

- **No source code lives here.** Source repos: [`Anro-Lab/MSI-Jinni-Launcher`](https://github.com/Anro-Lab/MSI-Jinni-Launcher) (Go launcher), `Anro-Lab/MSI-Jinni-AI-Desktop` (Electron desktop, private).
- **Anonymous read** is allowed — end users do not need GitHub credentials.
- **Issues are disabled here.** Report problems to the launcher repo:
  https://github.com/Anro-Lab/MSI-Jinni-Launcher/issues

## Release Flow

```
AI-Desktop CI (build win-unpacked + docker-compose)
   └─> push DRAFT release to this repo via PAT
   └─> POST repository_dispatch (event_type=audit_release, client_payload.tag=vX.Y.Z)
                          │
                          ▼
   .github/workflows/audit-and-publish.yml
       1. Guard: refuse if audit-self-test is in alarm state
       2. Download draft asset
       3. Run audit gate
       4. PASS  -> gh release edit --draft=false (publish)
          FAIL  -> gh release delete --cleanup-tag + open issue + Discord alert
```

Stale drafts (>24h, never published) are cleaned by `stale-draft-cleanup.yml` daily.

## Audit Gate Summary

| Check | Tool | Failure mode |
|-------|------|--------------|
| Secret scan | gitleaks (`audit-rules/gitleaks.toml`) + trufflehog (verified only) | Any hit -> FAIL |
| Service-account JSON | Custom regex `"type"\s*:\s*"service_account"` + `*-firebase-adminsdk-*.json` | Hit -> FAIL |
| Forbidden paths | `audit-rules/forbidden-paths.txt` (`*.ts`, `*.env`, `src/`, `*.pem`, `*.key`, `tsconfig.json`, `.git/`) | Hit -> FAIL |
| Size policy | `audit-rules/size-policy.yml` (warn >=50%, fail >=100% delta vs previous release; first release skipped) | >=100% -> FAIL |
| Integrity | Must contain `win-unpacked/` and `docker-compose.yml` | Missing -> FAIL |

The audit workflow is itself protected by a daily metamorphic self-test (`audit-self-test.yml`) that runs the gate against fixed clean / dirty fixtures. If a known-dirty fixture ever passes, the repo enters an **alarm state** and `audit-and-publish` refuses to publish anything until fixed.

## Version Mapping

For any tag `vX.Y.Z`:
- AI-Desktop source tag: `Anro-Lab/MSI-Jinni-AI-Desktop@vX.Y.Z`
- Dist artifact: this repo's release `vX.Y.Z`
- Launcher embedded default manifest points to the latest known-good release here.

## Policies

- **No source code.** PRs adding `.go`, `.ts`, `.tsx`, `.py`, `.js`, or any `src/` content will be rejected.
- **No issues.** Issues are filed in the launcher repo (link above).
- **Direct push to `main` is blocked.** Branch protection requires PR + review.
- **Releases are created exclusively via the AI-Desktop CI PAT bot.** Manual release creation by humans is disallowed by policy.

## Self-hosted Runner

All workflows run on the 5060 self-hosted runner (label `[self-hosted, Linux, X64]`). If the runner is not visible to this repo, an org admin must enable the org-level runner group for `Anro-Lab/msi-jinni-dist` via Settings -> Actions -> Runner groups.
