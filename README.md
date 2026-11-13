# Samsung A30: compilación remota de diagnóstico

Este paquete compila **solo el kernel** en un servidor de GitHub Actions. Las
fuentes, herramientas y archivos grandes permanecen en el servidor. No instala
Ubuntu en tu PC, no se conecta al teléfono y no flashea nada.

## Preparar el repositorio

1. En tu cuenta de GitHub, crea un repositorio **público** vacío para este trabajo.
2. Sube el contenido de esta carpeta, incluyendo `.github`, `scripts` y `config`.
   Subir solamente el ZIP no instala el flujo de Actions.
3. En **Actions**, selecciona **A30 - kernel experimental** y ejecútalo manualmente.
   Empieza con `original-241a585` para obtener una referencia de compilación.
4. Si termina, descarga el artefacto de esa ejecución. Si falla, conserva el
   registro de compilación y el artefacto parcial para corregir el error.

Los runners estándar de Actions para repositorios públicos tienen cómputo
gratuito según la documentación de GitHub. Esta receta no solicita runners de
pago, no activa ejecuciones por cada push y conserva artefactos durante 3 días.
El acceso efectivo a Actions y las cuotas de tu cuenta deben comprobarse allí.

## Qué produce

- `Image`: imagen Linux del kernel; **no es un boot.img flasheable**.
- `vmlinux` y `System.map`: símbolos para analizar los panics.
- Configuración, diferencias de configuración, versiones y SHA256.
- `build.log`, también cuando la compilación falla.

El `boot.img` se prepararía después en el PC usando el ramdisk original de
PixelOS, verificando tamaño y cabecera. No es necesario subir el boot del
teléfono ni información de tu cuenta Yape a GitHub.

## Límites importantes

La receta se ha revisado y validado localmente en sintaxis; todavía no se ha
ejecutado en GitHub. Puede requerir ajustes de compilación para este kernel.

La primera revisión es `241a585e09e4a5d4c416b9a16c683cb4af6460e9`, identificada
por el banner del boot original de PixelOS. La segunda es la punta examinada de
EurekaV3, `55d8ab30547ef33dd3f900fec5f8f98f764b3352`. Está fijada por commit,
no cambia automáticamente si el mantenedor mueve la rama.

Se usa AOSP Clang 20.0.0 r547379, fijado al commit
`70a12c4fe88940ab2b0e6d763492dffa2f07e15a`, cuya disponibilidad pública se
comprobó. El boot original declara Clang 21.0.0; **esto es una diferencia de
compilación y no una reproducción binaria idéntica del original**.

La opción posterior incorpora los cambios publicados del mantenedor, pero
ninguna opción ha demostrado corregir los panics al abrir repetidamente Yape.
No se presenta el resultado como kernel estable ni como solución al aviso de
seguridad de Yape. No se cambia automáticamente DTB/DTBO; su compatibilidad con
la variante física sigue pendiente de validar.

## Fuentes

- https://github.com/Shaheddan/android_kernel_samsung_exynos7885
- https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/
- https://docs.github.com/en/billing/concepts/product-billing/github-actions

El código del kernel conserva sus licencias y autoría originales. La revisión,
configuración y receta de compilación se incluyen para hacer trazable el resultado.
