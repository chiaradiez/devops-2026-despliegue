param(
    [ValidateSet('status', 'on', 'off')]
    [string]$Action = 'status',
    [string]$ApiBaseUrl = 'http://localhost/api'
)

$base = $ApiBaseUrl.TrimEnd('/')

if ($Action -eq 'status') {
    Invoke-RestMethod -Uri "$base/feature-flags?group=beta" -Method Get | ConvertTo-Json -Depth 5
    exit 0
}

if (-not $env:FEATURE_FLAGS_ADMIN_TOKEN) {
    throw 'Definí FEATURE_FLAGS_ADMIN_TOKEN en esta terminal antes de activar o desactivar la bandera.'
}

$body = @{
    group = 'beta'
    enabled = ($Action -eq 'on')
} | ConvertTo-Json

Invoke-RestMethod -Uri "$base/admin/feature-flags/show_order_wait_time" `
    -Method Patch `
    -Headers @{ Authorization = "Bearer $env:FEATURE_FLAGS_ADMIN_TOKEN" } `
    -ContentType 'application/json' `
    -Body $body | ConvertTo-Json -Depth 5
