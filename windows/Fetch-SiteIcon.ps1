param([Parameter(Mandatory=$true)][string]$HostName)
$ErrorActionPreference = 'Stop'
if ($HostName -notmatch '^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?::[0-9]+)?$') { exit 1 }
$cache = Join-Path $PSScriptRoot 'site-icons'
$null = New-Item -ItemType Directory -Path $cache -Force
$key = $HostName.ToLowerInvariant().Replace(':','_')
$destination = Join-Path $cache ($key + '.png')
$failure = Join-Path $cache ($key + '.failed')
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Drawing
$handler = [Net.Http.HttpClientHandler]::new()
$handler.UseCookies = $false
$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(8)
$client.MaxResponseContentBufferSize = 2097152
$client.DefaultRequestHeaders.UserAgent.ParseAdd('Mozilla/5.0 Squeak/2.2')
function Save-Icon([uri]$url) {
    if ($url.Scheme -ne 'https') { return $false }
    $response = $null; $memory = $null; $source = $null; $ico = $null
    $bitmap = $null; $graphics = $null
    try {
        $response = $client.GetAsync($url).GetAwaiter().GetResult()
        $null = $response.EnsureSuccessStatusCode()
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $memory = [IO.MemoryStream]::new([byte[]]$bytes)
        if ($bytes.Length -gt 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 1 -and $bytes[3] -eq 0) {
            $ico = [Drawing.Icon]::new($memory,64,64)
            $source = $ico.ToBitmap()
        } else { $source = [Drawing.Image]::FromStream($memory,$true,$true) }
        if ($source.Width -gt 4096 -or $source.Height -gt 4096) { return $false }
        $bitmap = [Drawing.Bitmap]::new(64,64)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode = 'HighQualityBicubic'
        $scale = [Math]::Min(64.0/$source.Width,64.0/$source.Height)
        $w = [int]($source.Width*$scale); $h = [int]($source.Height*$scale)
        $graphics.DrawImage($source,[int]((64-$w)/2),[int]((64-$h)/2),$w,$h)
        $temporary = $destination + '.' + $PID + '.tmp'
        $bitmap.Save($temporary,[Drawing.Imaging.ImageFormat]::Png)
        Move-Item -LiteralPath $temporary -Destination $destination -Force
        return $true
    } catch { return $false }
    finally {
        foreach ($resource in @($graphics,$bitmap,$source,$ico,$memory,$response)) {
            if ($null -ne $resource) { $resource.Dispose() }
        }
    }
}
try {
    $origin = [uri]('https://' + $HostName + '/')
    if (Save-Icon ([uri]::new($origin,'favicon.ico'))) { exit 0 }
    # Discover icon links when a site uses a PNG or a CDN instead of /favicon.ico.
    $response = $client.GetAsync($origin).GetAwaiter().GetResult()
    try {
        $null = $response.EnsureSuccessStatusCode()
        $html = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $base = $response.RequestMessage.RequestUri
    } finally { $response.Dispose() }
    $count = 0
    foreach ($tag in [regex]::Matches($html,'(?is)<link\b[^>]*>')) {
        if ($tag.Value -notmatch '(?i)\brel\s*=\s*["''][^"'']*\bicon\b[^"'']*["'']') { continue }
        if ($tag.Value -notmatch '(?i)\bhref\s*=\s*["'']([^"'']+)["'']') { continue }
        $url = [uri]::new($base,[Net.WebUtility]::HtmlDecode($Matches[1]))
        if (Save-Icon $url) { exit 0 }
        $count++
        if ($count -ge 3) { break }
    }
    throw 'Aucune icone exploitable.'
} catch {
    [IO.File]::WriteAllText($failure,[DateTime]::UtcNow.ToString('o'))
    exit 1
} finally { $client.Dispose(); $handler.Dispose() }
