#!/bin/bash

# Script para eliminar archivos duplicados automáticamente
# IMPORTANTE: Este script MUEVE los duplicados a una carpeta de backup

echo "🔧 GitMac - Eliminador Automático de Duplicados"
echo "================================================"
echo ""

# Crear carpeta de backup
BACKUP_DIR="./duplicates_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "📦 Backup creado en: $BACKUP_DIR"
echo ""

# Archivos a revisar
FILES_TO_CHECK=("InteractiveRebaseView.swift" "ThemeManager.swift" "SearchView.swift")

for filename in "${FILES_TO_CHECK[@]}"; do
    echo "🔍 Buscando: $filename"
    
    # Buscar todos los archivos con este nombre
    found_files=($(find . -name "$filename" -not -path "*/DerivedData/*" -not -path "*/.build/*" -not -path "*/duplicates_backup*"))
    
    count=${#found_files[@]}
    
    if [ $count -eq 0 ]; then
        echo "   ⚠️  No encontrado"
    elif [ $count -eq 1 ]; then
        echo "   ✅ OK - Solo 1 archivo"
    else
        echo "   ⚠️  Encontrados $count duplicados:"
        
        # Mostrar cada archivo y su tamaño
        for file in "${found_files[@]}"; do
            lines=$(wc -l < "$file")
            echo "      - $file ($lines líneas)"
        done
        
        # Encontrar el archivo más grande (mantener)
        largest_file=""
        largest_size=0
        
        for file in "${found_files[@]}"; do
            lines=$(wc -l < "$file")
            if [ $lines -gt $largest_size ]; then
                largest_size=$lines
                largest_file="$file"
            fi
        done
        
        echo ""
        echo "   ✅ MANTENER: $largest_file ($largest_size líneas)"
        echo "   ❌ MOVER A BACKUP:"
        
        # Mover los archivos más pequeños al backup
        for file in "${found_files[@]}"; do
            if [ "$file" != "$largest_file" ]; then
                lines=$(wc -l < "$file")
                echo "      - $file ($lines líneas)"
                
                # Crear estructura de directorios en backup
                dir_path=$(dirname "$file")
                mkdir -p "$BACKUP_DIR/$dir_path"
                
                # Mover archivo
                mv "$file" "$BACKUP_DIR/$file"
            fi
        done
    fi
    
    echo ""
done

echo "================================================"
echo "✅ Proceso completado"
echo ""
echo "📋 Resumen:"
echo "   - Duplicados movidos a: $BACKUP_DIR"
echo "   - Para restaurar: mv $BACKUP_DIR/* ."
echo "   - Para eliminar: rm -rf $BACKUP_DIR"
echo ""
echo "🚀 Próximos pasos:"
echo "   1. Abrir Xcode"
echo "   2. Product → Clean Build Folder (⌘⇧K)"
echo "   3. Product → Build (⌘B)"
echo ""
echo "Si el build funciona, puedes eliminar el backup:"
echo "   rm -rf $BACKUP_DIR"
echo ""
