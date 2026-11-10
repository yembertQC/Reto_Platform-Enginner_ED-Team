## 📝 ¿Qué cambia?

<!-- Describe el cambio en 1-3 frases. Enlaza el issue si existe: "Closes #123" -->

## 🎯 Tipo de cambio

- [ ] ✨ `feat` — funcionalidad nueva
- [ ] 🐛 `fix` — corrección
- [ ] 📖 `docs` — documentación (`doc/`)
- [ ] ⚙️ `ci` — workflows o scripts de despliegue
- [ ] 📦 `deps` — dependencias
- [ ] ♻️ `refactor` / 🧪 `test`

## 🧭 Áreas afectadas

- [ ] 🐍 App Python (`src/`)
- [ ] 🐹 App Go (`src-go/`)
- [ ] ⚙️ Pipelines (`.github/workflows/`) o `scripts/`
- [ ] ☁️ Infraestructura (Azure / AWS)
- [ ] 📖 Documentación / wiki

## ✅ Checklist

- [ ] Probé el cambio en local (`go test`, `docker run`, `smoke-test.sh`...).
- [ ] Los endpoints `/` y `/health` siguen respondiendo lo esperado.
- [ ] No hay secretos, claves ni datos personales en el código ni en los logs.
- [ ] Si toqué workflows: actions fijadas por **SHA** con `# vX.Y.Z` y `permissions` mínimos por job.
- [ ] Actualicé la documentación de `doc/` afectada **en este mismo PR**.
- [ ] Los checks de CI (CodeQL, dependency review, container scan) están en verde o expliqué los hallazgos abajo.

## 🔍 Cómo probarlo

<!-- Pasos para que quien revise pueda verificarlo. -->

## 📸 Evidencias / notas para la revisión

<!-- Enlace a la ejecución de Actions, URL desplegada, salida de curl, hallazgos de seguridad aceptados... -->
