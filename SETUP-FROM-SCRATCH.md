# Run this project on a fresh Windows PC

This guide assumes Windows is installed, but no development tools are installed.
It uses the PowerShell and Docker deployment supplied with this project. Follow
the numbered steps in order to run Frappe, ERPNext, HRMS, CRM, Lending, and
Insights, Helpdesk, and its Telephony dependency at **http://localhost:8080**.

The instructions target a **Windows 11 PC with an Intel or AMD x64 processor**,
matching this project's `linux/amd64` image. They are not Mac, Linux, or Windows
ARM instructions. The setup is for local use on your PC.

**This installs a new, empty site with Helpdesk included automatically.**
No existing installation or database backup is required. If the operating system
is Windows Server 2022/2025, use [WINDOWS-SERVER-SETUP.md](WINDOWS-SERVER-SETUP.md)
instead; Docker Desktop is not supported on Windows Server. If you are unsure,
start with [SETUP.md](SETUP.md).

## 1. Prepare the PC

You need an Internet connection, permission to enable Windows features, and a
browser such as the built-in Microsoft Edge.

- Install Windows updates and restart first. Use a Windows release currently
  supported by Docker Desktop.
- Check **Settings > System > About > System type** for an x64-based processor.
- Open **Task Manager > Performance > CPU** and check that **Virtualization** is
  enabled. If disabled, enable Intel VT-x or AMD SVM in your PC's BIOS/UEFI using
  the manufacturer's instructions.
