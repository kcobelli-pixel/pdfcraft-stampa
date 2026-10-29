<#
  PdfCraft con le patch, per Windows: la correzione della stampa per le stampanti Brother e più
  firme salvate in Compila e firma.

  Dopo ogni aggiornamento di PdfCraft fatto con l'ArtCraft Launcher, esegui Applica-patch.cmd.
  Lo script:
    1. legge la versione di PdfCraft installata;
    2. scarica da github.com/kcobelli-pixel/pdfcraft-stampa la build della stessa versione con le
       patch e ne controlla l'impronta SHA-256;
    3. la installa al posto di quella ufficiale (Windows chiede il permesso di amministratore).
  Quando il driver rifiuta la stampa XPS (errore 0x80040003, "Interfaccia non supportata"), questa
  build stampa il documento tramite GDI. Le firme salvate restano nelle preferenze di PdfCraft. Per
  tornare alla versione ufficiale basta "Reinstalla" nel Launcher, o il prossimo aggiornamento.

  Funziona con Windows PowerShell 5.1 (quello di Windows 10/11) e con PowerShell 7.
  Il file è salvato in UTF-8 con BOM: senza, PowerShell 5.1 mostra male le lettere accentate.
#>
$ErrorActionPreference = 'Stop'

# A 32-bit PowerShell sees the 32-bit registry and would miss the x64 install: rerun as 64-bit.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
  & "$env:windir\sysnative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
  exit $LASTEXITCODE
}

# Invoke-WebRequest in Windows PowerShell 5.1 is very slow while it draws a progress bar.
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = 'kcobelli-pixel/pdfcraft-stampa'
$Publisher = 'Learning Machines LLC'
$Headers = @{ 'User-Agent' = 'pdfcraft-patch'; 'Accept' = 'application/vnd.github+json' }
$InstallLog = Join-Path ([IO.Path]::GetTempPath()) 'pdfcraft-patch-installazione.log'
$script:Tmp = $null

function Fail([string] $Text, [int] $Code = 1) {
  if ($script:Tmp) { Remove-Item -LiteralPath $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
  Write-Host ''
  Write-Host $Text -ForegroundColor Red
  exit $Code
}

# Builds exist only for the newest PdfCraft: an older one is told to update first.
function Fail-NotReady {
  $latest = $null
  try { $latest = [string] (Invoke-RestMethod -Uri 'https://api.github.com/repos/storytold/pdfcraft/releases/latest' -Headers $Headers).tag_name } catch { }
  if ($latest -match '^v?(\d+\.\d+\.\d+)$' -and $Matches[1] -ne $version) {
    Fail "C'è una versione più recente di PdfCraft ($($Matches[1])): aggiornalo con l'ArtCraft Launcher, poi riesegui la patch. La patch viene preparata solo per l'ultima versione." 2
  }
  Fail "La versione di PdfCraft $version con le patch non è ancora pronta. Viene preparata in automatico entro qualche ora da ogni aggiornamento: riprova più tardi." 2
}

function Assert-NotRunning {
  if (Get-Process -Name pdfcraft -ErrorAction SilentlyContinue) {
    Fail 'PdfCraft è aperto: chiudilo e riesegui la patch.'
  }
}

# The ArtCraft Launcher installs PdfCraft with its MSI (per-machine): the Uninstall entry is the
# truth for the version, as in the launcher's own detection.
function Find-MsiInstall {
  $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  @(Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq 'PdfCraft' -and $_.Publisher -eq $Publisher })
}

function Get-MsiFolder {
  $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\pdfcraft.exe'
  $exe = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).'(default)'
  if (-not $exe) { return $null }
  $dir = Split-Path -Parent $exe.Trim('"')
  if ($dir -and (Test-Path -LiteralPath $dir) -and $dir -notmatch '"') { return $dir }
  $null
}

