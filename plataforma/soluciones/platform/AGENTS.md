# Cómo pide un servicio un agente de IA

Instrucciones para agentes (GitHub Copilot en modo agente, Claude Code u otros) que piden algo a la plataforma en nombre de una persona. La plataforma trata la petición igual que la de una persona: mismo formulario, mismas reglas, misma respuesta. Lo único distinto es que queda marcada como de un agente, para poder medirlo.

## Pedir un servicio nuevo

1. Lee `.github/ISSUE_TEMPLATE/nuevo-servicio.yml`: sus etiquetas (`label`) son los encabezados del issue y sus `options` son los únicos valores válidos.
2. Lee `config/plataforma.json`: la convención de nombres (`nombre_regex`), las regiones de cada nube y los tamaños permitidos. No pidas nada que no esté ahí.
3. Si te falta un dato (team dueño, nube, ambiente), pregúntaselo a la persona. No lo inventes.
4. Crea el issue en este repo con el cuerpo en el mismo formato que genera el formulario y **dos etiquetas**: `platform/pending` (la que dispara la plataforma) y `platform/agent` (quién lo pidió):

```bash
gh issue create --repo <org>/platform \
  --title "[servicio]: pagos-conciliacion" \
  --label platform/pending --label platform/agent \
  --body "### Nombre del repositorio

pagos-conciliacion

### Team dueño

pagos

### Tecnología

python

### Nube

azure

### Región

eastus

### Ambiente

dev

### Tamaño

pequeño

### Para qué es

Concilia los pagos del banco cada noche."
```

5. Sigue el issue: `platformctl` contesta en él. Si lo rechaza, el comentario dice qué regla no se cumplió; corrige editando el cuerpo del issue (se vuelve a evaluar) y no abras otro.

## Lo que no debes hacer

- Crear repos, teams, variables o secretos directamente con la API: todo pasa por el issue.
- Pedir `production` o un tamaño no permitido para "ir más rápido": la plataforma lo rechazará o lo dejará esperando aprobación.
