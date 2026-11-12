package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strings"
)

// Config es config/plataforma.json: lo que la plataforma ofrece hoy.
type Config struct {
	NombreRegex string            `json:"nombre_regex"`
	NombreAyuda string            `json:"nombre_ayuda"`
	Plantillas  map[string]string `json:"plantillas"`
	Nubes       map[string]struct {
		Regiones       []string `json:"regiones"`
		VariableRegion string   `json:"variable_region"`
	} `json:"nubes"`
	Ambientes []string `json:"ambientes"`
	Tamanos   map[string]struct {
		CPU      string `json:"cpu"`
		Memoria  string `json:"memoria"`
		LambdaMB string `json:"lambda_mb"`
	} `json:"tamanos"`
	TamanosPermitidos []string `json:"tamanos_permitidos"`
	TeamsReservados   []string `json:"teams_reservados"`

	nameRule *regexp.Regexp // nombre_regex compilada. De 3 a 28: <nombre>-dev cabe en los 32 de una Container App.
}

func loadConfig(path string) (Config, error) {
	var c Config
	b, err := os.ReadFile(path)
	if err != nil {
		return c, fmt.Errorf("no se pudo leer %s: %w", path, err)
	}
	if err := json.Unmarshal(b, &c); err != nil {
		return c, fmt.Errorf("%s no es JSON válido: %w", path, err)
	}
	if c.NombreRegex == "" {
		return c, fmt.Errorf("%s no define nombre_regex", path)
	}
	if c.nameRule, err = regexp.Compile(c.NombreRegex); err != nil {
		return c, fmt.Errorf("nombre_regex no es una expresión válida: %w", err)
	}
	return c, nil
}

// validate devuelve los motivos de rechazo; vacío si la petición es válida.
// Quién pide y qué teams existen se consulta siempre a GitHub. Las reglas sobre la petición
// se evalúan en Go (Módulo 1) o con OPA y policy/repo.rego (Módulo 2, POLICY_ENABLED=true).
func validate(req Request, env Env, cfg Config, gh *GitHub) []string {
	var problems []string
	if os.Getenv("ISSUE_AUTHOR_TYPE") != "Bot" && !gh.isMember(env.Org, env.Author) {
		problems = append(problems, fmt.Sprintf("@%s no es miembro de la organización", env.Author))
	}
	if cfg.nameRule.MatchString(req.Nombre) {
		if st, _ := gh.do("GET", "/repos/"+env.Org+"/"+req.Nombre, nil, nil); st == 200 {
			problems = append(problems, fmt.Sprintf("ya existe un repo llamado '%s' en la organización", req.Nombre))
		}
	}
	teams, err := gh.teams(env.Org)
	if err != nil {
		return append(problems, "no se pudo leer la lista de teams: "+err.Error())
	}
	if env.Policy {
		denies, err := validateOPA(req, teams)
		if err != nil {
			return append(problems, "no se pudo evaluar la política: "+err.Error())
		}
		return append(problems, denies...)
	}
	return append(problems, rules(req, cfg, teams)...)
}

// rules son las mismas reglas que policy/repo.rego, escritas en Go.
func rules(req Request, cfg Config, teams []string) []string {
	var p []string
	if !cfg.nameRule.MatchString(req.Nombre) {
		p = append(p, fmt.Sprintf("el nombre '%s' no cumple la convención: %s", req.Nombre, cfg.NombreAyuda))
	}
	if !slices.Contains(teams, req.Team) {
		p = append(p, fmt.Sprintf("el team '%s' no existe en la organización", req.Team))
	}
	if slices.Contains(cfg.TeamsReservados, req.Team) {
		p = append(p, fmt.Sprintf("el team '%s' no puede ser dueño de un servicio", req.Team))
	}
	if _, ok := cfg.Plantillas[req.Tecnologia]; !ok {
		p = append(p, fmt.Sprintf("no hay plantilla para la tecnología '%s'", req.Tecnologia))
	}
	nube, ok := cfg.Nubes[req.Nube]
	if !ok {
		p = append(p, fmt.Sprintf("la nube '%s' no está soportada", req.Nube))
	} else if !slices.Contains(nube.Regiones, req.Region) {
		p = append(p, fmt.Sprintf("la región '%s' no está permitida en %s (permitidas: %s)", req.Region, req.Nube, strings.Join(nube.Regiones, ", ")))
	}
	if !slices.Contains(cfg.Ambientes, req.Ambiente) {
		p = append(p, fmt.Sprintf("el ambiente '%s' no existe (ambientes: %s)", req.Ambiente, strings.Join(cfg.Ambientes, ", ")))
	}
	if _, ok := cfg.Tamanos[req.Tamano]; !ok {
		p = append(p, fmt.Sprintf("el tamaño '%s' no existe", req.Tamano))
	} else if !slices.Contains(cfg.TamanosPermitidos, req.Tamano) {
		p = append(p, fmt.Sprintf("el tamaño '%s' no está permitido (permitidos: %s)", req.Tamano, strings.Join(cfg.TamanosPermitidos, ", ")))
	}
	return p
}

func validateOPA(req Request, teams []string) ([]string, error) {
	input, _ := json.Marshal(map[string]any{
		"nombre": req.Nombre, "team": req.Team, "tecnologia": req.Tecnologia,
		"nube": req.Nube, "region": req.Region, "ambiente": req.Ambiente, "tamano": req.Tamano,
		"teams_existentes": teams,
	})
	cmd := exec.Command("opa", "eval", "--format", "json", "--stdin-input",
		"-d", "policy/repo.rego", "-d", "config/plataforma.json", "data.platform.repo.deny")
	cmd.Stdin = bytes.NewReader(input)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("opa eval: %w", err)
	}
	var res struct {
		Result []struct {
			Expressions []struct {
				Value []string `json:"value"`
			} `json:"expressions"`
		} `json:"result"`
	}
	if err := json.Unmarshal(out, &res); err != nil {
		return nil, err
	}
	if len(res.Result) == 0 || len(res.Result[0].Expressions) == 0 {
		return nil, nil
	}
	return res.Result[0].Expressions[0].Value, nil
}