function Assert-Hash([string] $File, [string] $SumsFile) {
  $name = Split-Path -Leaf $File
  $expected = $null
  foreach ($line in Get-Content -LiteralPath $SumsFile) {
    if ($line -match '^([0-9a-fA-F]{64}) [ *](.+)$' -and $Matches[2].Trim() -eq $name) {
      $expected = $Matches[1].ToLowerInvariant()
      break
    }
  }
  # Not listed yet: the release is still being published.
  if (-not $expected) { Fail-NotReady }
  $actual = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    Fail "Il file scaricato $name non corrisponde all'impronta pubblicata, quindi non lo installo. Se la versione si stava aggiornando proprio ora, riprova tra qualche minuto."
  }
}

function Save-Asset($Release, [string] $Name, [string] $Dir) {
  $asset = @($Release.assets) | Where-Object { $_.name -eq $Name } | Select-Object -First 1
  if (-not $asset) { Fail-NotReady }
  $url = [string] $asset.browser_download_url
  if (-not $url.StartsWith("https://github.com/$Repo/releases/download/")) { Fail "Indirizzo di download inatteso: $url" }
  $out = Join-Path $Dir $Name
  try {
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -Headers @{ 'User-Agent' = 'pdfcraft-patch' }
  } catch {
    Fail "Download di $Name non riuscito: $($_.Exception.Message)"
  }
  $out
}

Write-Host 'PdfCraft con le patch'
Write-Host '====================='

if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64' -or -not [Environment]::Is64BitOperatingSystem) {
  Fail 'Questa patch esiste solo per Windows a 64 bit su processori Intel o AMD (x64).'
}

$msiInstalls = @(Find-MsiInstall)
$portableExe = Join-Path $env:LOCALAPPDATA 'ArtCraft Launcher\apps\pdfcraft\pdfcraft.exe'
if ($msiInstalls.Count -gt 1) {
  Fail 'Risultano installate più copie di PdfCraft: disinstallale da Impostazioni > App, reinstalla PdfCraft dal Launcher e riprova.'
} elseif ($msiInstalls.Count -eq 1) {
  $mode = 'msi'
  $version = [string] $msiInstalls[0].DisplayVersion
} elseif (Test-Path -LiteralPath $portableExe) {
  $mode = 'portable'
  $record = Join-Path $env:LOCALAPPDATA 'ArtCraft Launcher\installed.json'
  $version = $null
  if (Test-Path -LiteralPath $record) {
    try { $version = [string] (Get-Content -LiteralPath $record -Raw | ConvertFrom-Json).apps.pdfcraft.version } catch { $version = $null }
  }
  if (-not $version) { $version = [string] (Get-Item -LiteralPath $portableExe).VersionInfo.ProductVersion }
} else {
  Fail 'PdfCraft non risulta installato: installalo (o aggiornalo) con l''ArtCraft Launcher, poi riesegui la patch.'
}
if ($version -notmatch '^\d+\.\d+\.\d+$') { Fail "Versione di PdfCraft non riconosciuta: '$version'." }
Write-Host "PdfCraft installato: versione $version"
Assert-NotRunning

$tag = "v$version"
try {
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$tag" -Headers $Headers
} catch {
  $status = 0
  if ($_.Exception.Response) { $status = [int] $_.Exception.Response.StatusCode }
  if ($status -eq 404) { Fail-NotReady }
  Fail "Non riesco a contattare GitHub: $($_.Exception.Message)"
}

# build.yml publishes this marker instead of a Windows build once the official sources have
# everything the patches add.
if (@($release.assets) | Where-Object { $_.name -eq 'PATCH-UFFICIALE-windows.txt' }) {
  $official = "Buone notizie: PdfCraft $version contiene già ufficialmente tutto quello che aggiungeva la patch (correzione della stampa e più firme salvate).`n`nLa patch non serve più: da ora puoi aggiornare PdfCraft con il Launcher e usarlo così com'è. Se qualcosa non dovesse funzionare, segnalalo."
  Write-Host ''
  Write-Host $official -ForegroundColor Green
  try { $null = (New-Object -ComObject WScript.Shell).Popup($official, 0, 'PdfCraft: patch', 64) } catch { }
  exit 0
}

