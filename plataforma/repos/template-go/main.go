// Servicio creado desde la plantilla template-go de la plataforma.
// Contrato del golden path: escucha en $PORT (8080 por defecto) y responde GET /health.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", helloHandler)
	http.HandleFunc("/health", healthHandler)

	log.Printf("Servidor escuchando en el puerto %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, map[string]string{"message": "Hola ED Team"})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"status": "healthy"})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}
