package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"
)

// Result es lo que report() le cuenta a quien pidió el servicio.
type Result struct {
	Repo, RepoURL, ActionsURL, Origen string
	Protected                         bool // production con aprobación obligatoria
}

// execute crea el servicio. Cada paso es idempotente o falla antes de tocar nada:
// si el repo ya existe, no se crea otro.
func execute(req Request, env Env, cfg Config, gh *GitHub, issue issueRef) (Result, error) {
	org, name := env.Org, req.Nombre
	res := Result{
		Repo:       org + "/" + name,
		RepoURL:    fmt.Sprintf("https://github.com/%s/%s", org, name),
		ActionsURL: fmt.Sprintf("https://github.com/%s/%s/actions", org, name),
		Origen:     "persona",
	}
	if env.AuthorIsBot {
		res.Origen = "agente"
	}
	issue.setLabels(append([]string{"platform/running"}, agentLabel(env)...)...)

	if st, _ := gh.do("GET", "/repos/"+org+"/"+name, nil, nil); st == 200 {
		return res, fmt.Errorf("el repo %s ya existe; no se crea otro", res.Repo)
	}

	// 1. Repo desde la plantilla de la tecnología elegida
	template := cfg.Plantillas[req.Tecnologia]
	if err := gh.expect(201, "POST", "/repos/"+org+"/"+template+"/generate", map[string]any{
		"owner": org, "name": name, "description": oneLine(req.Descripcion, 300), "private": false,
	}); err != nil {
		return res, fmt.Errorf("crear el repo desde %s: %w", template, err)
	}
	// GitHub copia la plantilla en segundo plano: se espera a que tenga contenido.
	if err := waitForContent(gh, org, name); err != nil {
		return res, err
	}

	// 2. El team dueño escribe en su repo
	if err := gh.expect(204, "PUT", "/orgs/"+org+"/teams/"+req.Team+"/repos/"+org+"/"+name,
		map[string]string{"permission": "push"}); err != nil {
		return res, fmt.Errorf("dar permiso al team %s: %w", req.Team, err)
	}

	// 3. Variables del repo: nube, región, ambiente y tamaño que pidió, y el team (activa deploy.yml)
	size := cfg.Tamanos[req.Tamano]
	vars := map[string]string{
		"CLOUD_PROVIDER":                   req.Nube,
		cfg.Nubes[req.Nube].VariableRegion: req.Region,
		"DEPLOY_ENVIRONMENT":               req.Ambiente,
		"CONTAINERAPP_CPU":                 size.CPU,
		"CONTAINERAPP_MEMORY":              size.Memoria,
		"LAMBDA_MEMORY":                    size.LambdaMB,
		"SERVICE_TEAM":                     req.Team,
	}
	for k, v := range vars {
		if err := gh.setVariable(org, name, k, v); err != nil {
			return res, fmt.Errorf("variable %s: %w", k, err)
		}
	}

	// 3b. M2 · Clase 3: production exige la aprobación del team indicado en PRODUCTION_REVIEWERS.
	if req.Ambiente == "production" && env.ProductionReviewers != "" {
		if err := protectProduction(gh, org, name, env.ProductionReviewers); err != nil {
			return res, fmt.Errorf("proteger production: %w", err)
		}
		res.Protected = true
	}

	// 4. CODEOWNERS. Este commit es el primer push con las variables puestas: dispara el deploy.
	owners := fmt.Sprintf("# Lo escribe la plataforma al crear el repo.\n*            @%s/%s\n/.github/    @%s/platform\n", org, req.Team, org)
	commit, err := gh.putFile(org, name, ".github/CODEOWNERS", owners, "", "Plataforma: CODEOWNERS del team "+req.Team)
	if err != nil {
		return res, fmt.Errorf("CODEOWNERS: %w", err)
	}
	cancelEarlyRuns(gh, org, name, commit)

	// 5. Fila en el catálogo
	if err := addToCatalog(gh, org, req, env, res); err != nil {
		return res, fmt.Errorf("catálogo: %w", err)
	}
	return res, nil
}