$script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ('pdfcraft-patch-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:Tmp | Out-Null
Write-Host 'Scarico la versione con le patch...'
$sums = Save-Asset $release 'SHA256SUMS.txt' $script:Tmp

if ($mode -eq 'msi') {
  $msi = Save-Asset $release "pdfcraft-$version-windows-x64.msi" $script:Tmp
  Assert-Hash $msi $sums
  Unblock-File -LiteralPath $msi
  $msiArgs = @('/i', "`"$msi`"", '/passive', '/norestart', '/l*v', "`"$InstallLog`"")
  # From 0.15.0 the MSI installs for the current user unless told otherwise, and refuses to
  # update an install for everyone that way: keep the installed copy's scope.
  if ($msiInstalls[0].PSPath -like '*HKEY_LOCAL_MACHINE*') { $msiArgs += 'ALLUSERS=1' }
  $folder = Get-MsiFolder
  if ($folder) { $msiArgs += "INSTALLFOLDER=`"$folder`"" }
  Assert-NotRunning
  Write-Host 'Installo la versione con le patch: se Windows chiede il permesso, rispondi Sì.'
  $msiexec = Join-Path $env:SystemRoot 'System32\msiexec.exe'
  $process = Start-Process -FilePath $msiexec -ArgumentList $msiArgs -Wait -PassThru
  switch ($process.ExitCode) {
    0 { }
    3010 { Write-Host 'Windows chiede di riavviare il PC per completare l''installazione.' -ForegroundColor Yellow }
    1641 { }
    1602 { Fail 'Installazione annullata: PdfCraft resta quello ufficiale.' }
    1618 { Fail 'Un''altra installazione è in corso: aspetta che finisca e riesegui la patch.' }
    default { Fail "L'installazione non è riuscita (codice $($process.ExitCode)). Il registro è in $InstallLog" }
  }
  $after = @(Find-MsiInstall)
  if ($after.Count -ne 1 -or [string] $after[0].DisplayVersion -ne $version) {
    Fail "Dopo l'installazione PdfCraft non risulta alla versione $version. Il registro è in $InstallLog"
  }
} else {
  $zip = Save-Asset $release "pdfcraft-$version-windows-x64-portable.zip" $script:Tmp
  Assert-Hash $zip $sums
  Unblock-File -LiteralPath $zip
  $unpacked = Join-Path $script:Tmp 'unpacked'
  Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
  $target = Split-Path -Parent $portableExe
  Assert-NotRunning
  foreach ($name in 'pdfcraft.exe', 'pdfcraft-cli.exe') {
    $source = Get-ChildItem -LiteralPath $unpacked -Recurse -Filter $name | Select-Object -First 1
    if (-not $source) { Fail "Nello zip manca $name." }
    Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $target $name) -Force
  }
}

# The build's receipt says which patches it has (one may not have applied to this version).
$fixes = ''
$receipt = @($release.assets) | Where-Object { $_.name -eq 'PATCHES-windows.txt' } | Select-Object -First 1
if ($receipt) {
  $receiptFile = Join-Path $script:Tmp 'PATCHES-windows.txt'
  try {
    Invoke-WebRequest -Uri $receipt.browser_download_url -OutFile $receiptFile -UseBasicParsing -Headers @{ 'User-Agent' = 'pdfcraft-patch' }
    $fixes = Get-Content -LiteralPath $receiptFile -Raw
  } catch { }
}
$done = @()
if ($fixes -match 'print') { $done += 'stampa anche sulle Brother' }
if ($fixes -match 'signatures') { $done += 'tiene più firme salvate' }
$what = if ($done.Count) { $done -join ' e ' } else { 'ha le patch' }
Remove-Item -LiteralPath $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host "Fatto: PdfCraft $version $what." -ForegroundColor Green
Write-Host 'Dopo il prossimo aggiornamento di PdfCraft riesegui Applica-patch.cmd.'
exit 0
