package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// Result es lo que report() le cuenta a quien pidió el servicio.
type Result struct {
	Repo, RepoURL, ActionsURL, Origen string
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

	// 3. Variables del repo: la nube y la región que pidió, y el team (activa deploy.yml)
	vars := map[string]string{
		"CLOUD_PROVIDER":                   req.Nube,
		cfg.Nubes[req.Nube].VariableRegion: req.Region,
		"SERVICE_TEAM":                     req.Team,
	}
	for k, v := range vars {
		if err := gh.setVariable(org, name, k, v); err != nil {
			return res, fmt.Errorf("variable %s: %w", k, err)
		}
	}

	// 4. CODEOWNERS. Este commit es el primer push con las variables puestas: dispara el deploy.
	owners := fmt.Sprintf("# Lo escribe la plataforma al crear el repo.\n*            @%s/%s\n/.github/    @%s/platform\n", org, req.Team, org)
	if err := gh.putFile(org, name, ".github/CODEOWNERS", owners, "", "Plataforma: CODEOWNERS del team "+req.Team); err != nil {
		return res, fmt.Errorf("CODEOWNERS: %w", err)
	}

	// 5. Fila en el catálogo
	if err := addToCatalog(gh, org, req, env, res); err != nil {
		return res, fmt.Errorf("catálogo: %w", err)
	}
	return res, nil
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
    descripcion: %s
    autor: %s
    origen: %s
    fecha: %s
    issue: %s
`, q(req.Nombre), q(req.Team), q(req.Tecnologia), q(req.Nube), q(req.Region), q(oneLine(req.Descripcion, 300)),
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
		if err = gh.putFile(org, "catalog", "catalog.yml", body, f.Sha, "Catálogo: "+req.Nombre+" ("+req.Team+")"); err == nil {
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
