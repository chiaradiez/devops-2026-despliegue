[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("100-0", "90-10", "50-50", "0-100")]
    [string]$Profile
)

$ErrorActionPreference = "Stop"

$composeFile = Join-Path $PSScriptRoot "docker-compose.canary.yml"
$activeFile = Join-Path $PSScriptRoot "weights\active.conf"
$profileFile = Join-Path $PSScriptRoot "weights\$Profile.conf"
$previousBytes = [System.IO.File]::ReadAllBytes($activeFile)

Copy-Item -LiteralPath $profileFile -Destination $activeFile -Force
Write-Host "Perfil $Profile copiado a weights/active.conf."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warning "Docker no esta disponible. El perfil quedo preparado para el proximo inicio."
    exit 0
}

$proxyId = docker compose -f $composeFile ps -q proxy
if ($LASTEXITCODE -ne 0) {
    [System.IO.File]::WriteAllBytes($activeFile, $previousBytes)
    throw "No se pudo consultar el estado del proxy. Se restauro la configuracion anterior."
}

if (-not $proxyId) {
    Write-Host "El proxy no esta ejecutandose. El perfil se aplicara al iniciar el stack."
    exit 0
}

docker compose -f $composeFile exec -T proxy nginx -t
if ($LASTEXITCODE -ne 0) {
    [System.IO.File]::WriteAllBytes($activeFile, $previousBytes)
    throw "Nginx rechazo la configuracion. Se restauro el perfil anterior."
}

docker compose -f $composeFile exec -T proxy nginx -s reload
if ($LASTEXITCODE -ne 0) {
    [System.IO.File]::WriteAllBytes($activeFile, $previousBytes)
    throw "No se pudo recargar Nginx. Se restauro el archivo anterior; valide y recargue nuevamente."
}

Write-Host "Perfil $Profile validado y aplicado sin detener los servicios."
