# Копирует иконки в проект. Источники (по приоритету):
#   1) android/app/src/appIcons  — как у вас (android/mipmap-*, Assets.xcassets, …)
#   2) application/ в корне bible_app
# Запуск:  pwsh ./tools/sync_application_icons.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$androidRes = Join-Path $root "android/app/src/main/res"
$appIcons = Join-Path $root "android/app/src/appIcons"
$application = Join-Path $root "application"
$branding = Join-Path $root "assets/branding"

$bundle = $null
if (Test-Path (Join-Path $appIcons "android/mipmap-mdpi")) {
    $bundle = $appIcons
    Write-Host "Источник: appIcons"
}
elseif (Test-Path $application) {
    $bundle = $application
    Write-Host "Источник: application"
}
else {
    Write-Warning "Нет ни android/app/src/appIcons, ни application/. Добавьте одну из папок."
    exit 0
}

# --- Android mipmaps ---
$mipmapSrc = $null
foreach ($p in @(
        (Join-Path $bundle "android"),
        (Join-Path $bundle "android/app/src/main/res"),
        (Join-Path $bundle "app/src/main/res"),
        (Join-Path $bundle "res"),
        $bundle
    )) {
    if ((Test-Path (Join-Path $p "mipmap-mdpi")) -or (Test-Path (Join-Path $p "mipmap-hdpi"))) {
        $mipmapSrc = $p
        break
    }
}

if ($mipmapSrc) {
    foreach ($d in @("mipmap-mdpi", "mipmap-hdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi", "mipmap-anydpi-v26", "drawable")) {
        $srcDir = Join-Path $mipmapSrc $d
        if (Test-Path $srcDir) {
            $dstDir = Join-Path $androidRes $d
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
            Copy-Item -Path (Join-Path $srcDir "*") -Destination $dstDir -Force
            Write-Host "OK: $d"
        }
    }
} else {
    Write-Warning "mipmap-* не найдены в $bundle"
}

# --- Splash + Flutter branding: предпочтительно 1024 из AppIcon ---
New-Item -ItemType Directory -Path $branding -Force | Out-Null
$splashMaster = $null
foreach ($cand in @(
        (Join-Path $bundle "Assets.xcassets/AppIcon.appiconset/1024.png"),
        (Join-Path $bundle "appstore.png"),
        (Join-Path $bundle "playstore.png")
    )) {
    if (Test-Path $cand) {
        $splashMaster = $cand
        break
    }
}
if (-not $splashMaster) {
    $allPng = Get-ChildItem -Path $bundle -Recurse -Filter "*.png" -File -ErrorAction SilentlyContinue
    if ($allPng.Count -gt 0) {
        $splashMaster = ($allPng | Sort-Object Length -Descending | Select-Object -First 1).FullName
    }
}
if ($splashMaster) {
    Copy-Item -LiteralPath $splashMaster -Destination (Join-Path $androidRes "drawable/splash_logo.png") -Force
    Copy-Item -LiteralPath $splashMaster -Destination (Join-Path $branding "launch_logo.png") -Force
    Write-Host "Splash: $splashMaster"
}

# --- iOS (если лежит рядом AppIcon) ---
$iosIconSrc = Join-Path $bundle "Assets.xcassets/AppIcon.appiconset"
$iosIconDst = Join-Path $root "ios/Runner/Assets.xcassets/AppIcon.appiconset"
if ((Test-Path $iosIconSrc) -and (Test-Path (Split-Path $iosIconDst))) {
    Remove-Item (Join-Path $iosIconDst "*") -Force -Recurse -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $iosIconSrc "*") $iosIconDst -Recurse -Force
    Write-Host "OK: iOS AppIcon.appiconset"
}

# --- Web PWA ---
$webIconSet = Join-Path $bundle "Assets.xcassets/AppIcon.appiconset"
$webOut = Join-Path $root "web/icons"
if ((Test-Path (Join-Path $webIconSet "512.png")) -and (Test-Path (Join-Path $webIconSet "256.png"))) {
    New-Item -ItemType Directory -Path $webOut -Force | Out-Null
    Copy-Item (Join-Path $webIconSet "512.png") (Join-Path $webOut "Icon-512.png") -Force
    Copy-Item (Join-Path $webIconSet "256.png") (Join-Path $webOut "Icon-192.png") -Force
    Copy-Item (Join-Path $webIconSet "512.png") (Join-Path $webOut "Icon-maskable-512.png") -Force
    Copy-Item (Join-Path $webIconSet "256.png") (Join-Path $webOut "Icon-maskable-192.png") -Force
    Write-Host "OK: web/icons"
}

Write-Host "Готово."