// protectProduction crea el environment production con el team como revisor obligatorio.
// El primer despliegue se queda esperando hasta que alguien de ese team lo apruebe.
func protectProduction(gh *GitHub, org, repo, team string) error {
	var t struct{ ID int64 }
	if err := gh.expect(200, "GET", "/orgs/"+org+"/teams/"+team, nil, &t); err != nil {
		return fmt.Errorf("team %s: %w", team, err)
	}
	return gh.expect(200, "PUT", "/repos/"+org+"/"+repo+"/environments/production", map[string]any{
		"reviewers":                []map[string]any{{"type": "Team", "id": t.ID}},
		"prevent_self_review":      false,
		"deployment_branch_policy": nil,
	})
}

// cancelEarlyRuns cancela el despliegue que dispara el commit inicial de la plantilla: arranca
// antes de que el repo tenga sus variables (nube, ambiente, tamaño) y desplegaría con los valores
// de la organización. El bueno es el del commit de CODEOWNERS (keep). Si falla, solo se registra.
func cancelEarlyRuns(gh *GitHub, org, repo, keep string) {
	for i := 0; i < 5; i++ {
		var runs struct {
			WorkflowRuns []struct {
				ID      int64
				HeadSha string `json:"head_sha"`
				Status  string
			} `json:"workflow_runs"`
		}
		if err := gh.expect(200, "GET", "/repos/"+org+"/"+repo+"/actions/runs?per_page=20", nil, &runs); err != nil {
			log.Printf("no se pudieron leer las ejecuciones de %s: %v", repo, err)
			return
		}
		cancelled := 0
		for _, r := range runs.WorkflowRuns {
			if r.HeadSha != keep && r.Status != "completed" {
				if _, err := gh.do("POST", fmt.Sprintf("/repos/%s/%s/actions/runs/%d/cancel", org, repo, r.ID), nil, nil); err == nil {
					cancelled++
				}
			}
		}
		if cancelled > 0 || len(runs.WorkflowRuns) > 1 {
			return
		}
		time.Sleep(2 * time.Second)
	}
}

func waitForContent(gh *GitHub, org, name string) error {
	for i := 0; i < 20; i++ {
		if st, _ := gh.do("GET", "/repos/"+org+"/"+name+"/contents/README.md", nil, nil); st == 200 {
			return nil
		}
		time.Sleep(3 * time.Second)
	}
	return fmt.Errorf("el repo %s/%s sigue vacío después de 60 s", org, name)
}

func addToCatalog(gh *GitHub, org string, req Request, env Env, res Result) error {
	q := func(s string) string { b, _ := json.Marshal(s); return string(b) }
	entry := fmt.Sprintf(`  - nombre: %s
    team: %s
    tecnologia: %s
    nube: %s
    region: %s
    ambiente: %s
    tamano: %s
    descripcion: %s
    autor: %s
    origen: %s
    fecha: %s
    issue: %s
`, q(req.Nombre), q(req.Team), q(req.Tecnologia), q(req.Nube), q(req.Region), q(req.Ambiente), q(req.Tamano), q(oneLine(req.Descripcion, 300)),
		q(env.Author), res.Origen, time.Now().UTC().Format("2006-01-02"),
		q(fmt.Sprintf("https://github.com/%s/%s/issues/%d", org, env.PlatformRepo, env.Issue)))

	// Dos intentos: si alguien escribió el catálogo entre la lectura y la escritura, el sha no coincide.
	var err error
	for i := 0; i < 2; i++ {
		var f struct{ Content, Sha string }
		if err = gh.expect(200, "GET", "/repos/"+org+"/catalog/contents/catalog.yml", nil, &f); err != nil {
			return err
		}
		raw, _ := base64.StdEncoding.DecodeString(strings.ReplaceAll(f.Content, "\n", ""))
		body := strings.TrimRight(string(raw), "\n") + "\n" + entry
		if _, err = gh.putFile(org, "catalog", "catalog.yml", body, f.Sha, "Catálogo: "+req.Nombre+" ("+req.Team+")"); err == nil {
			return nil
		}
	}
	return err
}

func agentLabel(env Env) []string {
	if env.AuthorIsBot {
		return []string{"platform/agent"}
	}
	return nil
}

func oneLine(s string, max int) string {
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > max {
		s = string(r[:max-1]) + "…"
	}
	return s
}
