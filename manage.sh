#!/usr/bin/env bash
# Docker Engine / WSL Ubuntu equivalent of manage.ps1.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
project_root="$PWD"
project_name="${FRAPPE_PROJECT_NAME:-alhorani-frappe}"
env_file="${FRAPPE_ENV_FILE:-$project_root/.env}"
# Match the Docker daemon, including ARM64 Oracle instances.
export DOCKER_DEFAULT_PLATFORM="${DOCKER_DEFAULT_PLATFORM:-$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')}"
action="${1:-Status}"
if (( $# )); then shift; fi
compose=(docker compose --project-name "$project_name" --project-directory "$project_root"
  --env-file "$env_file"
  -f frappe_docker/compose.yaml
  -f frappe_docker/overrides/compose.mariadb.yaml
  -f frappe_docker/overrides/compose.redis.yaml
  -f frappe_docker/overrides/compose.noproxy.yaml
  -f compose.local.yaml)

# Opt into a server certificate without changing local HTTP installations.
tls_enabled="${FRAPPE_TLS_ENABLED:-}"
if [[ -z "$tls_enabled" && -f "$env_file" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    case "$line" in FRAPPE_TLS_ENABLED=*) tls_enabled="${line#*=}" ;; esac
  done < "$env_file"
fi
if [[ "$tls_enabled" == 1 ]]; then
  compose+=(-f compose.tls.yaml)
fi

case "${action,,}" in
  build)
    apps_hash="$(sha256sum apps.json | cut -d ' ' -f 1)"
    docker build --platform "$DOCKER_DEFAULT_PLATFORM" --progress plain \
      --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
      --build-arg FRAPPE_BRANCH=v16.33.1 \
      --build-arg PYTHON_VERSION=3.14 --build-arg NODE_VERSION=24 \
      --build-arg "CACHE_BUST=${apps_hash^^}" \
      --secret id=apps_json,src=apps.json \
      --tag alhorani-frappe:2026-09-14-helpdesk \
      --file frappe_docker/images/custom/Containerfile frappe_docker
    ;;
  start) "${compose[@]}" up -d "$@" ;;
  stop) "${compose[@]}" stop ;;
  restart) "${compose[@]}" restart backend frontend websocket queue-short queue-long scheduler ;;
  status) "${compose[@]}" ps -a ;;
  logs) "${compose[@]}" logs --tail 100 "$@" ;;
  bench) "${compose[@]}" exec -T backend bench --site frappe.localhost "$@" ;;
  install)
    # Read only the two plain generated values; do not execute .env as shell code.
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      case "$line" in
        DB_PASSWORD=*) export DB_PASSWORD="${line#*=}" ;;
        ADMIN_PASSWORD=*) export ADMIN_PASSWORD="${line#*=}" ;;
        FRAPPE_SITE_URL=*) export FRAPPE_SITE_URL="${line#*=}" ;;
      esac
    done < "$env_file"
    : "${DB_PASSWORD:?DB_PASSWORD is missing from .env}"
    : "${ADMIN_PASSWORD:?ADMIN_PASSWORD is missing from .env}"
    trap 'unset DB_PASSWORD ADMIN_PASSWORD' EXIT
    "${compose[@]}" cp scripts/install-site.sh backend:/tmp/install-frappe-site.sh
    "${compose[@]}" exec -T -e DB_PASSWORD -e ADMIN_PASSWORD -e FRAPPE_SITE_URL backend bash /tmp/install-frappe-site.sh
    "${compose[@]}" cp scripts/configure_site.py backend:/tmp/configure-frappe-site.py
    "${compose[@]}" exec -T backend env/bin/python /tmp/configure-frappe-site.py
    ;;
  backup)
    timestamp="$(date +%Y%m%d-%H%M%S)"
    container_backup="/tmp/frappe-backup-$timestamp"
    destination="$project_root/backups/$timestamp"
    "${compose[@]}" exec -T backend bench --site frappe.localhost backup --with-files --backup-path "$container_backup"
    mkdir -p -- "$destination"
    "${compose[@]}" cp "backend:$container_backup/." "$destination"
    "${compose[@]}" cp backend:/home/frappe/frappe-bench/sites/frappe.localhost/site_config.json "$destination/site_config.json"
    "${compose[@]}" cp backend:/home/frappe/frappe-bench/sites/common_site_config.json "$destination/common_site_config.json"
    cp -- apps.json source-versions.json deployment-info.json python-packages.lock.txt "$destination/"
    chmod -R go-rwx -- "$destination"
    printf 'Backup saved to %s\n' "$destination"
    ;;
  verify)
    "${compose[@]}" cp scripts/verify_runtime.py backend:/tmp/verify-frappe-runtime.py
    "${compose[@]}" exec -T backend env/bin/python /tmp/verify-frappe-runtime.py
    "${compose[@]}" cp scripts/verify_insights.py backend:/tmp/verify-frappe-insights.py
    "${compose[@]}" exec -T backend env/bin/python /tmp/verify-frappe-insights.py
    export FRAPPE_ENV_FILE="$env_file"
    python3 -u scripts/verify_http.py
    ;;
  *) printf 'Usage: bash manage.sh {Build|Start|Stop|Restart|Status|Logs|Bench|Install|Backup|Verify} [arguments]\n' >&2; exit 2 ;;
esac
