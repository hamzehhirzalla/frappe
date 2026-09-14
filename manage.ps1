[CmdletBinding()]
param(
    [ValidateSet('Build', 'Start', 'Stop', 'Restart', 'Status', 'Logs', 'Bench', 'Install', 'Backup', 'Verify')]
    [string]$Action = 'Status',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$projectName = if ($env:FRAPPE_PROJECT_NAME) { $env:FRAPPE_PROJECT_NAME } else { 'alhorani-frappe' }
$envFile = if ($env:FRAPPE_ENV_FILE) { $env:FRAPPE_ENV_FILE } else { Join-Path $PSScriptRoot '.env' }
$compose = @('compose', '--project-name', $projectName, '--project-directory', $PSScriptRoot,
    '--env-file', $envFile,
    '-f', 'frappe_docker/compose.yaml',
    '-f', 'frappe_docker/overrides/compose.mariadb.yaml',
    '-f', 'frappe_docker/overrides/compose.redis.yaml',
    '-f', 'frappe_docker/overrides/compose.noproxy.yaml',
    '-f', 'compose.local.yaml')
function Invoke-Compose {
    & docker @compose @args
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed (exit $LASTEXITCODE)." }
}
switch ($Action) {
    'Build' {
        $appsHash = (Get-FileHash -LiteralPath apps.json -Algorithm SHA256).Hash
        & docker build --platform linux/amd64 --progress plain `
            --build-arg FRAPPE_PATH=https://github.com/frappe/frappe `
            --build-arg FRAPPE_BRANCH=v16.33.1 `
            --build-arg PYTHON_VERSION=3.14 --build-arg NODE_VERSION=24 `
            --build-arg "CACHE_BUST=$appsHash" `
            --secret id=apps_json,src=apps.json `
            --tag alhorani-frappe:2026-09-14-helpdesk `
            --file frappe_docker/images/custom/Containerfile frappe_docker
        if ($LASTEXITCODE -ne 0) { throw 'Image build failed.' }
    }
    'Start' { Invoke-Compose up -d }
    'Stop' { Invoke-Compose stop }
    'Restart' { Invoke-Compose restart backend frontend websocket queue-short queue-long scheduler }
    'Status' { Invoke-Compose ps -a }
    'Logs' {
        if ($ExtraArgs) { Invoke-Compose logs --tail 100 @ExtraArgs }
        else { Invoke-Compose logs --tail 50 }
    }
    'Bench' { Invoke-Compose exec -T backend bench --site frappe.localhost @ExtraArgs }
    'Install' {
        # Idempotent: an existing site is preserved; only missing apps are installed.
        foreach ($line in Get-Content -LiteralPath $envFile) {
            if ($line -match '^(DB_PASSWORD|ADMIN_PASSWORD)=(.*)$') {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
            }
        }
        try {
            Invoke-Compose cp scripts/install-site.sh backend:/tmp/install-frappe-site.sh
            Invoke-Compose exec -T -e DB_PASSWORD -e ADMIN_PASSWORD backend bash /tmp/install-frappe-site.sh
            Invoke-Compose cp scripts/configure_site.py backend:/tmp/configure-frappe-site.py
            Invoke-Compose exec -T backend env/bin/python /tmp/configure-frappe-site.py
        } finally {
            [Environment]::SetEnvironmentVariable('DB_PASSWORD', $null, 'Process')
            [Environment]::SetEnvironmentVariable('ADMIN_PASSWORD', $null, 'Process')
        }
    }
    'Backup' {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $containerBackup = "/tmp/frappe-backup-$timestamp"
        Invoke-Compose exec -T backend bench --site frappe.localhost backup --with-files --backup-path $containerBackup
        $destination = Join-Path $PSScriptRoot ('backups/' + $timestamp)
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Invoke-Compose cp "backend:$containerBackup/." $destination
        Invoke-Compose cp 'backend:/home/frappe/frappe-bench/sites/frappe.localhost/site_config.json' (Join-Path $destination 'site_config.json')
        Invoke-Compose cp 'backend:/home/frappe/frappe-bench/sites/common_site_config.json' (Join-Path $destination 'common_site_config.json')
        Copy-Item -LiteralPath apps.json -Destination $destination
        Copy-Item -LiteralPath source-versions.json,deployment-info.json,python-packages.lock.txt -Destination $destination
        Write-Output "Backup saved to $destination"
    }
    'Verify' {
        Invoke-Compose cp scripts/verify_runtime.py backend:/tmp/verify-frappe-runtime.py
        Invoke-Compose exec -T backend env/bin/python /tmp/verify-frappe-runtime.py
        Invoke-Compose cp scripts/verify_insights.py backend:/tmp/verify-frappe-insights.py
        Invoke-Compose exec -T backend env/bin/python /tmp/verify-frappe-insights.py
        & python -u scripts/verify_http.py
        if ($LASTEXITCODE -ne 0) { throw 'HTTP verification failed.' }
    }
}
