# XalgoExplorer

XalgoExplorer es un gestor de archivos nativo para macOS, disenado para usuarios que cambian de Windows a macOS.

Su objetivo es mantener flujos de trabajo de archivos claros y familiares, adaptados a una aplicacion nativa de macOS.

## Caracteristicas

- Espacio de trabajo con multiples paneles para navegar varias carpetas.
- Acciones conocidas: atras, adelante, subir, actualizar, nueva carpeta, nuevo archivo, cortar, copiar y pegar.
- Arrastrar y soltar con reglas similares a Finder: mover en el mismo disco, copiar entre discos diferentes.
- Barra lateral compacta para carpetas comunes, accesos directos, discos montados y ubicaciones de red.
- Navegacion con teclado, seleccion con mouse y seleccion por area.
- Etiquetas y ayudas emergentes en varios idiomas.
- Paquete DMG para instalacion en macOS.

## Version candidata

`v0.1.1-candidate` esta dirigida a Apple Silicon con macOS 14 o posterior.

Descarga el DMG desde GitHub Releases y arrastra `xAlgo Explorer.app` a `Applications`.

## Notas de version

### v0.1.1-candidate

- Corrige datos internos antiguos de arrastrar y soltar para que una accion cancelada no pueda mover otro archivo mas tarde.
- Agrega validacion de cambio de nombre y rechaza entradas inseguras como `../file` o `a/b`.
- Pegar un archivo cortado en su carpeta original ahora es no-op y no crea duplicados.
- Agrega copia y pegado de archivos compatibles con Finder mediante el portapapeles del sistema.
- Agrega un boton visible para cerrar busqueda y soporte de Escape, para que las flechas vuelvan a navegar la lista de archivos.
- Elimina el dispositivo de red falso codificado y muestra un estado de red vacio hasta implementar descubrimiento real.
- Actualiza metadatos de la version candidata, nombre del DMG, notas del README y pruebas de regresion.

### v0.1.0-candidate

Primera version candidata publica con interfaz nativa de macOS, navegacion multipanel, operaciones de arrastrar y soltar, navegacion con teclado, ayudas multilingues y DMG firmado para Apple Silicon.

## Licencia

MIT License.
