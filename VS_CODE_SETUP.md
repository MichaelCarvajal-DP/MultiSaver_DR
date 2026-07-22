# 🔧 Guía: Compilar MultiSaver en VS Code

## ⚡ TL;DR (Resumen rápido)

1. **Instala .NET SDK**: https://dotnet.microsoft.com/download
2. **En PowerShell**:
   ```powershell
   cd C:\Users\MichaelCarvajal\Desktop\Repositorio NEX\copilot-worktrees\MultiSaver\michaelcarvajal-dp-improved-potato
   .\compile.ps1
   ```
3. **Listo** → Ejecutable en: `MultiSaver\bin\Release\MultiSaver.exe`

---

## 📋 Pasos Detallados

### PASO 1: Instalar .NET SDK (Solo una vez)

**Opción A: Descarga directa**
1. Ve a: https://dotnet.microsoft.com/download
2. Descarga: **.NET 8 SDK** (o .NET 7/6)
3. Ejecuta el instalador `.exe`
4. Sigue el wizard → Next → Install → Finish
5. **⚠️ IMPORTANTE**: Cierra todas las ventanas de PowerShell y vuelve a abrir

**Opción B: Usar Chocolatey (si lo tienes)**
```powershell
choco install dotnet-sdk -y
```

**Verificar instalación**:
```powershell
dotnet --version
# Debe mostrar: 8.0.100 o similar
```

---

### PASO 2: Abrir el proyecto en VS Code

```powershell
cd "C:\Users\MichaelCarvajal\Desktop\Repositorio NEX\copilot-worktrees\MultiSaver\michaelcarvajal-dp-improved-potato"

code .
```

VS Code debería abrirse con la carpeta cargada.

---

### PASO 3: Instalar Extensiones en VS Code

1. **Abre el panel de extensiones**: `Ctrl + Shift + X`
2. **Busca e instala**:
   - `C# Dev Kit` (Microsoft)
   - `.NET Extension Pack` (Microsoft)
3. **Espera a que se instalen** (verás un popup "Reloading Window")

---

### PASO 4A: Compilar desde VS Code Terminal (Más fácil)

1. **Abre terminal**: `Ctrl + Ñ` (o `Ctrl + ~`)
2. **Ejecuta el script**:
   ```powershell
   .\compile.ps1
   ```
3. **Espera a que termine** (verás "Build completado" en verde)
4. **Ver el archivo generado**:
   ```
   MultiSaver\bin\Release\MultiSaver.exe
   ```

---

### PASO 4B: Compilar desde línea de comandos (Alternativa)

```powershell
# Limpiar
dotnet clean MultiSaver\MultiSaver.sln

# Restaurar dependencias
dotnet restore MultiSaver\MultiSaver.sln

# Compilar
dotnet build MultiSaver\MultiSaver.sln -c Release

# O en un solo comando:
dotnet build MultiSaver\MultiSaver.sln -c Release --no-restore
```

---

## ✅ Validación: ¿Funcionó?

Después de compilar, deberías ver:

```
✅ COMPILACIÓN EXITOSA
Ejecutable: MultiSaver\bin\Release\MultiSaver.exe

Para ejecutar:
  Panel de config:    & 'MultiSaver\bin\Release\MultiSaver.exe' /c
  Screensaver:        & 'MultiSaver\bin\Release\MultiSaver.exe' /s
```

---

## 🚀 Ejecutar el Screensaver

```powershell
# Panel de configuración (ingresa credenciales Wasabi)
& 'MultiSaver\bin\Release\MultiSaver.exe' /c

# Screensaver fullscreen
& 'MultiSaver\bin\Release\MultiSaver.exe' /s

# Preview (para panel de control)
& 'MultiSaver\bin\Release\MultiSaver.exe' /p <handle>
```

---

## 🔴 Errores Comunes

| Error | Solución |
|-------|----------|
| `dotnet: The term 'dotnet' is not recognized` | Instala .NET SDK, luego **cierra y reabre PowerShell** |
| `error : The project file could not be loaded` | Los archivos .csproj pueden tener rutas incorrectas. Abre `MultiSaver.sln` en Visual Studio Community |
| `error NU1101: Unable to find package` | Falta NuGet package. Ejecuta `dotnet restore` primero |
| `Build failed with errors` | Revisa los errores en la consola. Probablemente falte MonoGame. |
| `No such file: MultiSaver\bin\Release\...` | El build no se completó. Revisa los errores anteriores |

---

## 📦 Instalación de Dependencias (Si falla)

Si la compilación falla por dependencias:

```powershell
# Restaurar todos los paquetes NuGet
dotnet restore MultiSaver\MultiSaver.sln

# Verificar que los paquetes se descargaron
dotnet list package
```

---

## 💡 VS Code: Tips & Tricks

**Paleta de comandos** (`Ctrl + Shift + P`):
- Escribe `Build` → Ver opciones de build
- Escribe `Debug` → Ver opciones de debug
- Escribe `Terminal` → Abrir/cerrar terminal

**Explorer** (`Ctrl + B`):
- Navega por los archivos del proyecto
- Haz clic derecho en archivos para opciones

**Output Panel**:
- Ver errores de compilación en detalle
- Útil para debugging

---

## 🎯 Próximo Paso

Una vez compilado:
1. Crea `MultiSaverConfiguration.xml` con credenciales Wasabi
2. Ejecuta `MultiSaver.exe /c` para panel de config
3. Ingresa AccessKey, SecretKey, Bucket
4. Clic "Sync Now" (cuando implemente ConfigPanel)
5. Ejecuta `MultiSaver.exe /s` para ver screensaver

---

## ❓ ¿Problemas?

Si algo falla, comparte el **error exacto** de la consola y te ayudaré a resolverlo.

**Hilo de errores comunes en MultiSaver/MonoGame:**
- MonoGame no compatible con tu .NET version → Usa .NET 4.8 o 6.x
- Archivos .fx (shaders) no encontrados → Asegúrate de copiar carpeta `Content/`
- DirectX falta → Instala Visual C++ Redistributable

---

**Última actualización**: 2026-07-22
**Versión**: MVP 1.0
