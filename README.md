# Al Horani Frappe - fresh installation

**Start with [SETUP.md](SETUP.md).** It explains how to identify the server's
Windows edition and choose the correct from-scratch installation guide.
No existing Frappe installation, database, or old credentials are required.

Helpdesk and its required Telephony dependency are included automatically in
the first image build and site installation.

## Included applications

| Application | Release / source |
| --- | --- |
| Frappe | v16.33.1 |
| ERPNext | v16.34.2 |
| HRMS | v16.18.1 |
| CRM | v1.83.0 |
| Lending | v16.5.0 |
| Insights | v3.13.2 |
| Helpdesk | v1.30.1 |
| Telephony (Helpdesk dependency) | 0.0.1, `develop` snapshot |

The image uses Python 3.14 and Node 24, with MariaDB 11.8 and Redis 8.6 in
separate containers. Application refs are in `apps.json` and `manage.ps1` /
`manage.sh`. Source commits are recorded in `source-versions.json`.

Telephony has no upstream release tag. Its selected `develop` branch may change
between builds; the recorded snapshot is
`039cf39f245d6818ead03cf94eea6ce7f9c1e1f7`. Retain the built image if you need
that exact snapshot. The image tag is `alhorani-frappe:2026-09-14-helpdesk`.

## Installation guides

- [Start here: identify Windows edition and transfer the files](SETUP.md)
- [Windows 11: install WSL, Docker Desktop, and the project](SETUP-FROM-SCRATCH.md)
- [Windows Server 2022/2025: install WSL Ubuntu and Docker Engine](WINDOWS-SERVER-SETUP.md)
- [Helpdesk clean-install verification](HELPDESK-INSTALLATION.md)

The first three project operations are **Build**, **Start**, and **Install**,
followed by **Restart** and **Verify**. The guides include prerequisite software,
credential generation, commands, expected results, and troubleshooting.

`Install` creates the new site, installs all eight apps in dependency order,
and applies their database migrations. Helpdesk does not need a separate
manual download or install command.

## Open the apps

After installation, open these URLs on the machine running the stack:

| Area | URL |
| --- | --- |
| Main site / Desk | http://localhost:8080 |
| Helpdesk | http://localhost:8080/helpdesk |
| CRM | http://localhost:8080/crm |
| Insights | http://localhost:8080/insights |
| HR employee portal | http://localhost:8080/hrms |

Use `Administrator` and the password generated during setup. Finish the company
wizard, then open Helpdesk and complete its introductory setup. Configure your
agents, teams, support hours, and service-level agreements there.

Helpdesk creates a sample welcome ticket and default settings. Its installer
sets the shared customer portal defaults to `HD Customer` and `/helpdesk`.
Staff can continue to use Desk and the other app routes.

Email and calling/SMS require your own mailbox or provider account configuration.
The Telephony dependency is installed even when you only use support tickets.

The default URL is accessible on the host machine. `localhost` on another
computer refers to that other computer; it is not your server's address. The
Windows Server guide includes an optional domain/HTTPS configuration.

## Code, data, and daily use

- `manage.ps1`: Windows PowerShell commands with Docker Desktop.
- `manage.sh`: Bash commands with Docker Engine, including Ubuntu in WSL.
- `frappe_docker/`: official build files, downloaded at the exact commit in the guides.
- `sources/`: optional source checkouts for reading; builds fetch the configured upstream refs.
- `.env`: generated credentials and Compose settings. Keep this private.
- Docker volumes: the database, site files, and queue persistence.
- `backups/`: database, attachments, and configuration exported by `Backup`.

Use `Start` and `Stop` for daily operation. `Stop` retains data. Use `Backup`
regularly and copy the complete export off the server, including
`site_config.json` and its encryption key. Never delete Docker volumes to stop
the application.

Editing `sources/` does not change the running image or the current build input.
Custom source changes need their own repository/ref and a rebuilt image.

Local demonstration files, exported backups, credentials, and runtime logs are
excluded from this repository. A fresh installation creates a new database.

## Official references

- [Helpdesk compatibility and installation](https://github.com/frappe/helpdesk/tree/v1.30.1)
- [Helpdesk's Frappe and Telephony requirements](https://github.com/frappe/helpdesk/blob/v1.30.1/pyproject.toml)
- [Frappe Docker source used by this project](https://github.com/frappe/frappe_docker/tree/a0c52135d4d41c4b8acf7adfdfc5bbcba46dd4d0)
