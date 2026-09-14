"""Validate the newest exported backup without exposing its contents or credentials."""
import gzip
import argparse
import hashlib
import json
import tarfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("backup", nargs="?", help="Exact backup directory; defaults to the most recently modified export")
args = parser.parse_args()
backup = Path(args.backup).resolve() if args.backup else max(
    (path for path in (root / "backups").iterdir() if path.is_dir()),
    key=lambda path: path.stat().st_mtime,
)
database = next(backup.glob("*-database.sql.gz"))
with gzip.open(database, "rb") as handle:
    sql = handle.read()
for table in [b"tabUser", b"tabCompany", b"tabEmployee", b"tabCRM Lead", b"tabLoan", b"tabInsights Workbook", b"tabHD Ticket", b"tabTP Call Log"]:
    assert b"CREATE TABLE `" + table + b"`" in sql, table
archives = list(backup.glob("*.tar"))
assert len(archives) == 2
for archive in archives:
    with tarfile.open(archive) as handle:
        for member in handle.getmembers():
            if member.isfile():
                with handle.extractfile(member) as item:
                    while item.read(1024 * 1024):
                        pass
config = json.loads((backup / "site_config.json").read_text())
assert config.get("encryption_key") and config.get("db_name") and config.get("db_password")
manifest = {
    path.name: {"size": path.stat().st_size, "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()}
    for path in sorted(backup.iterdir()) if path.is_file() and path.name != "checksums.json"
}
(backup / "checksums.json").write_text(json.dumps(manifest, indent=2))
print(f"PASS backup integrity: {backup.name}; database tables for all apps, both attachment archives, site encryption key, SHA-256 checksums")
