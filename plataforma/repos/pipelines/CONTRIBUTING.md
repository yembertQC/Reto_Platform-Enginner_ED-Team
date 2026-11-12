# Contribuir a pipelines

Este repo es InnerSource: cualquier team puede proponer un cambio, el team `platform` lo revisa (`CODEOWNERS`).

1. Abre un pull request contra `main` explicando qué necesita tu servicio.
2. Si el cambio es compatible (un input nuevo con valor por defecto, un paso más), al fusionarlo se mueve el tag:
   ```bash
   git tag -f v1 && git push -f origin v1
   ```
3. Si rompe el contrato (quita o renombra un input, cambia el puerto), va en `v2`. `v1` sigue funcionando para quien no migre.

No subas credenciales ni valores de una nube concreta: van en secretos y variables de la organización.
