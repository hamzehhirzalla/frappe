# Ubuntu / Oracle server deployment

Requires Docker Engine, Docker Compose, Git, and Python 3. Run commands from the
repository root. `manage.sh` detects the Docker daemon's CPU architecture and
uses the same platform for the image build and application containers.
This supports AMD64 and ARM64 without emulation.

## Prepare

Clone this repository, then fetch the pinned upstream build files:

```bash
git clone https://github.com/hamzehhirzalla/frappe.git frappe-main
cd frappe-main
git clone --no-checkout https://github.com/frappe/frappe_docker.git frappe_docker
git -C frappe_docker config core.autocrlf false
git -C frappe_docker checkout a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0
```

Create a private `.env` from `.env.example`. Generate independent random values
for `DB_PASSWORD` and `ADMIN_PASSWORD`; do not commit this file. On Linux set its
permissions to `600`. For direct HTTP access set `HTTP_PUBLISH_PORT=0.0.0.0:80`
and `FRAPPE_SITE_URL=http://YOUR_SERVER_IP`. Allow TCP port 80 in the server's
network rules. Use a TLS reverse proxy and an HTTPS site URL when available.
The internal site name and `FRAPPE_SITE_NAME_HEADER` remain `frappe.localhost`.

## Build and install

```bash
bash manage.sh Build
bash manage.sh Start
bash manage.sh Install
bash manage.sh Restart
FRAPPE_BASE_URL=http://127.0.0.1 bash manage.sh Verify
bash manage.sh Status
```

For a different published port, include it in `FRAPPE_BASE_URL`. `Install` creates
a fresh database with all eight apps. It does not copy data from another server.
Log in as `Administrator` using the generated password and complete the company
setup wizard. Run `bash manage.sh Backup` to export the database, attachments,
and encryption configuration.

## Replacing an existing Docker workload

Record the running container IDs and their Compose project names before stopping
them. `docker stop` preserves containers and volumes. Do not remove volumes or
run a system prune to switch applications. Retain the container list so the old
workload can be restarted if requested.

Apply code changes locally, commit and push them, then use `git pull --ff-only`
on the server after checking that its working tree is clean. Record the deployed
Git commit and image ID with the verification results.
