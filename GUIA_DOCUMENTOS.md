# Documentos privados y versiones

Ejecuta `supabase/17_documentos_restringidos.sql` y después `supabase/19_corregir_carga_documentos.sql` en el SQL Editor de Supabase y actualiza Documentos. Si ya ejecutaste el 17, aplica únicamente el 19. La corrección elimina una referencia ambigua al nombre del proyecto en la política de carga, manteniendo el acceso privado. Ambos admiten volver a ejecutarse.

1. En Documentos, selecciona el proyecto y pulsa **Cargar documento**.
2. Añade título, descripción y un archivo: PDF, DOCX, XLSX, JPG, PNG o TXT, hasta 20 MB.
3. Elige personas del equipo, un área o **Responsables de aprobar materiales**. Las opciones se suman: cualquiera de esos destinatarios con acceso al proyecto puede consultar y descargar el documento.
   El formulario permite buscar por nombre o cargo, seleccionar todo el equipo actual, elegir los resultados de una búsqueda y quitar destinatarios individualmente. La lista muestra diez personas por página y conserva la selección al cambiar de página. El resumen de acceso reúne las personas y grupos elegidos antes de cargar el archivo. Seleccionar todos incluye el equipo actual; los colaboradores que se incorporen después no se añaden automáticamente.
4. El área incluye usuarios con una asignación de rol activa de alcance área. Un usuario con rol general no se incorpora a un área automáticamente: selecciónalo como persona si corresponde.
5. El autor, el jefe activo del proyecto y los administradores de la organización también pueden gestionarlo. Sin destinatarios adicionales, el documento queda reservado para ellos.

Los responsables de aprobación de materiales solo acceden por esa condición cuando se selecciona expresamente esa opción. Reciben los documentos quienes tienen `material.approve` o `approval.decide` en el proyecto. Los lectores restantes pueden descargar, pero no dar visto bueno.

## Correcciones

En **Ver documento e historial**, el responsable puede dar visto bueno o solicitar corrección con una observación obligatoria. Solicitar corrección habilita una nueva carga para sus destinatarios. También puede habilitar o deshabilitar esa carga manualmente.

La versión corregida se añade al historial; conserva todos los archivos anteriores. La carga de destinatarios vuelve a cerrarse después de entregar la nueva versión y el documento vuelve a pendiente de revisión. El autor, jefe y administrador pueden cargar una versión como responsables de gestión.

Cada revisión comprueba que se esté revisando la última versión. Si otra persona acaba de subir una corrección, es necesario actualizar antes de aprobar.

El acceso se aplica en la base de datos y en Storage. Las descargas usan enlaces temporales de 60 segundos. Los archivos del nuevo módulo no se publican ni se almacenan en el antiguo bucket general. Los documentos del esquema anterior no se trasladan automáticamente.

## Prueba recomendada

Carga una cotización y selecciona únicamente al equipo de aprobación de materiales. Comprueba con una cuenta destinataria que puede descargarla y con otro colaborador que no aparece. Solicita corrección, carga una segunda versión desde la cuenta destinataria y apruébala desde el responsable. El historial debe conservar ambas versiones.
