# catalog

Qué servicios hay en la organización, de quién son, en qué están hechos y dónde corren. Responde a la pregunta que más cuesta en una empresa con muchos equipos: "¿esto de quién es?".

`catalog.yml` lo escribe `platformctl` (repo `platform`) al crear cada servicio. Una fila por servicio:

| Campo | Ejemplo |
|---|---|
| `nombre` | `pagos-ledger` |
| `team` | `pagos` |
| `tecnologia` | `go` · `python` |
| `nube` / `region` | `azure` · `eastus` |
| `autor` / `origen` | quién lo pidió; `persona` o `agente` |
| `issue` | enlace a la petición |

En el Módulo 2 este archivo se publica como página con GitHub Pages.
