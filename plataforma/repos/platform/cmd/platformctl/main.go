// platformctl atiende una petición de servicio hecha con el formulario de issues.
//
//	parse    → lee el cuerpo del issue y devuelve la petición
//	validate → aplica las reglas de la plataforma (en Go, o con OPA si POLICY_ENABLED=true)
//	execute  → crea el repo desde la plantilla, da permisos, pone variables, CODEOWNERS y catálogo
//	report   → contesta en el issue, etiqueta y lo cierra
//
// Lo lanza .github/workflows/issueops.yml con el token de la GitHub App de la plataforma.
package main

import (
	"fmt"
	"log"
	"os"
	"slices"
	"strconv"
	"strings"
)

// Request es lo que pide el formulario.
type Request struct {
	Nombre      string `json:"nombre"`
	Team        string `json:"team"`
	Tecnologia  string `json:"tecnologia"`
	Nube        string `json:"nube"`
	Region      string `json:"region"`
	Ambiente    string `json:"ambiente"`
	Tamano      string `json:"tamano"`
	Descripcion string `json:"descripcion"`
}

// Env es el contexto que llega del workflow.
type Env struct {
	Org, PlatformRepo, Author string
	Issue                     int
	AuthorIsBot, Policy       bool
	// Team que aprueba los despliegues a production (M2 · Clase 3). Vacío: production sin protección.
	ProductionReviewers string
}

func main() {
	env := Env{
		Org:          mustEnv("ORG"),
		PlatformRepo: mustEnv("PLATFORM_REPO"),
		Author:       mustEnv("ISSUE_AUTHOR"),
		// Lo pidió un agente: una GitHub App (autor bot) o un agente que actúa con la sesión de una
		// persona y marca el issue con platform/agent. La persona sigue siendo la responsable.
		AuthorIsBot: os.Getenv("ISSUE_AUTHOR_TYPE") == "Bot" ||
			slices.Contains(strings.Split(os.Getenv("ISSUE_LABELS"), ","), "platform/agent"),
		Policy:              os.Getenv("POLICY_ENABLED") == "true",
		ProductionReviewers: strings.TrimSpace(os.Getenv("PRODUCTION_REVIEWERS")),
	}
	n, err := strconv.Atoi(mustEnv("ISSUE_NUMBER"))
	if err != nil {
		log.Fatalf("ISSUE_NUMBER no es un número: %v", err)
	}
	env.Issue = n

	cfg, err := loadConfig("config/plataforma.json")
	if err != nil {
		log.Fatal(err)
	}
	gh := newGitHub(mustEnv("GH_TOKEN"))
	issue := issueRef{gh: gh, org: env.Org, repo: env.PlatformRepo, number: env.Issue}

	req := parse(os.Getenv("ISSUE_BODY"))
	log.Printf("Petición #%d de %s: %+v", env.Issue, env.Author, req)

	if problems := validate(req, env, cfg, gh); len(problems) > 0 {
		reject(issue, env, problems)
		return
	}

	res, err := execute(req, env, cfg, gh, issue)
	if err != nil {
		fail(issue, env, err)
		os.Exit(1)
	}
	report(issue, req, env, res)
}

func reject(issue issueRef, env Env, problems []string) {
	var b strings.Builder
	b.WriteString("❌ **No se crea el servicio.** La petición no cumple las reglas de la plataforma:\n\n")
	for _, p := range problems {
		fmt.Fprintf(&b, "- %s\n", p)
	}
	b.WriteString("\nCorrige el formulario editando este issue y se vuelve a evaluar.")
	issue.comment(b.String())
	// Se queda abierto y con platform/pending para que una edición lo vuelva a evaluar.
	issue.setLabels(append([]string{"platform/pending", "platform/rejected"}, agentLabel(env)...)...)
	log.Printf("Rechazada: %v", problems)
}

func fail(issue issueRef, env Env, err error) {
	issue.comment(fmt.Sprintf("⚠️ **La plataforma falló a mitad de la petición.** El team `platform` ya lo tiene en el log del workflow.\n\n```\n%v\n```", err))
	issue.setLabels(append([]string{"platform/failed"}, agentLabel(env)...)...)
	log.Printf("Error: %v", err)
}

func mustEnv(k string) string {
	v := strings.TrimSpace(os.Getenv(k))
	if v == "" {
		log.Fatalf("falta la variable de entorno %s", k)
	}
	return v
}
