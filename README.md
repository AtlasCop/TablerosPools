# Aqua Bruma — Tablero de Equipos

Herramienta web para diseñar instalaciones de piscinas y spas: arrastra equipos sobre un tablero, arma la cotización automáticamente, genera un PDF de venta para el cliente y organiza el trabajo del equipo en un tablero Kanban.

No requiere instalación, servidor propio ni build: son archivos HTML que corren directamente en el navegador.

## Cómo abrir la aplicación

1. Abre `index.html` en el navegador (doble clic, o arrástralo a una pestaña).
2. Crea una cuenta local (usuario + contraseña + pregunta de seguridad) o inicia sesión si ya tienes una.
3. Se abre `tablero.html`, la herramienta principal.

> El acceso es solo local a ese navegador: no hay backend ni servidor de autenticación. Si borras los datos del navegador, se pierde la cuenta creada (no las cotizaciones ni el inventario, que se guardan aparte — ver [Dónde vive la información](#dónde-vive-la-información)).

## Estructura del proyecto

```
Tablero-Piscinas/
├── index.html      # Login / registro (no es la herramienta en sí)
├── tablero.html     # La aplicación completa: tablero, inventario, cotizador, Kanban
└── assets/
    ├── logo.png                # Logo de Aqua Bruma (toolbar y PDF de cotización)
    └── hero-pool-twilight.jpg  # Imagen de fondo del login
```

Todo el código de `tablero.html` es un único archivo (HTML + Tailwind vía CDN + JavaScript) — no hay pasos de compilación.

## Las tres pestañas

### 1. Productos
El flujo principal para armar una propuesta:

- **Panel de categorías** (barra izquierda): 22 categorías de equipos de piscina/spa (motobombas, filtración, iluminación, calefacción, automatización, robots de aseo, etc.).
- **Inventario por categoría**: cada categoría tiene sus propios objetos, con imagen (fondo eliminado y recortado automáticamente al subirla), código autogenerado, sublínea, descripción comercial y valor de venta sin IVA. Se pueden agregar, editar y eliminar objetos libremente — quedan guardados en el navegador.
- **Buscador y filtro de precio** por categoría (código, sublínea o descripción; rango de precio con banda deslizante).
- **Tablero de diseño**: arrastra objetos desde el inventario hacia el lienzo, muévelos, rótalos, duplícalos, agrega flechas y líneas, usa la cuadrícula, la mano para desplazar la vista, deshacer/rehacer (Ctrl+Z), zoom, bloqueo de edición.
- **Cotización en vivo** (barra derecha): al arrastrar un objeto al tablero, se suma automáticamente a su categoría de cotización correspondiente (26 categorías fijas del formato real de cotización, no las 22 del inventario — cada objeto sabe a cuál pertenece, y se puede reclasificar por objeto). La cantidad de cada línea se puede editar a mano.
- **Guardar el tablero**: con nombre, en la lista "Mis tableros" (se puede eliminar), o como archivo `.json` descargable para retomarlo en otro computador. También hay un botón "Compartir" que genera un enlace con el tablero comprimido dentro.
- **Exportar** el tablero como imagen PNG o PDF.
- **Generar cotización**: abre un documento de cotización elegante para el cliente (con logo, datos de contacto, nota personalizada), exportable a PDF, con botones para enviarlo por correo o WhatsApp (el PDF se descarga y el mensaje queda redactado y listo — adjuntar el archivo es manual, no hay backend que lo haga automático).

### 2. Panel Cotizaciones
Historial de todas las cotizaciones que se han generado (cada vez que se descarga el PDF o se envía por correo/WhatsApp queda un registro). Cada una muestra cliente, proyecto, fecha, cantidad de ítems y total, con tres botones de estado que se pueden cambiar en cualquier momento:

- **Pendiente**
- **Autorizada**
- **Facturada**

También se puede eliminar una cotización del historial.

### 3. Tablero Kanban
Tablero de tareas para organizar el trabajo del equipo, con cuatro columnas fijas: **Por hacer → En progreso → En revisión → Hecho**.

- **Equipo**: agrega personas con nombre y un color identificador (avatar con iniciales).
- **Tareas**: título, descripción, prioridad (baja/media/alta), fecha límite opcional y responsable asignado.
- Las tarjetas se mueven **arrastrándolas** entre columnas, o editando la tarea y cambiando la columna manualmente.

## Dónde vive la información

Todo se guarda **localmente en el navegador**, sin servidor propio:

| Dato | Dónde |
|---|---|
| Cuenta de acceso (usuario/contraseña) | `localStorage` |
| Tableros guardados ("Mis tableros") | `localStorage` |
| Inventario de objetos (imágenes, precios, etc.) | IndexedDB |
| Historial de cotizaciones generadas | IndexedDB |
| Tareas y equipo del Kanban | IndexedDB |

Esto significa que los datos son **por navegador y por computador** — no se sincronizan solos entre dispositivos. Para llevar un tablero a otro equipo, usa "Guardar archivo" (descarga un `.json`) y luego "Abrir archivo" en el otro computador, o el botón "Compartir".

## Tecnologías usadas (todas por CDN, sin instalación)

- [Tailwind CSS](https://tailwindcss.com/) — estilos
- [Fabric.js](http://fabricjs.com/) — el lienzo/tablero interactivo
- [LZString](https://pieroxy.net/blog/pages/lz-string/index.html) — compresión de los enlaces para compartir
- [jsPDF](https://github.com/parallax/jsPDF) + [html2canvas](https://html2canvas.hertzen.com/) — generación de los PDF (tablero y cotización)

## Repositorio

`https://github.com/AtlasCop/TablerosPools`
