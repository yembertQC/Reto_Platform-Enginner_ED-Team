# Política de seguridad

## ⚠️ Antes de reportar: vulnerabilidades intencionales

Este repositorio es **material de un curso de Ingeniería de Plataforma**. El archivo `src-go/main.go` contiene **a propósito** estas vulnerabilidades para que CodeQL las detecte:

| Tipo | Ubicación |
|------|-----------|
| Credenciales en el código (CWE-798) | Constantes `API_KEY`, `API_SECRET`, `DB_PASSWORD` |
| SQL Injection (CWE-89) | Endpoint `/search` |
| Command Injection (CWE-78) | Endpoint `/exec` |

**No hace falta reportarlas.** Están explicadas en la página [Seguridad](https://github.com/yembertQC/Reto_Platform-Enginner_ED-Team/wiki/10-Seguridad) de la wiki.

## Versiones con soporte

| Versión | Soporte |
|---------|---------|
| Rama `main` (última release) | ✅ |
| Releases anteriores | ❌ |

## Cómo reportar una vulnerabilidad

Si encuentras un problema de seguridad **real** (en los pipelines, en los scripts de despliegue, en la configuración de la nube o una fuga de credenciales):

1. **No abras un issue público** ni lo comentes en un Pull Request.
2. Usa el reporte privado de GitHub: pestaña **Security → Report a vulnerability** ([enlace directo](https://github.com/yembertQC/Reto_Platform-Enginner_ED-Team/security/advisories/new)).
3. Incluye:
   - descripción del problema y su impacto,
   - pasos para reproducirlo,
   - archivos, workflows o recursos afectados,
   - si lo conoces, una propuesta de solución.

## Qué puedes esperar

| Paso | Plazo orientativo |
|------|-------------------|
| Acuse de recibo | 5 días hábiles |
| Primera evaluación | 10 días hábiles |
| Corrección o mitigación | Según la gravedad |

Es un proyecto educativo mantenido con buena voluntad: los plazos son orientativos.

## Si se filtra un secreto

Si ves en el repositorio una clave o contraseña real (no las de ejemplo de `main.go` ni de `doc/*-example.json`):

1. Repórtalo por el canal privado de arriba.
2. La persona mantenedora **revocará y rotará** la credencial de inmediato. Borrarla del código no basta, porque sigue en el historial de git.
