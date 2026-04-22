# Ruteando - Optimización de Logística de Última Milla

Ruteando es una solución móvil diseñada para automatizar y optimizar la planificación de rutas de reparto, específicamente orientada a empresas de agua purificada. El proyecto busca reducir la ineficiencia de los procesos manuales y disminuir los costos operativos relacionados con el consumo de combustible mediante algoritmos de optimización.

## Equipo de Proyecto - Grupo 12

| Integrante | Rol | Responsabilidad Principal |

| Julio Vega | Scrum Master | Gestión de agilidad, procesos y facilitación técnica |
| Sebastián Rodríguez | Product Owner | Definición de valor de negocio y priorización de backlog |
| Francisca Meyer | Developer | Desarrollo de interfaz y lógica de aplicación |
| Ignacio Mendoza | Developer | Desarrollo de interfaz y lógica de aplicación |

---

## Estado del Proyecto: Sprint 1 

El sistema ha pasado de una fase de prototipado estático a una arquitectura conectada con servicios en la nube. Se ha completado la integración de seguridad base.

### Módulo de Acceso (HU08 - Acceso y Registro)
La autenticación ahora es gestionada íntegramente por Google Firebase Authentication. El sistema permite el registro de nuevos usuarios y la validación de credenciales existentes contra una base de datos real.

#### Credenciales de Prueba (Testing):
* Usuario: admin@ruteando.cl
* Contraseña: ruteando2026

---

## Guía de Sincronización para Desarrolladores

Para asegurar que el entorno de desarrollo local funcione correctamente con la nueva integración de Firebase, cada integrante debe seguir estos pasos en su terminal:

1. Actualizar repositorio local:
   git pull origin main

2. Descargar dependencias de Firebase y Flutter:
   flutter pub get

3. Configuración de Windows (Solo la primera vez):
   Si el sistema arroja errores de enlaces simbólicos (symlinks), se debe activar el Modo Programador en la configuración de Windows mediante el comando:
   start ms-settings:developers

---

## Tecnologías y Herramientas

* Lenguaje de programación: Dart
* Entorno de desarrollo: Flutter Framework
* Servicios de Backend: Google Firebase (Auth)
* Control de versiones: Git / GitHub
* Marco de trabajo: Metodología Scrum