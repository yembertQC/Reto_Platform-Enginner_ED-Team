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
| Catálogo | añadido como %s |

El primer despliegue ya está en marcha: [ver en Actions](%s). Cuando termine, la URL del servicio aparece en el resumen de la ejecución.`,
		res.Repo, res.RepoURL, req.Tecnologia, env.Org, req.Team, req.Nube, req.Region, res.Origen, res.ActionsURL))
	issue.setLabels(append([]string{"platform/done"}, agentLabel(env)...)...)
	issue.close()
}
