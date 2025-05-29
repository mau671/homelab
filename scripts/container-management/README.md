# Container Management Scripts

Este directorio contiene scripts para la gestión y administración de contenedores LXC en Proxmox VE.

## 📁 Contenido

### Scripts Principales
- **`resize-lxc.sh`** - Script para redimensionar discos de contenedores LXC

## 🎯 Funcionalidades

### resize-lxc.sh
Script profesional para redimensionar discos de contenedores LXC con:
- ✅ Interfaz interactiva con validación de entrada
- ✅ Detección automática de contenedores y discos
- ✅ Verificación de espacio disponible
- ✅ Respaldos automáticos antes de cambios
- ✅ Salida con colores y formato profesional
- ✅ Manejo completo de errores

## 📋 Uso

```bash
# Modo interactivo
sudo ./resize-lxc.sh

# El script te guiará a través de:
# 1. Selección de contenedor
# 2. Verificación de disco actual
# 3. Especificación del nuevo tamaño
# 4. Confirmación de cambios
# 5. Ejecución del redimensionamiento
```

## ⚠️ Consideraciones Importantes

- **Respaldos:** El script crea respaldos automáticamente
- **Validación:** Verifica espacio disponible antes de proceder
- **Contenedores en ejecución:** Puede trabajar con contenedores activos
- **Rollback:** Capacidad de revertir cambios si es necesario

## 🔧 Requisitos

- Proxmox VE host
- Permisos de root
- Contenedores LXC existentes
- Espacio suficiente en el almacenamiento
