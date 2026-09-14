"""Check the local installation through its real HTTP interface; no business data is created."""
import http.cookiejar
import json
import os
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode, quote, urljoin, urlparse
from urllib.request import HTTPCookieProcessor, Request, build_opener

ROOT = Path(__file__).resolve().parents[1]
# Compose binds IPv4 loopback; avoid an IPv6 localhost retry for every asset on Windows.
BASE = os.environ.get("FRAPPE_BASE_URL", "http://127.0.0.1:8080")
ENV_FILE = Path(os.environ.get("FRAPPE_ENV_FILE", ROOT / ".env"))
config = dict(
    line.split("=", 1) for line in ENV_FILE.read_text(encoding="utf-8-sig").splitlines()
    if line and not line.startswith("#") and "=" in line
)
cookies = http.cookiejar.CookieJar()
client = build_opener(HTTPCookieProcessor(cookies))
results = []


def fetch(path, data=None):
    request = Request(urljoin(BASE, path), data=urlencode(data).encode() if data else None)
    with client.open(request, timeout=120) as response:
        body = response.read()
        return response.status, body, response.headers, response.url


def record(name, **details):
    results.append({"check": name, "passed": True, **details})
    print(f"PASS {name}")


class Assets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        value = attrs.get("src") if tag == "script" else attrs.get("href") if tag == "link" else None
        if value and urlparse(value).path.startswith("/assets/"):
            self.urls.add(value)


status, body, _, _ = fetch("/api/method/ping")
assert json.loads(body)["message"] == "pong"
record("public health endpoint", status=status)

status, body, _, _ = fetch("/api/method/login", {"usr": "Administrator", "pwd": config["ADMIN_PASSWORD"]})
assert json.loads(body)["message"] == "Logged In"
status, body, _, _ = fetch("/api/method/frappe.auth.get_logged_user")
assert json.loads(body)["message"] == "Administrator"
record("Administrator authentication")

for doctype in ["Company", "Employee", "Salary Slip", "CRM Lead", "Loan", "Insights Workbook", "Insights Data Source v3", "HD Ticket", "HD Team", "HD Agent", "TP Call Log"]:
    path = "/api/resource/" + quote(doctype) + "?" + urlencode({"limit_page_length": 1})
    status, body, _, _ = fetch(path)
    assert isinstance(json.loads(body)["data"], list)
    record(f"{doctype} API", status=status)

status, body, _, _ = fetch("/api/method/helpdesk.api.auth.get_user")
helpdesk_user = json.loads(body)["message"]
assert helpdesk_user["user_id"] == "Administrator" and helpdesk_user["has_desk_access"]
record("Helpdesk Administrator access", status=status)

assets = set()
for path in ["/app", "/crm", "/hrms", "/insights", "/helpdesk"]:
    status, body, _, final_url = fetch(path)
    html = body.decode("utf-8")
    assert "Traceback (most recent call last)" not in html
    assert urlparse(final_url).path != "/login", final_url
    parser = Assets()
    parser.feed(html)
    assert parser.urls, f"No built assets found for {path}"
    assets.update(parser.urls)
    record(f"{path} page", status=status, url=final_url, assets=len(parser.urls))

for path in sorted(assets):
    status, body, headers, _ = fetch(path)
    assert len(body) > 0
    assert "text/html" not in headers.get("Content-Type", ""), path
record("compiled browser assets", count=len(assets))

status, body, _, _ = fetch("/socket.io/?EIO=4&transport=polling")
assert body.startswith(b"0{"), body[:100]
assert "sid" in json.loads(body[1:])
record("Socket.IO handshake", status=status)

(ROOT / "logs").mkdir(exist_ok=True)
(ROOT / "logs" / "http-verification.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
print(f"All {len(results)} HTTP checks passed.")
