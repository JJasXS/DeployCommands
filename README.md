# DeployCommands

Double-click Windows deploy scripts for ProAcc projects. Each app folder has:

| File | Source |
|------|--------|
| `deploy-*-github.cmd` | Clones from `https://github.com/JJasXS/<repo>.git` |
| `deploy-*-gitlab.cmd` | Clones from `https://gitlabsvr.oneclickclouds.com/softwaredevelopment/<repo>.git` |
| `validate-env.ps1` | Must sit next to the `.cmd` (Notepad `.env` gate) |

Also: `mirror\push-github-to-gitlab.cmd` mirrors GitHub → GitLab.

## How to run

1. Double-click the `.cmd` (do **not** paste into PowerShell).
2. Click **Yes** on the UAC prompt.
3. Notepad opens first — fill `.env`, **Save**, then **Close**.
4. Deploy continues (clone → publish/install → Windows service).

GitLab scripts use **HTTPS** (port 443). SSH `git@...` (port 22) is often blocked behind Cloudflare.

## Projects

| Folder | Service | Port | Branch | Notes |
|--------|---------|------|--------|-------|
| `ProAccScanner` | `ProAccScanner` | 8443 | `main` | eScan / `FirebirdWeb.exe` |
| `ABS_System` | `ABS_System` | 8080 | `fix-from-old` | e-Booking |
| `ApprovalPO` | `ApprovalPO` | 2095 | `main` | Needs `FIREBIRD_PASSWORD` |
| `eQuotation` | `ProAcc_eQuotation` | 8880 | `main` | Python + NSSM |
| `autoEmailing` | `SQL Accounting Email Worker` | (none) | `main` | Background worker |

## Mirror GitHub → GitLab

```text
mirror\push-github-to-gitlab.cmd
```

Pick one project or **ALL**. Uses `git clone --mirror` + `git push --mirror`.  
**Warning:** `--mirror` makes GitLab an exact copy of GitHub (GitLab-only branches are deleted).

## Required `.env` keys

Most apps:

- `TENANT_CODE`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

ApprovalPO also needs `FIREBIRD_PASSWORD`.  
autoEmailing requires at least `TENANT_CODE` (other keys optional / from `.env.example`).
