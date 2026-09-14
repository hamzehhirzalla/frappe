# Install from scratch on your Windows server

This project includes **Frappe, ERPNext, HRMS, CRM, Lending, Insights, Helpdesk,
and Telephony**. You will build one application image and create a new site.
You do not need an existing installation or backup.

## 1. Check which Windows edition is installed

On the server, open **PowerShell** and run:

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture
```

You can also press **Windows + R**, type `winver`, and press Enter when using a
Windows desktop session.

| What the result says | Follow this guide |
| --- | --- |
| Windows 11 on an Intel/AMD x64 machine | [Windows 11 setup from scratch](SETUP-FROM-SCRATCH.md) |
| Windows Server 2022 or Windows Server 2025 on x64 | [Windows Server setup from scratch](WINDOWS-SERVER-SETUP.md) |
| An older Windows version, Windows ARM, or a different OS | Check that edition's compatibility before running either guide. |

Windows 11 and Windows Server use different Docker installation paths.
**Docker Desktop is not supported on Windows Server.** The Server guide uses
Ubuntu inside WSL 2 and Docker Engine instead.
[Docker's Windows support requirements](https://docs.docker.com/desktop/setup/install/windows-install/#system-requirements).

## 2. Transfer the deployment code

Download the project from
[hamzehhirzalla/frappe on GitHub](https://github.com/hamzehhirzalla/frappe).
Click **Code > Download ZIP**, extract the archive, and copy the contents of
the extracted `frappe-main` folder into `C:\Projects\alhorani-frappe` on the
server. `SETUP.md` and `manage.ps1` should be directly inside that directory.
Downloading the ZIP does not require Git to be installed.

If Git is already installed, you can instead run:

```powershell
git clone https://github.com/hamzehhirzalla/frappe.git C:\Projects\alhorani-frappe
```

You can also transfer the supplied `alhorani-frappe-source.zip` and extract it
there. Both options provide deployment code and guides without credentials or
existing business data. The destination should be a new folder for this fresh
installation.

The required files are:

```text
.env.example
.gitattributes
.gitignore
apps.json
compose.local.yaml
manage.ps1
manage.sh
Start-Frappe.cmd
Stop-Frappe.cmd
source-versions.json
deployment-info.json
python-packages.lock.txt
scripts/
README.md
SETUP.md
SETUP-FROM-SCRATCH.md
WINDOWS-SERVER-SETUP.md
HELPDESK-INSTALLATION.md
```

The guides download `frappe_docker/` at the required commit if it is absent.
The build then downloads the selected application sources. You do not need to
transfer `sources/`, an old `.env`, `.local/`, `backups/`, Docker volumes, or
`client-demo/` for a new installation.

## 3. Follow your selected guide in order

Each guide starts with the prerequisite software, creates new passwords, and
then runs **Build > Start > Install > Restart > Verify**.

Helpdesk and Telephony are part of those steps automatically. After installation,
open **http://localhost:8080/helpdesk** on the server and log in with
`Administrator` and the password you generated.

The default network configuration is local to the server. Use a browser in
your server's desktop/RDP session initially. For a public Windows Server
installation, finish the domain/HTTPS section in its guide.
