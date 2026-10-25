[CmdletBinding()]
param(
    [string]$BaseUri = "http://localhost:8080",

    [ValidateRange(1000, 100000)]
    [int]$Requests = 1000,

    [ValidateRange(0, 100)]
    [double]$ExpectedV2Percent = 10,

    [ValidateRange(0.1, 20)]
    [double]$Tolerance = 5,

    [switch]$TestOrders
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 no siempre carga este ensamblado al resolver el tipo.
Add-Type -AssemblyName System.Net.Http

$base = $BaseUri.TrimEnd("/")
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(10)
$counts = @{ v1 = 0; v2 = 0; unknown = 0; httpErrors = 0 }
$failures = [System.Collections.Generic.List[string]]::new()

try {
    Write-Host "Enviando $Requests solicitudes a $base ..."

    for ($i = 1; $i -le $Requests; $i++) {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, "$base/")
        try {
            $response = $client.SendAsync($request).GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) {
                $counts.httpErrors++
                continue
            }

            $headerValues = $null
            if (-not $response.Headers.TryGetValues("X-App-Version", [ref]$headerValues)) {
                $counts.unknown++
                continue
            }

            $version = ($headerValues | Select-Object -First 1).ToLowerInvariant()
            if ($version -eq "v1" -or $version -eq "v2") {
                $counts[$version]++
            } else {
                $counts.unknown++
            }
        } catch {
            $counts.httpErrors++
        } finally {
            if ($null -ne $response) { $response.Dispose() }
            $request.Dispose()
            $response = $null
        }
    }

    $v1Percent = 100 * $counts.v1 / $Requests
    $v2Percent = 100 * $counts.v2 / $Requests
    $expectedV1Percent = 100 - $ExpectedV2Percent

    Write-Host ""
    Write-Host "Total de solicitudes: $Requests"
    Write-Host ("Version V1: {0} solicitudes ({1:N1} %)" -f $counts.v1, $v1Percent)
    Write-Host ("Version V2: {0} solicitudes ({1:N1} %)" -f $counts.v2, $v2Percent)
    Write-Host "Errores HTTP o de red: $($counts.httpErrors)"
    Write-Host "Respuestas sin version valida: $($counts.unknown)"

    if ($counts.httpErrors -gt 0) {
        $failures.Add("Se detectaron $($counts.httpErrors) errores HTTP o de red.")
    }
    if ($counts.unknown -gt 0) {
        $failures.Add("Se detectaron $($counts.unknown) respuestas sin X-App-Version valida.")
    }

    if ($ExpectedV2Percent -eq 0 -or $ExpectedV2Percent -eq 100) {
        if ([Math]::Abs($v2Percent - $ExpectedV2Percent) -gt 0) {
            $failures.Add("El perfil extremo exige $ExpectedV2Percent % de V2 sin tolerancia.")
        }
    } elseif ([Math]::Abs($v2Percent - $ExpectedV2Percent) -gt $Tolerance) {
        $failures.Add("V2 quedo fuera de la tolerancia de +/- $Tolerance puntos porcentuales.")
    }

    if ([Math]::Abs($v1Percent - $expectedV1Percent) -gt $Tolerance -and
        $ExpectedV2Percent -ne 0 -and $ExpectedV2Percent -ne 100) {
        $failures.Add("V1 quedo fuera de la tolerancia de +/- $Tolerance puntos porcentuales.")
    }

    # Verifica que la cabecera coincida con la variante HTML realmente servida.
    $requiredVersions = @()
    if ($expectedV1Percent -gt 0) { $requiredVersions += "v1" }
    if ($ExpectedV2Percent -gt 0) { $requiredVersions += "v2" }
    $verifiedVersions = @{}

    for ($attempt = 1; $attempt -le 100 -and $verifiedVersions.Count -lt $requiredVersions.Count; $attempt++) {
        $response = $client.GetAsync("$base/").GetAwaiter().GetResult()
        try {
            $headerValues = $null
            if (-not $response.Headers.TryGetValues("X-App-Version", [ref]$headerValues)) { continue }
            $version = ($headerValues | Select-Object -First 1).ToLowerInvariant()
            if ($version -notin $requiredVersions -or $verifiedVersions.ContainsKey($version)) { continue }

            $html = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $hasCanaryLabel = $html.Contains("CoffeeQueue V2 - Canary")
            if (($version -eq "v2" -and $hasCanaryLabel) -or ($version -eq "v1" -and -not $hasCanaryLabel)) {
                $verifiedVersions[$version] = $true
            } else {
                $failures.Add("La cabecera $version no coincide con el HTML visible recibido.")
            }
        } finally {
            $response.Dispose()
        }
    }

    foreach ($version in $requiredVersions) {
        if (-not $verifiedVersions.ContainsKey($version)) {
            $failures.Add("No se pudo validar el HTML de $version en 100 intentos.")
        }
    }

    # /api debe ir directamente al backend compartido, nunca al upstream de frontends.
    $apiResponse = $client.GetAsync("$base/api/orders").GetAwaiter().GetResult()
    try {
        if (-not $apiResponse.IsSuccessStatusCode) {
            $failures.Add("GET /api/orders respondio HTTP $([int]$apiResponse.StatusCode).")
        }
        if ($apiResponse.Headers.Contains("X-App-Version")) {
            $failures.Add("La API recibio X-App-Version: parece estar pasando por el upstream de frontends.")
        }
    } finally {
        $apiResponse.Dispose()
    }

    if ($TestOrders) {
        $createdId = $null
        try {
            $payload = @{
                customer = "Prueba Canary"
                items = @(@{ name = "Cafe de prueba"; quantity = 1 })
            } | ConvertTo-Json -Depth 4
            $content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, "application/json")
            $postResponse = $client.PostAsync("$base/api/orders", $content).GetAwaiter().GetResult()
            try {
                if (-not $postResponse.IsSuccessStatusCode) {
                    $failures.Add("No se pudo crear el pedido de prueba: HTTP $([int]$postResponse.StatusCode).")
                } else {
                    $created = $postResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                    $createdId = $created.data.id
                    Write-Host "Pedido temporal $createdId creado correctamente."
                }
            } finally {
                $postResponse.Dispose()
                $content.Dispose()
            }
        } finally {
            if ($null -ne $createdId) {
                $deleteResponse = $client.DeleteAsync("$base/api/orders/$createdId").GetAwaiter().GetResult()
                try {
                    if (-not $deleteResponse.IsSuccessStatusCode) {
                        $failures.Add("El pedido temporal $createdId no pudo eliminarse.")
                    } else {
                        Write-Host "Pedido temporal $createdId eliminado correctamente."
                    }
                } finally {
                    $deleteResponse.Dispose()
                }
            }
        }
    }

    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Host "Resultado: FALLIDO" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host "- $failure" -ForegroundColor Red }
        exit 1
    }

    Write-Host ""
    Write-Host "Resultado: distribucion y rutas validadas correctamente." -ForegroundColor Green
} finally {
    $client.Dispose()
}
