# SqlAccountSync SDK Live deploy

Double-click:

- `deploy-SqlAccountSync-SDK-github.cmd` (or `-gitlab.cmd`)
- Click **Yes** on UAC

What it does:

1. Opens Notepad for `.env` (`TENANT_CODE`, AWS keys, bootstrap URL, optional `SDK_SECRET_ID`)
2. Checks `SQLAcc.BizApp` COM registration
3. Offers `aws login` if AWS CLI session expired
4. Clones branch **`sdk-conversion`**, publishes self-contained win-x64 to `C:\Apps\SqlAccountSync\publish`
5. Disables the old **SqlAccountSync** Windows service (API mode)
6. Creates scheduled task **SqlAccountSync-SDK** — At log on, highest privileges, restart on failure
7. Starts the task and opens `http://127.0.0.1:5030/`

Prerequisite checklist: see `SqlAccountSync\docs\SDK_SETUP.md`.
