package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// GitHub es un cliente mínimo de la API REST, sin dependencias.
type GitHub struct {
	token, base string
	http        *http.Client
}

func newGitHub(token string) *GitHub {
	base := os.Getenv("GITHUB_API_URL")
	if base == "" {
		base = "https://api.github.com"
	}
	return &GitHub{token: token, base: base, http: &http.Client{Timeout: 30 * time.Second}}
}

// do hace la llamada y devuelve el código HTTP. Si out no es nil, decodifica la respuesta.
func (g *GitHub) do(method, path string, in, out any) (int, error) {
	var body io.Reader
	if in != nil {
		b, err := json.Marshal(in)
		if err != nil {
			return 0, err
		}
		body = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, g.base+path, body)
	if err != nil {
		return 0, err
	}
	req.Header.Set("Authorization", "Bearer "+g.token)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	resp, err := g.http.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return resp.StatusCode, fmt.Errorf("%s %s → %d: %s", method, path, resp.StatusCode, bytes.TrimSpace(raw))
	}
	if out != nil && len(raw) > 0 {
		return resp.StatusCode, json.Unmarshal(raw, out)
	}
	return resp.StatusCode, nil
}

// expect falla si el código no es el esperado.
func (g *GitHub) expect(want int, method, path string, in any, out ...any) error {
	var o any
	if len(out) > 0 {
		o = out[0]
	}
	st, err := g.do(method, path, in, o)
	if err != nil {
		return err
	}
	if st != want {
		return fmt.Errorf("%s %s → %d (se esperaba %d)", method, path, st, want)
	}
	return nil
}

func (g *GitHub) isMember(org, user string) bool {
	st, _ := g.do("GET", "/orgs/"+org+"/members/"+user, nil, nil)
	return st == 204
}

func (g *GitHub) teams(org string) ([]string, error) {
	var list []struct{ Slug string }
	if err := g.expect(200, "GET", "/orgs/"+org+"/teams?per_page=100", nil, &list); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(list))
	for _, t := range list {
		out = append(out, t.Slug)
	}
	return out, nil
}

func (g *GitHub) setVariable(org, repo, name, value string) error {
	body := map[string]string{"name": name, "value": value}
	st, err := g.do("POST", "/repos/"+org+"/"+repo+"/actions/variables", body, nil)
	if st == 409 { // ya existe: se actualiza
		return g.expect(204, "PATCH", "/repos/"+org+"/"+repo+"/actions/variables/"+name, body)
	}
	return err
}

// putFile crea (sha vacío) o actualiza un archivo con un commit. Devuelve el sha del commit.
func (g *GitHub) putFile(org, repo, path, content, sha, message string) (string, error) {
	body := map[string]string{"message": message, "content": base64.StdEncoding.EncodeToString([]byte(content))}
	if sha != "" {
		body["sha"] = sha
	}
	var out struct {
		Commit struct{ Sha string }
	}
	_, err := g.do("PUT", "/repos/"+org+"/"+repo+"/contents/"+path, body, &out)
	return out.Commit.Sha, err
}

// issueRef agrupa lo que se hace sobre el issue de la petición. Sus errores se registran
// pero no paran la ejecución: contestar en el issue nunca debe deshacer el trabajo hecho.
type issueRef struct {
	gh        *GitHub
	org, repo string
	number    int
}

func (i issueRef) path() string {
	return fmt.Sprintf("/repos/%s/%s/issues/%d", i.org, i.repo, i.number)
}

func (i issueRef) comment(body string) {
	if _, err := i.gh.do("POST", i.path()+"/comments", map[string]string{"body": body}, nil); err != nil {
		log.Printf("no se pudo comentar: %v", err)
	}
}

func (i issueRef) setLabels(labels ...string) {
	if _, err := i.gh.do("PUT", i.path()+"/labels", map[string][]string{"labels": labels}, nil); err != nil {
		log.Printf("no se pudieron poner las etiquetas: %v", err)
	}
}

func (i issueRef) close() {
	if _, err := i.gh.do("PATCH", i.path(), map[string]string{"state": "closed", "state_reason": "completed"}, nil); err != nil {
		log.Printf("no se pudo cerrar el issue: %v", err)
	}
}
