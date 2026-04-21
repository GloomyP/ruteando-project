#  Ruteando - Optimización de Logística de Última Milla

**Ruteando** es una solución móvil diseñada para automatizar y optimizar la planificación de rutas de reparto, específicamente orientada a empresas de agua purificada. El proyecto surge como respuesta a la ineficiencia de los procesos manuales y al constante alza en los costos de combustible.

##  Equipo de Proyecto (Grupo 12)

* **Julio Vega** - Scrum Master (Facilitador de agilidad y gestión técnica)
* **Sebastián Rodríguez** - Product Owner (Responsable del valor de negocio)
* **Francisca Meyer** - Developer (Ejecución y desarrollo técnico)
* **Ignacio Mendoza** - Developer (Ejecución y desarrollo técnico)

---

##  Sprint Actual: Sprint 1 (Construcción de Base)
Actualmente nos encontramos en la fase de implementación de la arquitectura base y el sistema de seguridad.

###  Módulo de Acceso (HU08 - Acceso y Registro)
Para facilitar la revisión y el testing del sistema, se han configurado credenciales de prueba que permiten validar el flujo completo de autenticación.

#### Credenciales de Prueba:
* **Correo Electrónico:** `admin@ruteando.cl`
* **Contraseña:** `ruteando2026`

---

##  Casos de Prueba Disponibles

El sistema permite validar los siguientes escenarios según los criterios de aceptación definidos:

1.  **Validación de Formato:** El sistema detecta si el texto ingresado no cumple con el estándar de correo electrónico (ej. falta de `@` o dominio).
2.  **Autenticación Exitosa (Ruta Feliz):** Al ingresar las credenciales mencionadas arriba, el sistema procesa la solicitud (2 seg) y confirma el acceso exitoso.
3.  **Control de Errores:** Si se ingresan datos incorrectos, el sistema despliega un mensaje de advertencia: *"Credenciales incorrectas"*.
4.  **Feedback de Usuario:** Se ha implementado un indicador de carga (`CircularProgressIndicator`) para evitar múltiples clics durante la espera de respuesta del servidor.

---

##  Tecnologías Utilizadas
* **Lenguaje:** Dart
* **Framework:** Flutter (Multiplataforma)
* **Control de Versiones:** Git / GitHub
* **Metodología:** Scrum
