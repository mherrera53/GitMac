# Firma, Notarización y Empaquetado de la App

Este documento explica cómo firmar, notarizar y empaquetar la app usando el script y el Makefile proporcionados.

---

## Prerrequisitos

- Tener Xcode y las herramientas de línea de comando instaladas.
- Contar con un certificado válido de Apple Developer.
- Crear un perfil de keychain para notarización (se explica más abajo).
- Variables de entorno configuradas correctamente.

---

## Variables de Entorno

| Variable       | Descripción                                                                                          | Ejemplo                                    |
|----------------|--------------------------------------------------------------------------------------------------|--------------------------------------------|
| `APP_NAME`     | Nombre de la app                                                                                   | MyApp                                      |
| `SCHEME`       | Esquema de compilación                                                                             | MyAppScheme                                |
| `CONFIGURATION`| Configuración de build (Debug, Release)                                                           | Release                                    |
| `BUNDLE_ID`    | Identificador del paquete (Bundle Identifier)                                                     | com.miempresa.myapp                         |
| `DEVELOPER_ID` | Identidad para firmar (Developer ID Application)                                                  | Developer ID Application: Tu Nombre (SRVK53YUSF) |
| `APPLE_ID`     | Apple ID usado para notarización                                                                   | tu.email@ejemplo.com                        |
| `APPLE_TEAM_ID`| ID del equipo Apple                                                                                | SRVK53YUSF                                 |
| `KEYCHAIN_PROFILE` | Nombre del perfil para notarización en el keychain (puede ser AC_PASSWORD)                     | AC_PASSWORD                                |

---

## Comandos de Ejemplo para Configurar Variables

```bash
export DEVELOPER_ID="Developer ID Application: Tu Nombre (SRVK53YUSF)"
export APPLE_ID="tu.email@ejemplo.com"
export APPLE_TEAM_ID="SRVK53YUSF"
