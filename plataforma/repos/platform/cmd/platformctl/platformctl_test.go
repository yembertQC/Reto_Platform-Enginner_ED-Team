package main

import (
	"testing"
)

// Así llega el cuerpo de un issue creado con .github/ISSUE_TEMPLATE/nuevo-servicio.yml.
const formBody = "### Nombre del repositorio\n\npagos-ledger\n\n### Team dueño\n\npagos\n\n### Tecnología\n\npython\n\n### Nube\n\naws\n\n### Región\n\nus-east-1\n\n### Para qué es\n\nLibro mayor\nde pagos.\n"

func TestParse(t *testing.T) {
	got := parse(formBody)
	want := Request{Nombre: "pagos-ledger", Team: "pagos", Tecnologia: "python", Nube: "aws", Region: "us-east-1", Descripcion: "Libro mayor\nde pagos."}
	if got != want {
		t.Fatalf("parse:\n got %+v\nwant %+v", got, want)
	}
}

func TestParseCRLFYSinRespuesta(t *testing.T) {
	got := parse("### Nombre del repositorio\r\n\r\nweb-app\r\n\r\n### Para qué es\r\n\r\n_No response_\r\n")
	if got.Nombre != "web-app" || got.Descripcion != "" {
		t.Fatalf("parse: %+v", got)
	}
}

func testConfig(t *testing.T) Config {
	t.Helper()
	cfg, err := loadConfig("../../config/plataforma.json")
	if err != nil {
		t.Fatal(err)
	}
	return cfg
}

func TestRules(t *testing.T) {
	cfg := testConfig(t)
	teams := []string{"pagos", "web", "platform"}
	ok := Request{Nombre: "pagos-ledger", Team: "pagos", Tecnologia: "go", Nube: "azure", Region: "eastus"}

	cases := []struct {
		name   string
		mutate func(*Request)
		fallos int
	}{
		{"válida azure", func(r *Request) {}, 0},
		{"válida aws", func(r *Request) { r.Nube, r.Region = "aws", "us-east-1" }, 0},
		{"nombre con mayúsculas", func(r *Request) { r.Nombre = "Pagos_Ledger" }, 1},
		{"nombre que termina en guion", func(r *Request) { r.Nombre = "pagos-" }, 1},
		{"nombre de 29", func(r *Request) { r.Nombre = "a234567890123456789012345678x" }, 1},
		{"team inexistente", func(r *Request) { r.Team = "datos" }, 1},
		{"team reservado", func(r *Request) { r.Team = "platform" }, 1},
		{"tecnología sin plantilla", func(r *Request) { r.Tecnologia = "java" }, 1},
		{"región de otra nube", func(r *Request) { r.Region = "us-east-1" }, 1},
		{"nube no soportada", func(r *Request) { r.Nube = "gcp" }, 1},
	}
	for _, c := range cases {
		r := ok
		c.mutate(&r)
		if got := rules(r, cfg, teams); len(got) != c.fallos {
			t.Errorf("%s: %d fallos %v, se esperaban %d", c.name, len(got), got, c.fallos)
		}
	}
}

func TestOneLine(t *testing.T) {
	if got := oneLine("  a\n b  ", 10); got != "a b" {
		t.Fatalf("oneLine = %q", got)
	}
	if got := oneLine("abcdef", 4); got != "abc…" {
		t.Fatalf("oneLine corta = %q", got)
	}
}
