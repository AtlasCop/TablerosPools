# Aqua Bruma — Tablero de Equipos

Herramienta web para diseñar instalaciones de piscinas y spas: arrastra equipos sobre un tablero 2D, planea su ubicación real en 3D, arma la cotización automáticamente, genera un PDF de venta para el cliente y organiza el trabajo del equipo en un tablero Kanban.

No requiere instalación ni build: son archivos HTML que corren directamente en el navegador, con Supabase como base de datos en la nube compartida por todo el equipo.

## Cómo abrir la aplicación

1. Abre `index.html` en el navegador (doble clic, o arrástralo a una pestaña).
2. Inicia sesión, o crea una cuenta nueva con tu correo real.
3. Si es una cuenta nueva, queda **pendiente de aprobación** — un administrador debe aprobarla y asignarle un rol antes de que puedas entrar (pestaña "Usuarios", ver abajo).
4. Una vez aprobado, se abre `tablero.html`, la herramienta principal.

> El acceso es real (Supabase Auth: correo + contraseña, recuperación de contraseña por correo), no solo de este navegador — puedes entrar desde cualquier computador con la misma cuenta.

## Usuarios y permisos

Cada cuenta tiene un **rol**, asignado por un administrador desde la pestaña **"Usuarios"** (solo visible para administradores):

| Función | Administrador | Editor | Consulta |
|---|---|---|---|
| Ver todo (inventario, cotizaciones, Kanban, 3D) | ✅ | ✅ | ✅ |
| Crear/editar/eliminar inventario | ✅ | ✅ | ❌ |
| Crear y ver cotizaciones, cambiar su estado | ✅ | ✅ | ✅ |
| Eliminar cotizaciones | ✅ | ✅ | ❌ |
| Crear/editar/eliminar tareas y equipo del Kanban | ✅ | ✅ | ❌ |
| Agregar/editar/eliminar en el Tablero 3D | ✅ | ✅ | ❌ |
| Aprobar usuarios y asignar roles | ✅ | ❌ | ❌ |

Estos permisos se hacen cumplir **en la base de datos** (políticas de Row Level Security en Supabase), no solo ocultando botones en la pantalla — aunque alguien intentara saltarse la interfaz, la base de datos rechaza la operación si su rol no la permite.

**Primer administrador:** ver `supabase-schema.sql`, sección final — es un paso manual de una sola vez (nadie puede aprobarse a sí mismo la primera vez).

## Estructura del proyecto

```
Tablero-Piscinas/
├── index.html            # Login / registro / recuperar contraseña (no es la herramienta en sí)
├── tablero.html           # La aplicación completa: tablero 2D, 3D, inventario, cotizador, Kanban, usuarios
├── supabase-schema.sql   # Esquema completo de la base de datos (tablas, permisos, roles)
└── assets/
    ├── logo.png                # Logo de Aqua Bruma (toolbar y PDF de cotización)
    └── hero-pool-twilight.jpg  # Imagen de fondo del login
```

Todo el código de `tablero.html` es un único archivo (HTML + Tailwind vía CDN + JavaScript) — no hay pasos de compilación.

## Las pestañas

### 1. Productos
El flujo principal para armar una propuesta:

- **Panel de categorías** (barra izquierda, redimensionable): 22 categorías de equipos de piscina/spa (motobombas, filtración, iluminación, calefacción, automatización, robots de aseo, etc.).
- **Inventario por categoría**: cada categoría tiene sus propios objetos, con imagen (fondo eliminado y recortado automáticamente al subirla — se generan dos versiones: una para el ícono 2D y otra cuadrada para usar como textura en el Tablero 3D), código autogenerado, sublínea, descripción comercial y valor de venta sin IVA. La pestaña "Inventario" reúne todos los objetos de todas las categorías en una sola tabla, con búsqueda, filtro y orden por columna, además de dos botones (**Eliminados**: muestra el rastro de todo lo que se ha borrado, con quién lo borró y cuándo; **Reiniciar numeración**, solo administradores: pone en 0 el consecutivo de código de cada categoría, para que los próximos objetos creados vuelvan a empezar en 0001).
- **Buscador y filtro de precio** por categoría (código, sublínea o descripción; rango de precio con banda deslizante).
- **Tablero de diseño 2D**: arrastra objetos desde el inventario hacia el lienzo, muévelos, rótalos, duplícalos, agrega flechas y líneas, usa la cuadrícula, la mano para desplazar la vista, deshacer/rehacer (Ctrl+Z), zoom, bloqueo de edición.
- **Cotización en vivo** (barra derecha, redimensionable): al arrastrar un objeto al tablero, se suma automáticamente a su categoría de cotización correspondiente (26 categorías fijas del formato real de cotización, no las 22 del inventario). La cantidad de cada línea se puede editar a mano.
- **Guardar el tablero**: con nombre, en la lista "Mis tableros" (se puede eliminar), o como archivo `.json` descargable, o con el botón "Compartir" (enlace con el tablero comprimido dentro).
- **Exportar** el tablero como imagen PNG o PDF.
- **Generar cotización**: documento de cotización elegante para el cliente (logo, datos de contacto, nota personalizada, responsable asignado), exportable a PDF, con botones para enviarlo por correo o WhatsApp (el PDF se descarga y el mensaje queda redactado — adjuntar el archivo es manual, no hay backend que lo haga automático).

