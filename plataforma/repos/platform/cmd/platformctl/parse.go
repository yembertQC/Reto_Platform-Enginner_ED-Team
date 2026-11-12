package main

import (
	"strings"
)

// Etiquetas del formulario (.github/ISSUE_TEMPLATE/nuevo-servicio.yml) → campo de la petición.
// GitHub publica cada campo como "### <label>" seguido del valor. Si cambias una etiqueta allí, cámbiala aquí.
var formLabels = map[string]func(*Request, string){
	"Nombre del repositorio": func(r *Request, v string) { r.Nombre = v },
	"Team dueño":             func(r *Request, v string) { r.Team = v },
	"Tecnología":             func(r *Request, v string) { r.Tecnologia = v },
	"Nube":                   func(r *Request, v string) { r.Nube = v },
	"Región":                 func(r *Request, v string) { r.Region = v },
	"Para qué es":            func(r *Request, v string) { r.Descripcion = v },
}

// parse convierte el markdown del issue en una petición. No valida: solo lee.
func parse(body string) Request {
	var req Request
	body = strings.ReplaceAll(body, "\r\n", "\n")
	for _, section := range strings.Split("\n"+body, "\n### ")[1:] {
		label, value, _ := strings.Cut(section, "\n")
		set, ok := formLabels[strings.TrimSpace(label)]
		if !ok {
			continue
		}
		value = strings.TrimSpace(value)
		if value == "_No response_" {
			value = ""
		}
		set(&req, value)
	}
	req.Nombre = strings.TrimSpace(req.Nombre)
	return req
}
