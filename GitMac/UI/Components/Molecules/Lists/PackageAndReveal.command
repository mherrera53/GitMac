#!/usr/bin/env bash
set -euo pipefail

# Cambiar al directorio del script
cd "$(dirname "$0")"

# Comprobar y solicitar DEVELOPER_ID si no está seteado
if [[ -z "${DEVELOPER_ID-}" ]]; then
  echo -n "Por favor, ingresa tu DEVELOPER_ID (ej. Developer ID Application: Tu Nombre (SRVK53YUSF)): "
  read -r DEVELOPER_ID
fi

# Comprobar y solicitar APPLE_ID si no está seteado
if [[ -z "${APPLE_ID-}" ]]; then
  echo -n "Por favor, ingresa tu Apple ID (email): "
  read -r APPLE_ID
fi

# Establecer APPLE_TEAM_ID por defecto si no está seteado
if [[ -z "${APPLE_TEAM_ID-}" ]]; then
  APPLE_TEAM_ID="SRVK53YUSF"
fi

echo
echo "Resumen de configuración:"
echo "DEVELOPER_ID: $DEVELOPER_ID"
echo "APPLE_ID: $APPLE_ID"
echo "APPLE_TEAM_ID: $APPLE_TEAM_ID"
echo
echo -n "¿Está correcto? (Y/n): "
read -r confirm
confirm=${confirm:-Y}

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Abortando por usuario."
  exit 1
fi

echo
echo "Ejecutando 'make package'..."
DEVELOPER_ID="$DEVELOPER_ID" APPLE_ID="$APPLE_ID" APPLE_TEAM_ID="$APPLE_TEAM_ID" make package

echo
echo "Ejecutando 'make reveal'..."
make reveal

echo
echo -n "¿Deseas instalar la aplicación en /Applications? (y/N): "
read -r install_confirm
install_confirm=${install_confirm:-N}

if [[ "$install_confirm" =~ ^[Yy]$ ]]; then
  echo "Ejecutando 'make install'..."
  make install
else
  echo "Instalación omitida."
fi

echo
read -rp "Presiona Enter para salir..."
