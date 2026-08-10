# DeployCommands

Double-click Windows deploy scripts for ProAcc projects. Each app folder has:

| File | Source |
|------|--------|
| `deploy-*-github.cmd` | Clones from `https://github.com/JJasXS/<repo>.git` |
| `deploy-*-gitlab.cmd` | Clones from `https://gitlabsvr.oneclickclouds.com/softwaredevelopment/<repo>.git` |
| `validate-env.ps1` | Must sit next to the `.cmd` (Notepad `.env` gate) |

## How to run

1. Double-click the `.cmd` (do **not** paste into PowerShell).
2. Click **Yes** on the UAC prompt.
3. Notepad opens first — fill `.env`, **Save**, then **Close**.
4. Deploy continues (clone → publish/install → Windows service).

GitLab scripts use **HTTPS** (port 443). SSH `git@...` (port 22) is often blocked behind Cloudflare.

## Client deploy notes

- Keep `validate-env.ps1` in the **same folder** as the `.cmd` you run.
- The PC needs network access and git HTTPS auth for the chosen remote (GitHub or GitLab). Use a cached credential, PAT, or signed-in Git Credential Manager.
- .NET apps auto-install Git + the required SDK via winget when missing, and publish **self-contained** win-x64.
- **eQuotation** auto-installs Git, Python 3.11, and NSSM via winget when missing (if winget fails for NSSM, install it manually and ensure `nssm` is on PATH).
- **ABS_System** deploys branch `fix-from-old` (not `main`).

## Projects

| Folder | Service | Port | Branch | Notes |
|--------|---------|------|--------|-------|
| `ProAccScanner` | `ProAccScanner` | 8443 | `main` | eScan / `FirebirdWeb.exe` |
| `ABS_System` | `ABS_System` | 8080 | `fix-from-old` | e-Booking |
| `ApprovalPO` | `ApprovalPO` | 2095 | `main` | Needs `FIREBIRD_PASSWORD` |
| `eQuotation` | `ProAcc_eQuotation` | 8880 | `main` | Python + NSSM |
| `autoEmailing` | `SQL Accounting Email Worker` | (none) | `main` | Background worker |

## Mirror GitHub → GitLab

One folder per project under `mirror\`:

```text
mirror\ProAccScanner\push-github-to-gitlab.cmd
mirror\autoEmailing\push-github-to-gitlab.cmd
mirror\ABS_System\push-github-to-gitlab.cmd
mirror\eQuotation\push-github-to-gitlab.cmd
mirror\ApprovalPO\push-github-to-gitlab.cmd
mirror\push-all-github-to-gitlab.cmd
```

Double-click a project script, or `push-all-github-to-gitlab.cmd` for every repo.  
Uses `git clone --mirror` + `git push --mirror`.  
**Warning:** `--mirror` makes GitLab an exact copy of GitHub (GitLab-only branches are deleted).

## Required `.env` keys

Most apps:

- `TENANT_CODE`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

ApprovalPO also needs `FIREBIRD_PASSWORD`.  
autoEmailing requires at least `TENANT_CODE` (other keys optional).
