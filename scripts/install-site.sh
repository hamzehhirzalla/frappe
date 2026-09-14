#!/usr/bin/env bash
set -euo pipefail
site=frappe.localhost
if [ ! -f "sites/$site/site_config.json" ]; then
  bench new-site "$site" --db-root-username root \
    --db-root-password "$DB_PASSWORD" --admin-password "$ADMIN_PASSWORD" \
    --mariadb-user-host-login-scope='%' --install-app erpnext --set-default
fi
bench set-config -g server_script_enabled 1
for app in erpnext hrms crm lending insights telephony helpdesk; do
  if ! bench --site "$site" list-apps --format json | python -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.load(sys.stdin).get("frappe.localhost", []) else 1)' "$app"; then
    bench --site "$site" install-app "$app"
  fi
done
bench --site "$site" migrate
bench --site "$site" set-config host_name http://localhost:8080
bench --site "$site" enable-scheduler
bench --site "$site" clear-cache
bench --site "$site" list-apps
