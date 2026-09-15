# Fresh Ubuntu: install Frappe step by step

This guide starts with a newly installed Ubuntu machine. It installs Docker,
builds this project's image, and creates a fresh site with **Frappe, ERPNext,
HRMS, CRM, Lending, Insights, Helpdesk, and Telephony**.

Follow **steps 1–10** to get a working installation, **step 11** to add a domain
with Cloudflare HTTPS, and **step 12** to save a backup.

Nginx is included in the frontend container. Docker runs the database, Redis,
Python, Node, and application services too; separate host installations of
these components are not needed.

## Before you start

- Use a normal Ubuntu account that can run `sudo`, such as the account created
  during installation. Cloud images often call this account `ubuntu`.
- Use 64-bit Ubuntu on Intel/AMD (`x86_64`) or ARM (`aarch64`, including Oracle
  ARM instances). The scripts select the native architecture automatically.
- Docker currently supports Ubuntu **22.04, 24.04, and 26.04 LTS**.
  See [Docker's Ubuntu requirements](https://docs.docker.com/engine/install/ubuntu/#os-requirements).
- For planning, allow about **4 CPU cores, 16 GB RAM, and at least 50 GB free
  disk space** for this eight-app build. This is a practical starting budget,
  not a measured minimum or a production sizing guarantee.
- The machine needs internet access to download packages and application code.
- For the optional domain setup, you need a public server IP and a domain whose
  DNS is managed by Cloudflare. A machine behind a router also needs incoming
  port 443 forwarded to it; a private LAN address is not a public DNS target.

**Where to run commands:** use the **Ubuntu terminal**, except for SSH/tunnel
and backup-download commands explicitly marked “your computer.” Copy one code
block at a time, including its `EOF` or `PY` closing line. Wait for it to finish.
If it reports an error, resolve that error before the next step.

When `sudo` asks for a password, use your Ubuntu account password. The terminal
does not display characters while you type it. Replace `YOUR_UBUNTU_USER`,
`YOUR_SERVER_IP`, and `erp.example.com` with your own values wherever they appear.
The examples contain no existing server passwords.

## 1. Open Ubuntu and check the machine

On Ubuntu Desktop, open **Terminal** (`Ctrl` + `Alt` + `T`). On Ubuntu Server,
sign in at its console. If SSH is already available, you can connect from
**PowerShell or Terminal on your computer**:

```bash
ssh YOUR_UBUNTU_USER@YOUR_SERVER_IP
```

If your provider requires an SSH key, use
`ssh -i /path/to/your-key YOUR_UBUNTU_USER@YOUR_SERVER_IP` instead.

In the **Ubuntu terminal**, check:

```bash
whoami
cat /etc/os-release
uname -m
free -h
df -h /
sudo -v
```

Check the Ubuntu version, architecture, memory, and the disk's `Avail` column.
If `whoami` says `root`, sign in with your normal sudo-capable Ubuntu account
before continuing.

## 2. Update Ubuntu and install basic tools

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl git python3 nano openssl tmux
```

If you want SSH access and it was not installed, run these at the **Ubuntu console**:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

For a cloud server, allow your SSH port in the provider's network rules. The
default is TCP 22; restrict it to your own IP where practical. If UFW is already
enabled, allow that same SSH port there before connecting remotely.

After system updates, reboot:

```bash
sudo reboot
```

The SSH session disconnects. Wait for Ubuntu to start, then sign in again.

## 3. Install Docker Engine and Docker Compose

Add Docker's package signing key:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add Docker's official Ubuntu repository. Paste this **whole block**:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Install Docker and its Compose/build plugins:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker containerd
sudo docker run --rm hello-world
```

**Expected:** a `Hello from Docker!` message. These commands follow
[Docker's official Ubuntu installation method](https://docs.docker.com/engine/install/ubuntu/#install-using-the-apt-repository).
If you previously installed Docker through Snap or Ubuntu's `docker.io` package,
resolve the package conflicts described there before using this method.

## 4. Allow your Ubuntu account to use Docker

```bash
sudo groupadd --force docker
sudo usermod -aG docker "$USER"
```

**Log out and log in again now.** For SSH, type `exit`, then reconnect. On Ubuntu
Desktop, log out of the desktop account and sign back in; opening another
terminal alone may not refresh your group membership.

Then check, **without `sudo`**:

```bash
docker run --rm hello-world
docker version
docker compose version
docker buildx version
```

These should all succeed. Use `docker compose` with a space. HTTPS requires
**Compose 2.24.4 or newer** because it replaces the HTTP port mapping using
[`!override`](https://docs.docker.com/reference/compose-file/merge/#replace-value).
Newer major versions, including Compose 5, also satisfy this requirement.

The Docker group grants root-level control of this machine; add only trusted
administrators. See [Docker's Linux post-install instructions](https://docs.docker.com/engine/install/linux-postinstall/).

## 5. Download this project and its build files

Run as your normal Ubuntu account:

```bash
cd ~
git clone https://github.com/hamzehhirzalla/frappe.git frappe-main
cd ~/frappe-main
git clone --no-checkout https://github.com/frappe/frappe_docker.git frappe_docker
git -C frappe_docker config core.autocrlf false
git -C frappe_docker checkout a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0
```

Check the downloaded files:

```bash
pwd
ls manage.sh .env.example apps.json frappe_docker/compose.yaml
git -C frappe_docker rev-parse HEAD
```

**Expected:** the directory is your home folder's `frappe-main`, all four files
exist, and the last command prints
`a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0`. Keep the upstream checkout at this
commit; it is the build configuration used by this project.

From now on, run project commands from `~/frappe-main`. If you reconnect later,
first run `cd ~/frappe-main`.

## 6. Create fresh passwords and the private configuration

Paste the whole block below. It creates `.env` from `.env.example`, generates
**two different random passwords**, and restricts the file to your Ubuntu user.
It refuses to overwrite an existing `.env`.

```bash
cd ~/frappe-main
python3 - <<'PY'
import os
import secrets
from pathlib import Path

path = Path('.env')
if path.exists():
    raise SystemExit('.env already exists. Keep it and continue; do not regenerate database credentials.')

text = Path('.env.example').read_text(encoding='utf-8')
text = text.replace('GENERATE_A_RANDOM_DATABASE_PASSWORD', secrets.token_hex(24))
text = text.replace('GENERATE_A_DIFFERENT_ADMINISTRATOR_PASSWORD', secrets.token_hex(24))
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8') as output:
    output.write(text)
print('Created private .env with fresh database and Administrator passwords.')
PY
```

To see **only your new Frappe login password**, run:

```bash
python3 - <<'PY'
from pathlib import Path

for line in Path('.env').read_text(encoding='utf-8').splitlines():
    if line.startswith('ADMIN_PASSWORD='):
        print('Username: Administrator')
        print('Password:', line.split('=', 1)[1])
        break
PY
```

Save this login in your password manager. It differs from your Ubuntu password
and the database password. Keep `.env` private; it is excluded from Git.

The initial settings bind Frappe to **`127.0.0.1:8080` on Ubuntu**. Keep these
defaults for now. Step 10 explains how to open it through SSH; step 11 publishes
HTTPS. Leave the internal site name and
`FRAPPE_SITE_NAME_HEADER=frappe.localhost` unchanged when adding a domain.

## 7. Build the application image

The first build downloads and compiles all eight applications. Allow tens of
minutes; duration depends on CPU, disk, and connection speed.

For an SSH installation, start a persistent terminal so the build can continue
if your connection drops:

```bash
tmux new -s frappe-install
```

This opens another shell on Ubuntu. Inside it, run:

```bash
cd ~/frappe-main
mkdir -p logs
set -o pipefail
bash manage.sh Build < /dev/null 2>&1 | tee logs/build.log
```

Wait for a successful build and the command prompt to return. Confirm the image:

```bash
docker image inspect --format '{{.Id}}' alhorani-frappe:2026-09-14-helpdesk
```

**Expected:** an image ID starting with `sha256:`. A build failure is also saved
in `logs/build.log`; resolve it before starting the containers.

If SSH disconnects, reconnect and run `tmux attach -t frappe-install`. To leave
tmux without stopping it, press `Ctrl` + `B`, release both keys, then press `D`.
Do not start a second build while the first is still running.

## 8. Start the containers and install the site

```bash
cd ~/frappe-main
bash manage.sh Start < /dev/null
bash manage.sh Status
```

**Expected:** the database, Redis, and application containers start.
`configurator` showing `Exited (0)` is normal: it is a one-time configuration
job. Backend/frontend health checks may fail until the site is installed.

Create the fresh database and install all applications:

```bash
mkdir -p logs
set -o pipefail
bash manage.sh Install < /dev/null 2>&1 | tee logs/install.log
```

Wait for installation and database migrations to finish. This creates the
internal site `frappe.localhost` and installs seven additional apps alongside
Frappe. It does not import data from another server. Helpdesk and Telephony are
included automatically.

Check the installed apps:

```bash
bash manage.sh Bench list-apps < /dev/null
```

**Expected:** `frappe`, `erpnext`, `hrms`, `crm`, `lending`, `insights`,
`telephony`, and `helpdesk`.

## 9. Restart and verify the installation

```bash
bash manage.sh Restart < /dev/null
bash manage.sh Status
```

Wait for the backend and frontend to report `healthy`, then run:

```bash
FRAPPE_BASE_URL=http://127.0.0.1:8080 bash manage.sh Verify < /dev/null
```

**Expected:** runtime and Insights checks pass, followed by
`All 21 HTTP checks passed.` This checks login, application APIs, pages, compiled
assets, and the Socket.IO handshake. HTTP results are saved to
`logs/http-verification.json`.

The default stack has **nine running containers**, plus the completed
`configurator`. Some services have no health check; they show `Up` without a
`healthy` label.

## 10. Open Frappe and finish the company setup

### If you are using the Ubuntu machine's own browser

Open **http://localhost:8080**.

### If Ubuntu is a remote server

Open a **second PowerShell/Terminal window on your computer**, and keep this
command running:

```bash
ssh -N -L 127.0.0.1:18080:127.0.0.1:8080 YOUR_UBUNTU_USER@YOUR_SERVER_IP
```

Add `-i /path/to/your-key` if SSH needs a key. The command normally stays open
without printing anything. In your computer's browser, open
**http://localhost:18080**. Closing that SSH window closes the tunnel.

### Sign in

- **Username:** `Administrator` (capital `A`).
- **Password:** the password generated in step 6.
- Complete the company setup wizard with your real company details.

The installation defaults to the Dubai time zone; choose the appropriate country,
time zone, and currency for your company during setup.

Use these paths after the address you opened:

| Application | Path | Example through the SSH tunnel |
| --- | --- | --- |
| ERPNext / main Desk | `/app` | `http://localhost:18080/app` |
| Helpdesk | `/helpdesk` | `http://localhost:18080/helpdesk` |
| CRM | `/crm` | `http://localhost:18080/crm` |
| Insights | `/insights` | `http://localhost:18080/insights` |
| HR portal | `/hrms` | `http://localhost:18080/hrms` |

Complete Helpdesk's introductory setup when you first open it. Email and calling
need your own mailbox/provider configuration later.

**You now have a working installation.** Continue using the SSH tunnel, or follow
step 11 for a public HTTPS domain.

## 11. Optional: publish your domain with Cloudflare HTTPS

This setup exposes **only TCP 443** for Frappe. Public port 80 can stay closed.
Cloudflare redirects HTTP visitors to HTTPS before contacting your server.

### 11.1 Choose the hostname and prepare DNS

In Cloudflare, open your domain. Its zone must be active, with the required
nameservers already set at your registrar.

Under **DNS → Records**, create an **A** record:

| Field | Example value |
| --- | --- |
| Name | `erp` (for `erp.example.com`) |
| IPv4 address | Your new Ubuntu server's public IPv4 address |
| Proxy status | **Proxied**, orange cloud |
| TTL | Auto |

Use an unused hostname if another application already uses the domain. Ensure
there is no conflicting record or stale AAAA record pointing that hostname at
another machine. DNS can be prepared now; the site will work after the remaining
HTTPS steps are complete.

### 11.2 Create an origin certificate

In Cloudflare:

1. Open **SSL/TLS → Origin Server → Create Certificate**.
2. Let Cloudflare generate the private key and CSR; choose **RSA**.
3. Include your exact hostname, such as `erp.example.com`.
4. Choose the validity period and create the certificate.
5. Select **PEM** format. Keep the page open to copy the **Origin Certificate**
   and **Private Key** separately; the private key is displayed only once.

This secures the Cloudflare-to-Ubuntu connection. Cloudflare also needs an active
edge certificate for visitors, shown under **SSL/TLS → Edge Certificates**.
See [Cloudflare Origin CA setup](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/).

### 11.3 Save the certificate on Ubuntu

In the **Ubuntu terminal**:

```bash
sudo install -d -m 700 /etc/ssl/frappe
sudo nano /etc/ssl/frappe/fullchain.pem
```

Paste only the **Origin Certificate**, including its `-----BEGIN CERTIFICATE-----`
and `-----END CERTIFICATE-----` lines. In nano, press `Ctrl` + `O`, then `Enter`
to save, then `Ctrl` + `X` to exit.

Now save the separate **Private Key**, including its BEGIN and END lines:

```bash
sudo nano /etc/ssl/frappe/privkey.pem
```

Save and exit nano the same way. Set permissions and check the files:

```bash
sudo chown 1000:1000 /etc/ssl/frappe/fullchain.pem /etc/ssl/frappe/privkey.pem
sudo chmod 600 /etc/ssl/frappe/fullchain.pem /etc/ssl/frappe/privkey.pem
sudo openssl x509 -in /etc/ssl/frappe/fullchain.pem -noout -dates -ext subjectAltName
sudo openssl pkey -in /etc/ssl/frappe/privkey.pem -check -noout
```

**Expected:** the certificate covers your hostname, its dates are valid, and the
key check succeeds. The frontend container uses numeric user ID **1000**, so
these files must be readable by that ID even if your Ubuntu account has a
different ID. The directory remains accessible only to root; Docker bind-mounts
the two files into the container. Keep the key outside Git.

### 11.4 Open the HTTPS network path

Allow inbound **TCP 443** in the cloud provider's security group/firewall. On
Oracle Cloud, check the instance's subnet security list and any attached network
security groups. Keep your SSH access rule. Behind a router, forward TCP 443 to
the Ubuntu machine too.

If you use UFW on Ubuntu, allow your actual SSH port **before** enabling it, then
allow HTTPS. These commands assume the default SSH port 22:

```bash
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

Docker-published ports can bypass UFW filtering. Use your provider's firewall or
Docker-aware firewall rules to restrict published container ports; do not rely
on UFW alone. This project publishes no database or Redis ports. See
[Docker's firewall notes](https://docs.docker.com/engine/install/ubuntu/#firewall-limitations).

### 11.5 Enable HTTPS in the project

In the **Ubuntu terminal**, replace the example hostname on the second line,
then paste the whole block. It updates only the HTTPS settings and keeps both
generated passwords intact:

```bash
cd ~/frappe-main
export FRAPPE_DOMAIN=erp.example.com
python3 - <<'PY'
import os
import re
from pathlib import Path

domain = os.environ['FRAPPE_DOMAIN'].strip()
if domain == 'erp.example.com' or not re.fullmatch(r'[A-Za-z0-9]+(?:[A-Za-z0-9.-]*[A-Za-z0-9])?', domain):
    raise SystemExit('Set FRAPPE_DOMAIN to your real hostname, without https://, a port, or a path.')
updates = {
    'FRAPPE_TLS_ENABLED': '1',
    'HTTPS_PUBLISH_PORT': '443',
    'FRAPPE_TLS_CERT_FILE': '/etc/ssl/frappe/fullchain.pem',
    'FRAPPE_TLS_KEY_FILE': '/etc/ssl/frappe/privkey.pem',
    'FRAPPE_SITE_URL': 'https://' + domain,
}
path = Path('.env')
lines = path.read_text(encoding='utf-8').splitlines()
lines = [line for line in lines if line.split('=', 1)[0] not in updates]
lines.extend(f'{key}={value}' for key, value in updates.items())
path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
path.chmod(0o600)
print('HTTPS settings saved for https://' + domain)
PY
```

If the script asks for a real hostname, correct `FRAPPE_DOMAIN` and rerun the
block before continuing. Apply the container settings and the site's URL:

```bash
bash manage.sh Start --no-deps backend frontend < /dev/null
bash manage.sh Bench set-config host_name "https://$FRAPPE_DOMAIN" < /dev/null
bash manage.sh Bench clear-cache < /dev/null
bash manage.sh Status
```

If you reconnect between these commands, set `FRAPPE_DOMAIN` again first. The
frontend now publishes **443 only**, replacing the earlier `127.0.0.1:8080`
mapping. The HTTP tunnel from step 10 will no longer serve Frappe. Port 8080
remains in use inside the container for routing and health checks.

### 11.6 Set Cloudflare encryption and HTTP redirects

In Cloudflare:

1. Under **SSL/TLS → Overview**, set the encryption mode to **Full (strict)**.
2. Confirm **SSL/TLS → Edge Certificates** shows an active certificate covering
   your hostname.
3. Under **SSL/TLS → Edge Certificates**, turn **Always Use HTTPS** on.

These zone-level settings affect other hostnames in the same domain. If other
sites need different settings, use a hostname-specific
[SSL configuration rule](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/#update-your-encryption-mode)
and a [Single Redirect](https://developers.cloudflare.com/rules/url-forwarding/single-redirects/)
matching your Frappe hostname and HTTP scheme instead. Preserve the path and
query string in the redirect to HTTPS.

Full (strict) validates your server's certificate. Flexible mode uses HTTP to the
origin and is incompatible with this HTTPS-only configuration. See
[Cloudflare Full (strict)](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/).

**The redirect matters when port 80 is closed:** without it, an HTTP visit may
show error 521 even while the HTTPS URL works. With the redirect, Cloudflare
handles that HTTP request and the browser continues over HTTPS. See
[Always Use HTTPS](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/always-use-https/).

### 11.7 Verify the public site

In the **Ubuntu terminal**, set your real hostname again and run:

```bash
cd ~/frappe-main
export FRAPPE_DOMAIN=erp.example.com
FRAPPE_BASE_URL="https://$FRAPPE_DOMAIN" bash manage.sh Verify < /dev/null
curl -I "http://$FRAPPE_DOMAIN"
```

Replace `erp.example.com` before running. **Expected:**

- Runtime and Insights checks pass, then `All 22 HTTP checks passed.` HTTPS
  verification also checks that the login cookie is marked `Secure`.
- The HTTP request returns a redirect, typically `301` or `308`, with a
  `Location:` pointing to your HTTPS URL.
- Your browser opens `https://YOUR_HOSTNAME` and you can sign in.

Use the same application paths from step 10 with your HTTPS domain.

Keep DNS **proxied**. Cloudflare Origin CA certificates are trusted by Cloudflare;
browsers connecting directly to the server IP do not trust them. They do not use
port 80 for renewal. Record the expiry date and replace the certificate/key
before expiry. See [Origin CA considerations](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/#additional-considerations).

After replacing certificate files later, repeat the permissions in step 11.3,
then recreate the frontend so it mounts the current files:

```bash
bash manage.sh Start --force-recreate --no-deps frontend < /dev/null
```

Wait for it to become healthy and repeat the HTTPS verification above.

## 12. Save your first backup

After completing the company setup:

```bash
cd ~/frappe-main
bash manage.sh Backup < /dev/null
ls -lt backups
```

**Expected:** a new folder such as `backups/20260915-160000`, containing the
database export, public/private file archives, site configuration including the
encryption key, and deployment reference files. Use the actual folder printed
by the command.

Copy that whole folder off Ubuntu. For example, run this on **your computer**,
replacing the timestamp and SSH details:

```bash
scp -r YOUR_UBUNTU_USER@YOUR_SERVER_IP:~/frappe-main/backups/YYYYMMDD-HHMMSS .
```

Keep a private copy of `.env` and, if configured, the TLS certificate/private key
as well; `Backup` does not include those host files. Store backups securely:
the site encryption key is needed to recover saved application credentials.
Back up regularly and before application updates.

## Daily commands

Run these from `~/frappe-main` as needed:

| Task | Command |
| --- | --- |
| Show services | `bash manage.sh Status` |
| Start services | `bash manage.sh Start` |
| Stop services, keeping data | `bash manage.sh Stop` |
| Restart application services | `bash manage.sh Restart` |
| View recent logs | `bash manage.sh Logs` |
| View backend logs | `bash manage.sh Logs backend` |
| Follow frontend logs (`Ctrl+C` to exit) | `bash manage.sh Logs -f frontend` |
| List installed apps | `bash manage.sh Bench list-apps` |
| Create a backup | `bash manage.sh Backup` |
| Verify the initial local HTTP setup | `bash manage.sh Verify` |
| Verify after enabling HTTPS | `FRAPPE_BASE_URL=https://YOUR_HOSTNAME bash manage.sh Verify` |

Docker starts at boot, and running services use `unless-stopped` restart
policies. If you deliberately used `Stop`, use `Start` to bring them back;
rebooting does not undo that deliberate stop. Rebuilding and running the
installer are not needed on every reboot.

Keep `.env` and Docker volumes when maintaining the site. Changing `DB_PASSWORD`
in `.env` does not change the password already stored in MariaDB. Changing
`ADMIN_PASSWORD` there does not reset the existing Frappe login; it is also the
password the verification script uses, so keep it in sync if you change the
Administrator password in Frappe.

For future code updates, make and commit source changes locally, push them to
GitHub, and pull the reviewed commit on Ubuntu with `git pull --ff-only` after
checking `git status --short` is clean. Follow the update's build/migration
instructions and record `git rev-parse HEAD` with your verification results.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Docker `permission denied` | Complete step 4 and fully log out/in. Check `id -nG` includes `docker`. |
| `docker: 'compose' is not a docker command` | Install `docker-compose-plugin` from step 3. Use `docker compose`, with a space. |
| Compose rejects `!override` | Update the Compose plugin; HTTPS requires 2.24.4 or newer. |
| Build runs out of space | Check `df -h /` and `docker system df`; expand disk space before retrying. Avoid deleting application volumes. |
| Build exits with code 137 / process is killed | Check RAM and `sudo journalctl -k -n 100` for an out-of-memory kill; add capacity before rebuilding. |
| `configurator` says `Exited (0)` | Normal: this setup job finishes after writing shared configuration. |
| Backend/frontend unhealthy before installation | Complete step 8, restart, then wait for health checks. If still unhealthy, inspect `bash manage.sh Logs backend frontend`. |
| `localhost:8080` fails on your computer | For remote Ubuntu, use the SSH tunnel and `localhost:18080` from step 10. After TLS is enabled, use the HTTPS domain. |
| Nginx cannot read the certificate | Repeat the ownership/mode commands in step 11.3. The container needs UID 1000 to read both files. |
| Cloudflare 521 / 522 on HTTPS | Check DNS, `bash manage.sh Status`, frontend logs, and inbound TCP 443 in provider and host network rules. |
| HTTPS works but HTTP shows 521 | Complete the redirect in step 11.6; this setup leaves origin port 80 closed. |
| Cloudflare 526 | Check Full (strict) has a valid, unexpired origin certificate covering the requested hostname. |
| Verification gets Cloudflare 403 | Inspect Cloudflare Security Events for the request and review the specific rule that blocked it. |
| Administrator login fails | Retrieve the step 6 password. If changed in Frappe later, use the new password and update `.env` for verification. |

For a quick service and disk report:

```bash
cd ~/frappe-main
bash manage.sh Status
bash manage.sh Logs backend frontend
df -h /
docker system df
```

Do not post `.env`, credentials, private keys, or backup archives in public
troubleshooting reports.