### 2. Panel Cotizaciones
Historial de todas las cotizaciones generadas. Cada una muestra cliente, proyecto, fecha, ítems y total, con:

- **Semáforo** de seguimiento: verde (menos de 7 días), amarillo (7-9 días), rojo (10 días o más sin cerrarse).
- **Responsable asignado**, con botón de recordatorio por WhatsApp una vez se pone en rojo.
- Tres botones de estado: **Pendiente / Autorizada / Facturada**, y opción de eliminar.
- **Descargar PDF** (ícono de documento): vuelve a generar el PDF de esa cotización exacta, tal como quedó guardada — incluida la hoja de fichas técnicas — sin importar qué haya cambiado desde entonces en el tablero o el inventario.
- Cada vez que se genera una cotización con un responsable asignado, se crea automáticamente una tarea de seguimiento para esa persona en el Tablero Kanban (columna "Por hacer").

### 3. Tablero Kanban
Tareas del equipo en cuatro columnas con color: **📋 Por hacer → 🚀 En progreso → 🔍 En revisión → 🎉 Hecho**.

- **Equipo**: personas con nombre, cargo, foto de perfil (o iniciales de color) y teléfono.
- **Tareas**: título, descripción, prioridad (baja/media/alta, con acento de color en la tarjeta), fecha límite y responsable.
- **Comentarios de actualización** por tarea, con foto del autor y fecha/hora exacta.
- Las tarjetas se mueven arrastrándolas entre columnas o editando la tarea.
- Generar una cotización (ver Panel Cotizaciones) crea aquí sola una tarea de seguimiento para el responsable asignado.

### 4. Tablero 3D
Planeación real de la ubicación de los equipos en el cuarto de máquinas:

- Defines el **tamaño real del cuarto** (ancho, profundo, alto en metros).
- Agregas equipos del mismo inventario — aparecen como cajas con la foto real del producto (o el color de su categoría si no tiene foto).
- Los mueves, giras y escalas directamente con el mouse (gizmo tipo editor 3D), con las medidas en centímetros actualizándose en vivo.
- Cámara libre o vista superior para revisar la posición exacta.

### 5. Usuarios (solo administradores)
Aprobar o rechazar solicitudes de acceso nuevas, asignar/cambiar el rol de cualquiera, o quitarle el acceso.

## Dónde vive la información

| Dato | Dónde |
|---|---|
| Cuentas, aprobación y roles | Supabase Auth + tabla `profiles` |
| Inventario, cotizaciones, Kanban, Tablero 3D | Supabase (compartido por todo el equipo, en tiempo real) |
| Tableros guardados ("Mis tableros") | `localStorage` (por navegador, no compartido todavía) |
| Preferencias de ancho de paneles/columnas | `localStorage` (por navegador) |

Para llevar un **tablero 2D** puntual a otro computador, usa "Guardar archivo" y luego "Abrir archivo", o el botón "Compartir" — el inventario, cotizaciones, Kanban y Tablero 3D ya se ven iguales en cualquier computador sin hacer nada extra.

## Tecnologías usadas (todas por CDN, sin instalación)

- [Tailwind CSS](https://tailwindcss.com/) — estilos
- [Fabric.js](http://fabricjs.com/) — el lienzo/tablero 2D interactivo
- [Three.js](https://threejs.org/) — el Tablero 3D
- [Supabase](https://supabase.com/) (`@supabase/supabase-js`) — base de datos, autenticación y permisos
- [LZString](https://pieroxy.net/blog/pages/lz-string/index.html) — compresión de los enlaces para compartir
- [jsPDF](https://github.com/parallax/jsPDF) + [html2canvas](https://html2canvas.hertzen.com/) — generación de los PDF (tablero y cotización)

## Repositorio

`https://github.com/AtlasCop/TablerosPools`
