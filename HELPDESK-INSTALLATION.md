# Helpdesk clean-install validation - 14 September 2026

Helpdesk is included in the fresh-install configuration. **Start your server
installation with [SETUP.md](SETUP.md).**

## What was added

- Helpdesk **v1.30.1** and its required Telephony **0.0.1** dependency.
- Automatic installation of both apps through `Install`, followed by migrations.
- Helpdesk/Telephony checks in runtime, HTTP, and backup verification.
- `manage.sh` for Docker Engine inside Ubuntu/WSL, alongside `manage.ps1` for Docker Desktop.
- Fresh Windows 11 and Windows Server 2022/2025 instructions.

Helpdesk's declared Frappe requirement is `>=15.116.1,<17.0.0`, which includes
this project's Frappe 16.33.1. It declares Telephony as a required app.
[Official Helpdesk requirements](https://github.com/frappe/helpdesk/blob/v1.30.1/pyproject.toml).

Telephony currently uses its upstream `develop` branch because it has no release
tag. The checkout validated here is
`039cf39f245d6818ead03cf94eea6ce7f9c1e1f7`; its branch may advance in future builds.

## What passed

Validation used an isolated Docker project with **new empty database/site
volumes**, not an upgrade of the existing populated site.

| Check | Result |
| --- | --- |
| Application image build | Passed; `alhorani-frappe:2026-09-14-helpdesk` |
| Python dependency compatibility | All 196 installed packages passed |
| Fresh site and app installation | All eight apps installed successfully |
| Container health | Nine services running; all five health checks healthy |
| Configurator | Completed successfully with exit 0 |
| Helpdesk/Telephony source comparison | 346 Python/JSON source files matched the recorded checkouts |
| Administrator authentication | Passed |
| Helpdesk Administrator access API | Passed |
| HTTP verification | All 21 checks passed |
| Browser assets referenced by app pages | 143 assets returned successfully with non-HTML content |
| Socket.IO | Handshake passed |
| Short and long queues | Both completed verification jobs |
| Helpdesk knowledge-base search and ticket defaults | Passed |
| Insights database and permissions | Passed |
| Bash wrapper | Status, repeated Install, Verify, and Backup exercised against the clean stack |
| Exported backup | Database tables for all apps, both attachment archives, encryption key, and checksums passed |

Two health probes arrived while the new database was still creating its built-in
users and produced startup Error Log entries. Their tracebacks were inspected;
they came from `/api/method/ping` during bootstrap. Subsequent health, login,
and application checks passed, with no additional errors in those checks.

The company setup wizard remains for the server owner to complete with their
actual business details. No mailboxes or phone providers were connected.

## Evidence and limits

The working directory retains evidence under `logs/`:

- `build-helpdesk-20260914.log`
- `helpdesk-fresh-install.log`
- `helpdesk-fresh-verification.log`
- `helpdesk-bash-verification.log`
- `helpdesk-source-verification.json`
- `http-verification.json`

The clean-site backup is `backups/20260914-175710`. Logs, backups, test
credentials, and existing business records are excluded from the source ZIP.

The image and fresh application installation were tested using Docker Desktop's
Linux engine. The Bash wrapper was exercised with a Linux Docker CLI container.
Windows Server provisioning, Task Scheduler, public DNS/HTTPS, and a backup
restore drill were not executed. Browser automation was unavailable; UI page and
asset checks used authenticated HTTP rather than visual interaction.

`deployment-info.json` describes the image validated for this source handoff;
`python-packages.lock.txt` is its package snapshot. It does not install anything
on your server until you run the setup steps there.