- Docker lists **8 GB RAM** and **WSL 2.1.5 or later** among its WSL requirements.
  See the [current Docker Windows requirements](https://docs.docker.com/desktop/setup/install/windows-install/#system-requirements).

For this eight-application build, allow **16 GB RAM or more and around 50 GB of
free SSD space** as a practical starting budget, not a measured minimum. Builds,
Docker storage, attachments, and backups need additional room as you use the site.
Allow an hour or more for the first installation; download and build times vary.

All command blocks below use **Windows PowerShell**. Run one block at a time.
If a command fails, resolve it before continuing.

## 2. Install WSL 2 and Ubuntu Linux

Open Start, search for **Windows PowerShell**, right-click it, and choose
**Run as administrator**. Run:

```powershell
wsl --install
```

This installs WSL 2 and Ubuntu Linux. Restart Windows when it completes, then
open **Ubuntu** from Start and follow the prompts to create your Linux username
and password. Open an administrator PowerShell again:

```powershell
wsl --update
wsl --set-default-version 2
wsl --version
```

The version command should display WSL and kernel versions.
See [Microsoft's WSL command reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands).

If `--install` is not recognized, finish Windows updates and consult
[Microsoft's WSL installation instructions](https://learn.microsoft.com/en-us/windows/wsl/install).

## 3. Install and start Docker Desktop

1. Open the [official Docker Desktop Windows download page](https://docs.docker.com/desktop/setup/install/windows-install/).
2. Download the Windows **x86_64** installer and run it.
3. Choose the **WSL 2** backend when offered, and finish the installer.
4. Restart if requested, then open **Docker Desktop** from Start and complete
   its first-run prompts.
5. In Docker Desktop settings, confirm **Use the WSL 2 based engine** is enabled.
   Wait until the Docker engine is running. Keep Docker Desktop running while
   using this project.

Close any old terminals. Open a new, ordinary **Windows PowerShell** window and
run:

```powershell
docker --version
docker compose version
docker version
docker info --format '{{.OSType}}'
docker run --rm hello-world
```

Expected results:

- Docker and Compose print version numbers.
- `docker version` shows both **Client** and **Server** information.
- The OS type is **linux**. If it is `windows`, switch Docker Desktop to Linux
  containers and retry.
- The last command prints **Hello from Docker!** after downloading its test image.

Docker Desktop supplies Docker Compose; no separate Compose installer is needed.
See [Docker Desktop](https://docs.docker.com/desktop/).

## 4. Install Git and Python on Windows

### Git

Download and run the **x64 Setup** installer from
[Git for Windows](https://git-scm.com/install/windows). If asked about PATH,
choose **Git from the command line and also from 3rd-party software**.

### Python

Download a stable **Python 3.14 Windows installer (64-bit)** from
[Python's Windows downloads](https://www.python.org/downloads/windows/).
Use the normal installer, not the embeddable package. Enable **Add python.exe
to PATH**, then install. See [Python's Windows installation documentation](https://docs.python.org/3.14/using/windows.html).

Close and reopen PowerShell after both installations:

```powershell
git --version
python --version
python -c "import sys; print(sys.executable)"
```

The last two commands must run Python, not open the Microsoft Store.

Windows Python is used by `manage.ps1 Verify` and the backup integrity checker.
Those scripts use the Python standard library, so there is no host-side
`pip install` step. The application runs with a separate Python inside Docker.
Docker also installs Node.js, Yarn, Bench, MariaDB, Redis, and application
dependencies; you do not install those individually on Windows.

## 5. Get the project files and open its folder

Copy or extract the supplied **whole project folder** onto the new PC. For
example, place it at `C:\Projects\alhorani-frappe`. Do not run it from inside a
ZIP archive. This guide does not assume a public Git URL for this project.

For a clean installation, transfer the deployment files below. `.env`, `.local`,
`logs`, and `backups` are machine/private files rather than prerequisites for a
new empty site. Existing data and credentials are not needed for this fresh installation.

```text
alhorani-frappe/
  .env.example
  apps.json
  compose.local.yaml
  manage.ps1
  Start-Frappe.cmd
  Stop-Frappe.cmd
  source-versions.json
  deployment-info.json
  python-packages.lock.txt
  scripts/
    install-site.sh
    configure_site.py
    verify_runtime.py
    verify_insights.py
    verify_http.py
    verify_backup.py
  frappe_docker/             supplied or downloaded in step 6
```

Optional local `sources/` checkouts are excluded from the repository. The image
build downloads the application code itself from the refs in `manage.ps1` and
`apps.json`.

Open ordinary PowerShell and enter your actual project path:

```powershell
Set-Location -LiteralPath 'C:\Projects\alhorani-frappe'
Get-ChildItem -Force
Test-Path .\manage.ps1
Test-Path .\.env.example
```

Both checks should return `True`.

Use **your chosen folder** for the rest of the guide. Whenever you open a new
PowerShell window, return to that folder first. Windows already includes
PowerShell; installing PowerShell 7 or a code editor is optional.

## 6. Obtain the pinned Docker build files

The project's `.gitignore` excludes `frappe_docker/`. A Git checkout or a small
source-only archive may therefore be missing it. If it is missing, run this
block from the project folder:

```powershell
if (-not (Test-Path -LiteralPath '.\frappe_docker')) {
    git clone --no-checkout https://github.com/frappe/frappe_docker.git frappe_docker
    if ($LASTEXITCODE -ne 0) { throw 'Docker source download failed.' }
    git -C frappe_docker config core.autocrlf false
    git -C frappe_docker checkout a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0
    if ($LASTEXITCODE -ne 0) { throw 'Pinned Docker source checkout failed.' }
}
Test-Path .\frappe_docker\compose.yaml
Test-Path .\frappe_docker\images\custom\Containerfile
```

Both path checks must return `True`. A Git message about a **detached HEAD** is
normal because this uses an exact commit. If the supplied folder has Git
metadata, check it with:

```powershell
git -C frappe_docker rev-parse HEAD
git -C frappe_docker status --short
```

Expected commit: `a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0`. The status should
be empty for an unchanged checkout. If you received a ZIP without Git metadata,
use the deployment files supplied for that commit. Resolve missing files or a
different revision before building; do not substitute the upstream `pwd.yml`
quick demo for this project's configuration.

## 7. Create local credentials and working folders

**Run credential generation only for a new installation.** If this PC already
has this site's Docker volumes, keep its existing `.env` and go to step 8.
Changing `DB_PASSWORD` in a file does not change an existing MariaDB password.

First create the working directories, including `logs`, which the verifier
expects to exist:

```powershell
New-Item -ItemType Directory -Path '.local', 'logs', 'backups' -Force | Out-Null
```

For a fresh site with no `.env`, paste this entire block. It creates two
different random passwords without printing them:

```powershell
if (Test-Path -LiteralPath '.env') {
    throw '.env already exists. Keep it if intentional; do not regenerate credentials for existing data.'
}

function New-SetupPassword {
    $passwordBytes = New-Object byte[] 24
    $passwordGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $passwordGenerator.GetBytes($passwordBytes) }
    finally { $passwordGenerator.Dispose() }
    return [BitConverter]::ToString($passwordBytes).Replace('-', '')
}

$databasePassword = New-SetupPassword
$administratorPassword = New-SetupPassword
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
$envText = [System.IO.File]::ReadAllText((Join-Path $PWD '.env.example'))
$envText = $envText.Replace('GENERATE_A_RANDOM_DATABASE_PASSWORD', $databasePassword)
$envText = $envText.Replace('GENERATE_A_DIFFERENT_ADMINISTRATOR_PASSWORD', $administratorPassword)
[System.IO.File]::WriteAllText((Join-Path $PWD '.env'), $envText, $utf8WithoutBom)
$loginText = "URL: http://localhost:8080`r`nUsername: Administrator`r`nPassword: $administratorPassword`r`n"
[System.IO.File]::WriteAllText((Join-Path $PWD '.local\login.txt'), $loginText, $utf8WithoutBom)
Remove-Variable databasePassword, administratorPassword, envText, loginText
```

If an intentional `.env` was supplied with your installation, use those
credentials instead and skip the generation block. For an empty new machine,
you can put the supplied file aside manually before generating fresh credentials.

The generated values contain only letters and digits, avoiding quoting and
variable-expansion problems in `.env`. Keep these files private. When editing
`.env`, preserve its exact filename; it must not become `.env.txt`.

Keep these deployment values from `.env.example`:

```dotenv
CUSTOM_IMAGE=alhorani-frappe
CUSTOM_TAG=2026-09-14-helpdesk
HTTP_PUBLISH_PORT=127.0.0.1:8080
FRAPPE_SITE_NAME_HEADER=frappe.localhost
```

The image name and tag must match the hardcoded build command in `manage.ps1`.
The port and site name also appear in installation and verification scripts.

Finally, ensure the shell installation script has Linux line endings. This
matters if the project was checked out with Windows line-ending conversion:

```powershell
$installScriptPath = Join-Path $PWD 'scripts\install-site.sh'
$installScriptText = [System.IO.File]::ReadAllText($installScriptPath).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($installScriptPath, $installScriptText, (New-Object System.Text.UTF8Encoding($false)))
```

## 8. Build the application image

Keep Docker Desktop running and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Build
```

This is the longest step. It downloads the build dependencies and applications,
installs them, compiles browser assets, and creates the local image
`alhorani-frappe:2026-09-14-helpdesk`. Leave the terminal open until it finishes.

The selected application releases are:

| Application | Release |
| --- | --- |
| Frappe | v16.33.1 |
| ERPNext | v16.34.2 |
| HRMS | v16.18.1 |
| CRM | v1.83.0 |
| Lending | v16.5.0 |
| Insights | v3.13.2 |
| Helpdesk | v1.30.1 |
| Telephony (Helpdesk dependency) | 0.0.1, `develop` snapshot |

Helpdesk requires Telephony, so both are installed. Telephony has no upstream
release tag; its `develop` branch is selected and the installed commit is
recorded in `source-versions.json`. The recorded snapshot is
`039cf39f245d6818ead03cf94eea6ce7f9c1e1f7`. Future builds may fetch a newer
Telephony commit; retain the image to preserve this exact installation.

The container build uses Python 3.14 and Node 24. MariaDB 11.8 and Redis 8.6
are separate services selected by the Compose files. These are the project's
configured versions, not instructions to install the latest upstream apps.

Confirm the image exists:

```powershell
docker image inspect alhorani-frappe:2026-09-14-helpdesk --format '{{.Id}}'
```

It should print a `sha256:...` image ID. If the build was interrupted, fix the
reported issue and repeat `Build`; Docker can reuse completed build layers.

## 9. Start the services and install the site

Start the database, Redis, and application containers:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Status
```

On the first run, Docker also downloads MariaDB and Redis. Wait until `db` is
healthy and `configurator` shows **Exited (0)**. The configurator is a one-time
setup service, so that exit is expected. Repeat `Status` as needed.

**Before the site exists, frontend/backend health checks may fail.** This is
expected at this stage; do not wait for those two to become healthy before
running `Install`.

Create the site and install its applications:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Install
```

This creates `frappe.localhost`, installs missing apps (including Telephony
before Helpdesk), runs database migrations, enables the scheduler
and server scripts, initializes the encryption key, sets `Asia/Dubai`, and
configures Insights permissions. Wait for it to finish and print the installed
apps. It preserves an existing site when rerun, while reapplying those runtime
defaults.

Then restart the application services:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Restart
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Status
```

Allow a few minutes for health checks. Expect nine running services: `db`,
`redis-cache`, `redis-queue`, `backend`, `frontend`, `websocket`, `queue-short`,
`queue-long`, and `scheduler`. The database, both Redis services, backend, and
frontend should report healthy. `configurator` remains **Exited (0)**.

## 10. Open the website and log in

Open **http://localhost:8080** in your browser. No hosts-file or DNS change is
needed: the frontend maps requests to the internal site `frappe.localhost`.

- **Username:** `Administrator`
- **Password:** the value created in `.local\login.txt`, also stored as
  `ADMIN_PASSWORD` in `.env`.

Open your local password note with:

```powershell
notepad .\.local\login.txt
```

If you kept a supplied `.env` and have no login note, open `.env` privately in
Notepad and use its `ADMIN_PASSWORD` value. There is no universal default
password for this setup.

For a fresh empty site, complete the company setup wizard with your company
name, country, currency, timezone, and other requested details. The new site includes Helpdesk's sample welcome ticket, but not the old
Al Horani demonstration database.

After setup, use the app switcher or these addresses:

| Area | Address |
| --- | --- |
| Main site / Desk | http://localhost:8080 |
| CRM | http://localhost:8080/crm |
| Insights | http://localhost:8080/insights |
| Helpdesk | http://localhost:8080/helpdesk |
| HR employee portal | http://localhost:8080/hrms |

ERPNext, HR administration, payroll, and Lending workspaces are available in
Desk. An Administrator login does not itself create employees or employee
portal records.

For Helpdesk, open **http://localhost:8080/helpdesk** with the same Administrator
login and complete its introductory setup. Configure your support agents, teams,
business hours, and service-level agreements. The installer creates a welcome
ticket and default settings, and sets the shared customer portal defaults to
`HD Customer` and `/helpdesk`. Email and calling/SMS require your own mailbox or
provider configuration; Telephony is installed as a dependency even without a
phone account. See the [Helpdesk installation reference](https://github.com/frappe/helpdesk/tree/v1.30.1).

## 11. Verify the installation

From the project folder, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Bench list-apps
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Bench doctor
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Verify
```

Check that all eight applications appear, workers are online, the scheduler is
enabled, and verification finishes without an exception. Verification checks
application schemas, real jobs in both queues, Insights connectivity,
Administrator login, Helpdesk access and APIs, HTTP pages, static assets, and Socket.IO. Its HTTP results
are written to `logs\http-verification.json`.

For a quick browser-independent health check:

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/api/method/ping'
```

The response should contain `message` with value `pong`.

The HTTP verifier logs in with `ADMIN_PASSWORD` from `.env`. If you later
change the Administrator password in the application, update the local
`ADMIN_PASSWORD` and login note to match. Editing `.env` alone does **not**
change a password on an existing site.

## 12. Daily use and backups

After the first successful installation, open Docker Desktop, wait for its
engine, and double-click **Start-Frappe.cmd**. It starts the existing services
and opens your browser. If the page opens before the services are ready, wait
and refresh.

Alternatively, use PowerShell from the project folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Status
```

When finished, double-click **Stop-Frappe.cmd**, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Stop
```

`Stop` preserves your data. You do not repeat `Build` or `Install` for daily use.
Start Docker Desktop again after a PC restart, then use `Start` if needed.

Create a backup after initial setup and regularly after entering data:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Backup
python .\scripts\verify_backup.py
```

`Backup` exports the database, public and private attachments, site/common
configuration, and version records into `backups\<timestamp>`. The second
command checks the newest backup and writes its checksum manifest. That
integrity check is not a full restore test.

Copy the entire timestamped backup folder to another device. Keep
`site_config.json` with the database: its encryption key is needed to read
stored encrypted secrets.

Live data lives in Docker volumes prefixed `alhorani-frappe_`. Copying this
project folder alone does not copy those volumes. Avoid `docker compose down
-v`, Docker volume deletion, and Docker Desktop factory reset when preserving
your installation.

## 13. Troubleshooting

| Symptom | What to do |
| --- | --- |
| `docker` or `git` is not recognized | Close and reopen PowerShell after installation. Confirm the installer added the program to PATH. |
| Docker reports a connection/pipe/engine error | Open Docker Desktop and wait for the Linux engine. Run `docker version` again. |
| Docker reports virtualization or WSL errors | Check Task Manager virtualization, restart after enabling Windows features, and run `wsl --update`. |
| A Compose file or `Containerfile` is missing | Return to the project folder and complete step 6. |
| `pull access denied for alhorani-frappe` | Complete `Build` before `Start`. Confirm the local image exists and `.env` uses the matching image name/tag. |
| Build is killed or reports insufficient space | Free disk space or increase available Docker/WSL memory, then rerun `Build`. |
| Downloads fail or time out | Check Internet, VPN, proxy, and Docker network settings. Resolve the network error and retry the same step. |
| `$'\r': command not found`, `bash\r`, or invalid shell options | Complete the line-ending normalization in step 7. Docker resource scripts also need LF endings; the clone in step 6 disables conversion. |
| `configurator` shows `Exited (0)` | This is expected; it runs once to configure the shared site settings. |
| Browser shows 404/502 before installation | Complete `Install`, then `Restart`, and wait for healthy frontend/backend services. |
| Python opens the Store or is not found | Repair/reinstall Python with PATH enabled and reopen PowerShell. If the Store alias shadows Python, adjust it in Windows **Manage app execution aliases**. |
| Verification cannot write `logs/http-verification.json` | Create the `logs` directory as shown in step 7. |
| Verification login fails but browser login works | Match `.env`'s `ADMIN_PASSWORD` to the actual current Administrator password. |
| MariaDB access denied after editing `.env` | Restore the original `DB_PASSWORD` for those existing volumes. File edits do not rotate database passwords. |
| Demo links are missing on a new site | A fresh `Install` contains no old Al Horani demo records; those links belong to the separate populated demonstration. |
| Editing `sources/` has no visible effect | Running containers use code packaged in the image. The current build downloads upstream refs; it does not build from local source edits. |

If port 8080 is already in use, identify the process:

```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Look up that process ID in Task Manager and close or reconfigure the conflicting
application. Keep 8080 for this guide: changing only `.env` would leave the
hardcoded URLs in installation, verification, shortcuts, and demo links out of
sync. If Docker reports an existing `alhorani-frappe` installation, inspect it
with `Status` instead of initializing over its data.

To inspect failures, run the relevant log command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Logs backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Logs configurator
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Logs db
powershell -NoProfile -ExecutionPolicy Bypass -File .\manage.ps1 Logs queue-short
```

If Windows blocks a downloaded project script, unblock the trusted supplied
script and retry the documented command:

```powershell
Unblock-File -LiteralPath .\manage.ps1
```

The guide's `-ExecutionPolicy Bypass` flag applies to the launched PowerShell
process; it does not require a permanent machine-wide policy change.

## Completion checklist

- [ ] Docker Desktop's Linux engine starts successfully.
- [ ] The local application image exists.
- [ ] All nine ongoing services are running and the five health checks pass.
- [ ] All eight apps appear in `Bench list-apps`.
- [ ] Administrator login works at http://localhost:8080.
- [ ] The company wizard is completed and Helpdesk opens.
- [ ] `manage.ps1 Verify` passes.
- [ ] A complete backup is saved and copied off the PC.

Prepared against this project's deployment files and the linked official
installation documentation on **14 September 2026**. Clean-install validation is recorded in [HELPDESK-INSTALLATION.md](HELPDESK-INSTALLATION.md).
You still run the installation steps on your own server.
