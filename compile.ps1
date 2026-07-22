# Script para compilar MultiSaver desde PowerShell
# Uso: .\compile.ps1

$solutionPath = "MultiSaver\MultiSaver.sln"
$projectPath = "MultiSaver\MultiSaver\MultiSaver\MultiSaver.csproj"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "MultiSaver Build Script" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

# Verificar .NET SDK
Write-Host "`nVerificando .NET SDK..." -ForegroundColor Yellow
$dotnetCheck = & dotnet --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: .NET SDK no está instalado" -ForegroundColor Red
    Write-Host "Descarga desde: https://dotnet.microsoft.com/download" -ForegroundColor Cyan
    exit 1
}
Write-Host "✅ .NET SDK encontrado: $dotnetCheck" -ForegroundColor Green

# Limpiar builds anteriores
Write-Host "`nLimpiando builds anteriores..." -ForegroundColor Yellow
if (Test-Path "MultiSaver\bin") {
    Remove-Item "MultiSaver\bin" -Recurse -Force
    Write-Host "✅ Carpeta bin limpiada" -ForegroundColor Green
}

# Restaurar dependencias NuGet
Write-Host "`nRestaurando paquetes NuGet..." -ForegroundColor Yellow
& dotnet restore $solutionPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  WARNING: NuGet restore tuvo issues, continuando..." -ForegroundColor Yellow
}

# Compilar
Write-Host "`nCompilando solución..." -ForegroundColor Yellow
& dotnet build $solutionPath -c Release --no-restore
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: Compilación falló" -ForegroundColor Red
    exit 1
}

# Buscar .exe
Write-Host "`nBuscando ejecutable generado..." -ForegroundColor Yellow
$exePaths = @(
    "MultiSaver\bin\Release\MultiSaver.exe",
    "MultiSaver\MultiSaver\bin\Release\MultiSaver.exe",
    "MultiSaver\MultiSaver\bin\Release\net4.8\MultiSaver.exe"
)

$foundExe = $null
foreach ($exe in $exePaths) {
    if (Test-Path $exe) {
        $foundExe = $exe
        break
    }
}

if ($foundExe) {
    Write-Host "✅ COMPILACIÓN EXITOSA" -ForegroundColor Green
    Write-Host "Ejecutable: $foundExe" -ForegroundColor Cyan
    Write-Host "`nPara ejecutar:" -ForegroundColor Yellow
    Write-Host "  Panel de config:    & '$foundExe' /c" -ForegroundColor Green
    Write-Host "  Screensaver:        & '$foundExe' /s" -ForegroundColor Green
} else {
    Write-Host "❌ No se encontró MultiSaver.exe" -ForegroundColor Red
    Write-Host "Carpetas buscadas:" -ForegroundColor Yellow
    $exePaths | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Build completado" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
