# Fresh installation on Windows Server 2022 or 2025

Use this guide for an **Intel/AMD x64 Windows Server 2022 or 2025** machine.
For Windows 11, follow [SETUP-FROM-SCRATCH.md](SETUP-FROM-SCRATCH.md).

This route installs **Ubuntu 24.04 in WSL 2**, then Docker Engine inside Ubuntu.
Docker Desktop is not supported on Windows Server.
[Docker Windows requirements](https://docs.docker.com/desktop/setup/install/windows-install/#system-requirements).

The result is a new site with Frappe, ERPNext, HRMS, CRM, Lending, Insights,
Helpdesk, and Telephony. No old database or installation is needed.

## 1. Prepare Windows and install WSL

Install Windows updates first. Allow a practical starting budget of **16 GB RAM
and 50 GB free SSD space**, with more space for future records and backups.
Hardware virtualization must be enabled. If the server is itself a virtual
machine, its host/provider must expose nested virtualization for WSL 2.

Open **PowerShell as Administrator on the server**:

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture
wsl --install -d Ubuntu-24.04
```

Restart Windows. In administrator PowerShell:

```powershell
wsl --update
wsl --set-default-version 2
wsl --list --verbose
wsl -d Ubuntu-24.04
```

Ubuntu must show version **2** in the list. If it shows version 1, exit Ubuntu
and run `wsl --set-version Ubuntu-24.04 2` from PowerShell before continuing.

On first launch, Ubuntu asks you to choose a Linux username and password. These
are separate from Windows and from the Frappe Administrator login. Password
typing in Linux may be invisible; type it and press Enter.

Microsoft documents WSL installation on Server 2022/2025, including the required
components, Ubuntu distribution, and reboot, in its
[Windows Server WSL guide](https://learn.microsoft.com/en-us/windows/wsl/install-on-server).

## 2. Install basic tools in Ubuntu

The following blocks are **Bash commands inside Ubuntu**, not PowerShell:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git python3 nano
sudo apt-get install -y systemd systemd-sysv
uname -m
cat /etc/os-release
ps -p 1 -o comm=
```

Confirm `x86_64`, Ubuntu 24.04, and `systemd` respectively. Python here is used
for the supplied verification scripts. The application's own Python and Node
will be installed inside its Docker image.

If process 1 is not `systemd`, open `/etc/wsl.conf` with
`sudo nano /etc/wsl.conf`. Add or update this section, preserving other sections:

```ini
[boot]
systemd=true
```

Exit Ubuntu. Run the following in **PowerShell**, then return to Ubuntu:

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04
```

`wsl --shutdown` stops all WSL distributions; use this during initial setup.
Check `ps -p 1 -o comm=` again. See
[Microsoft's systemd guidance](https://learn.microsoft.com/en-us/windows/wsl/systemd).

## 3. Install Docker Engine inside Ubuntu

In **Ubuntu Bash**, add Docker's official package repository:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker version
sudo docker compose version
sudo docker run --rm hello-world
```

Expect Docker client/server versions, a Compose version, and **Hello from
Docker!**. This follows [Docker's Ubuntu repository installation](https://docs.docker.com/engine/install/ubuntu/).
Keep using `sudo` for Docker commands in this guide.

## 4. Transfer and prepare the deployment folder

Extract the supplied source archive in Windows at
`C:\Projects\alhorani-frappe`. It should contain `apps.json`, `.env.example`,
`manage.sh`, `compose.local.yaml`, and `scripts/`, as listed in [SETUP.md](SETUP.md).

Copy it into your Ubuntu user's filesystem. In **Ubuntu Bash**:

```bash
mkdir -p ~/alhorani-frappe
cp -R /mnt/c/Projects/alhorani-frappe/. ~/alhorani-frappe/
cd ~/alhorani-frappe
ls -la
test -f manage.sh
test -f .env.example
```

Use an empty destination for this new installation. All remaining Bash project
commands run from `~/alhorani-frappe`. Windows paths beginning with `C:\` are
available under `/mnt/c/` inside Ubuntu.

Download the official build source if it was not included:

```bash
if [ ! -d frappe_docker ]; then
  git clone --no-checkout https://github.com/frappe/frappe_docker.git frappe_docker
  git -C frappe_docker config core.autocrlf false
  git -C frappe_docker checkout a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0
fi
test -f frappe_docker/compose.yaml
test -f frappe_docker/images/custom/Containerfile
```

If the folder was supplied, check that its Git commit is the same with
`git -C frappe_docker rev-parse HEAD`. A detached-HEAD message for the pinned
commit is expected.

Normalize transferred shell scripts and create working directories:

```bash
sed -i 's/\r$//' manage.sh scripts/install-site.sh
mkdir -p .local logs backups
```

## 5. Generate new passwords

Run this **Bash** block once. It refuses to overwrite an existing `.env`:

```bash
umask 077
python3 - <<'PY'
import secrets
from pathlib import Path

env_path = Path('.env')
assert not env_path.exists(), '.env already exists; use a clean deployment folder'
database_password = secrets.token_hex(24)
administrator_password = secrets.token_hex(24)
text = Path('.env.example').read_text()
text = text.replace('GENERATE_A_RANDOM_DATABASE_PASSWORD', database_password)
text = text.replace('GENERATE_A_DIFFERENT_ADMINISTRATOR_PASSWORD', administrator_password)
env_path.write_text(text)
env_path.chmod(0o600)
login_path = Path('.local/login.txt')
login_path.write_text('URL: http://localhost:8080\nUsername: Administrator\nPassword: ' + administrator_password + '\n')
login_path.chmod(0o600)
print('Created .env and .local/login.txt with new credentials.')
PY
```

Keep `.env` and `.local/login.txt` private. Leave the image, site header, and
loopback port defaults unchanged during the initial installation.

## 6. Build and install all apps

In **Ubuntu Bash**, run each command after the preceding command succeeds:

```bash
sudo bash manage.sh Build
sudo docker image inspect alhorani-frappe:2026-09-14-helpdesk --format '{{.Id}}'
sudo bash manage.sh Start
sudo bash manage.sh Status
```

The first build downloads dependencies and compiles the application assets;
allow an hour or more for the full first setup depending on the server/network.
Wait for the database to be healthy and `configurator` to show **Exited (0)**.
Frontend/backend health checks can fail until the site has been created.

Now install and restart:

```bash
sudo bash manage.sh Install
sudo bash manage.sh Restart
sudo bash manage.sh Status
```

`Install` creates `frappe.localhost`, installs all eight applications including
Telephony before Helpdesk, applies migrations, and sets the Dubai timezone,
scheduler, encryption key, and Insights permissions. It finishes by listing
the applications.

Expect **nine running services** and the completed configurator. The database,
both Redis services, backend, and frontend should become healthy.

## 7. Verify and log in

In **Ubuntu Bash**:

```bash
sudo bash manage.sh Bench list-apps
sudo bash manage.sh Bench doctor
sudo bash manage.sh Verify
curl --fail http://localhost:8080/api/method/ping
```

Expect eight apps, online workers, a passing verification, and a `pong` response.

Open **http://localhost:8080** in a browser on the Windows server, for example
inside its RDP session. WSL normally forwards Linux localhost services to the
Windows host. See [WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking).
If Windows cannot reach it, first confirm the Bash `curl` check passes and that
WSL localhost forwarding has not been disabled.

Read your generated password privately with `cat .local/login.txt` in Ubuntu.
Log in as **Administrator**, finish the company setup wizard, then open:

- **Helpdesk:** http://localhost:8080/helpdesk
- **CRM:** http://localhost:8080/crm
- **Insights:** http://localhost:8080/insights
- **HR employee portal:** http://localhost:8080/hrms

Helpdesk includes a welcome ticket. Complete its introduction and configure
agents, teams, support hours, and SLAs. Mailboxes and phone providers can be
configured later with your own account details.

## 8. Daily operation and restart behavior

Return to Ubuntu with `wsl -d Ubuntu-24.04` from PowerShell. In Bash:

```bash
cd ~/alhorani-frappe
sudo bash manage.sh Start
sudo bash manage.sh Status
```

To stop while retaining all records:

```bash
sudo bash manage.sh Stop
```

Docker is enabled under systemd, and the project containers use
`unless-stopped`. However, Windows must start this user's WSL distribution.
Systemd services alone do not guarantee that WSL remains running.
[WSL systemd behavior](https://learn.microsoft.com/en-us/windows/wsl/systemd).

For unattended operation after a Windows restart, create a **Task Scheduler**
task on Windows under the **same Windows account that installed Ubuntu**:

1. Choose **Run whether user is logged on or not** and **Run with highest privileges**.
2. Add an **At startup** trigger, delayed by one minute.
3. Set the program to `C:\Windows\System32\wsl.exe`.
4. Set its arguments to the following single line:

```text
-d Ubuntu-24.04 -u root --exec /bin/bash -lc "systemctl start docker && exec sleep infinity"
```

5. Disable **Stop the task if it runs longer than...**. Choose **Do not start a new instance** if already running.
6. Save it with that Windows account's credentials, run the task once, and
   confirm the site opens. Test an actual Windows restart before depending on it.

If you manually ran `Stop`, run `Start` again; the Docker restart policy
respects manually stopped containers. Do not run `wsl --shutdown` during use.

## 9. Back up the new site

In **Ubuntu Bash**:

```bash
cd ~/alhorani-frappe
sudo bash manage.sh Backup
sudo python3 scripts/verify_backup.py
```

Copy the complete newest `backups/<timestamp>` folder to another device.
Keep database, attachments, and `site_config.json` together: the configuration
contains the encryption key needed for stored secrets. The Python check verifies
backup integrity, not a complete restore drill.

## 10. Optional: give users a domain and HTTPS

The setup above is accessible locally on the server. Complete this section if
people need to reach it through a public domain. Use your real name in place of
`erp.example.com`, and point its DNS A record to your Windows server's public IP.
If you have an AAAA record, its IPv6 route must also reach this service; otherwise
remove that unused DNS record. Allow TCP 80 and 443 through any provider/router
firewall to the Windows host.

Install Caddy inside **Ubuntu Bash** using its official repository:

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
```

These commands follow [Caddy's Debian/Ubuntu installation](https://caddyserver.com/docs/install#debian-ubuntu-raspbian).
Edit `/etc/caddy/Caddyfile` with `sudo nano /etc/caddy/Caddyfile`. For a fresh
Caddy installation, replace its example site with:

```caddyfile
erp.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

In Ubuntu:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable --now caddy
sudo systemctl reload caddy
cd ~/alhorani-frappe
sudo bash manage.sh Bench set-config host_name https://erp.example.com
sudo bash manage.sh Bench clear-cache
sudo bash manage.sh Restart
```

Now forward Windows TCP 80/443 to WSL. Run in **PowerShell as Administrator**:

```powershell
$wslAddress = ((wsl -d Ubuntu-24.04 -- hostname -I).Trim() -split '\s+')[0]
if (-not $wslAddress) { throw 'No WSL address found.' }
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=$wslAddress connectport=80
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=443 connectaddress=$wslAddress connectport=443
New-NetFirewallRule -DisplayName 'Al Horani HTTP and HTTPS' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80,443
```

Forwarding follows [Microsoft's WSL LAN networking guidance](https://learn.microsoft.com/en-us/windows/wsl/networking).
The WSL address can change when Windows/WSL restarts: rerun the `$wslAddress`
assignment and the two `netsh` commands afterward. The firewall rule is created
only once. Include that forwarding refresh in your server's startup automation
before treating the public endpoint as unattended.

Open **https://erp.example.com/helpdesk** from another computer. Caddy obtains
and renews a certificate when the public DNS and challenge ports reach it.
See [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https).

Keep Docker's port 8080 on loopback; Caddy is the public entry point. The
internal site remains `frappe.localhost`, selected by the frontend's site header.
After configuring a domain, use `Start` for daily use: rerunning `Install`
reapplies the local `host_name` default, which you would need to set again.

## Troubleshooting

| Problem | Check |
| --- | --- |
| WSL cannot start a virtual machine | Enable virtualization/nested virtualization and restart after installing Windows features. |
| `systemctl` says the system was not booted with systemd | Complete step 2 and restart WSL. |
| Docker permission denied | Use the documented `sudo` commands. |
| `bash\r`, `$'\r'`, or shell syntax errors | Normalize line endings as shown in step 4. |
| Missing Compose file or Containerfile | Download the pinned `frappe_docker` directory in step 4. |
| Image pull denied | Finish `Build` before `Start`; keep the supplied image name and tag. |
| Site is unhealthy on first startup | Complete `Install`, then `Restart`, and allow the health checks to run. |
| Public HTTPS fails after restart | Refresh WSL forwarding, confirm the scheduled task is running, and check DNS/provider firewall. |

In Ubuntu, inspect a service with `sudo bash manage.sh Logs backend` or replace
`backend` with `db`, `configurator`, `queue-long`, or `frontend`.

The fresh application installation was tested in Docker. Windows Server
provisioning, scheduled startup, and your domain configuration must be checked
on your server; they were not executed on a Windows Server host during preparation.
