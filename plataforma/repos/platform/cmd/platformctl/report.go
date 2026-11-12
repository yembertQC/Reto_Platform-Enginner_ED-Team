package main

import "fmt"

// report le contesta a quien pidió el servicio y cierra el issue.
func report(issue issueRef, req Request, env Env, res Result) {
	issue.comment(fmt.Sprintf(`✅ **Listo: [%s](%s)**

| | |
|---|---|
| Plantilla | %s |
| Team dueño | @%s/%s (write y CODEOWNER) |
| Nube | %s · %s |
| Ambiente | %s%s |
| Tamaño | %s |
| Catálogo | añadido como %s |

El primer despliegue ya está en marcha: [ver en Actions](%s). Cuando termine, la URL del servicio aparece en el resumen de la ejecución.`,
		res.Repo, res.RepoURL, req.Tecnologia, env.Org, req.Team, req.Nube, req.Region,
		req.Ambiente, protectedNote(res, env), req.Tamano, res.Origen, res.ActionsURL))
	issue.setLabels(append([]string{"platform/done"}, agentLabel(env)...)...)
	issue.close()
}

func protectedNote(res Result, env Env) string {
	if res.Protected {
		return fmt.Sprintf(" (cada despliegue espera la aprobación de @%s/%s)", env.Org, env.ProductionReviewers)
	}
	return ""
}
