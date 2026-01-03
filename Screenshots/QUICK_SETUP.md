# ⚡ Setup Rápido - 2 Minutos

## ✅ Ya está listo:
- ✅ 38 tests de screenshots creados
- ✅ Repositorio demo con datos realistas
- ✅ Scripts de automatización
- ✅ Post-procesamiento configurado

## 🎯 Solo falta 1 cosa: Agregar el target en Xcode

### Xcode ya está abierto. Sigue estos pasos:

#### 1️⃣ Crear el Target (30 segundos)
```
File → New → Target...
```
- Busca: **"UI Testing Bundle"** (bajo macOS)
- Click en **"UI Testing Bundle"**
- Click **Next**

#### 2️⃣ Configurar (30 segundos)
En la pantalla de configuración:
- **Product Name:** GitMacUITests
- **Target to be Tested:** GitMac
- **Organization Identifier:** (deja el que aparece)

Click **Finish**

#### 3️⃣ Limpiar (30 segundos)
Xcode creará un archivo que NO necesitamos:
- En el navegador de archivos (izquierda)
- Busca: **GitMacUITests**
- Verás: **GitMacUITestsLaunchTests.swift**
- Click derecho → **Delete** → **Move to Trash**

#### 4️⃣ Conectar nuestro archivo (30 segundos)
- En el navegador, busca: **Tests/GitMacUITests/GitMacScreenshotTests.swift**
- Click en el archivo
- En el panel derecho (File Inspector)
- Bajo "Target Membership" marca: ✅ **GitMacUITests**

#### 5️⃣ Verificar (30 segundos)
```
Product → Build For → Testing
```
O presiona: **⌘ + Shift + U**

Si compila sin errores, ¡listo!

---

## 🚀 Luego ejecuta:

```bash
cd Screenshots
./capture-screenshots.sh --clean
```

---

## ⏱️ Tiempo total: ~2 minutos

¿Listo para empezar? **¡Vamos a Xcode!** 🎉
