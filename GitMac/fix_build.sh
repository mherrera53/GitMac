#!/bin/bash

# Script para arreglar problemas de build - Eliminar archivos duplicados
# Ejecutar desde la raíz del proyecto: bash fix_build.sh

echo "🔧 Arreglando problemas de build de GitMac..."
echo ""

# 1. Limpiar DerivedData
echo "📦 Limpiando DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/GitMac-*
echo "✅ DerivedData limpiado"
echo ""

# 2. Buscar archivos duplicados
echo "🔍 Buscando archivos duplicados..."
echo ""

# Archivos problemáticos identificados
DUPLICATES=(
    "InteractiveRebaseView.swift"
    "ThemeManager.swift"
    "SearchView.swift"
)

for file in "${DUPLICATES[@]}"; do
    echo "Buscando: $file"
    find . -name "$file" -not -path "*/DerivedData/*" -not -path "*/.build/*"
    echo ""
done

echo "⚠️  IMPORTANTE: Debes eliminar los archivos DUPLICADOS MANUALMENTE en Xcode:"
echo ""
echo "1. Abre Xcode"
echo "2. En Project Navigator (⌘1), busca cada archivo duplicado"
echo "3. Para cada duplicado encontrado:"
echo "   - Click derecho → Delete"
echo "   - Selecciona 'Remove Reference' (NO 'Move to Trash')"
echo ""
echo "Los archivos a MANTENER son los más recientes (más líneas):"
echo "  ✅ InteractiveRebaseView.swift (~594 líneas)"
echo "  ✅ ThemeManager.swift (~685 líneas)"
echo "  ✅ SearchView.swift (~645 líneas)"
echo ""
echo "Los archivos a ELIMINAR (versiones antiguas/incompletas):"
echo "  ❌ Versiones con menos líneas"
echo ""

# 3. Instrucciones finales
echo "📋 Después de eliminar los duplicados:"
echo "1. En Xcode: Product → Clean Build Folder (⌘⇧K)"
echo "2. En Xcode: Product → Build (⌘B)"
echo ""
echo "✨ Si el build sigue fallando, ejecuta:"
echo "   xcodebuild clean -project GitMac.xcodeproj -scheme GitMac"
echo ""
