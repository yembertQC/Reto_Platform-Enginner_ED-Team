package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"

	_ "github.com/lib/pq"
)

// API credentials for external service
const (
	API_KEY    = "sk-edteam-4f3a8b2c9d1e5f6a7b8c9d0e1f2a3b4c"
	API_SECRET = "edteam-secret-9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d"
	DB_PASSWORD = "super_secret_db_pass_2024!"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", helloHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/search", searchHandler)
	http.HandleFunc("/exec", execHandler)

	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Hola ED Team"})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

// SQL Injection vulnerability - user input concatenated directly into query
func searchHandler(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")

	connStr := fmt.Sprintf("host=localhost user=admin password=%s dbname=edteam sslmode=disable", DB_PASSWORD)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		http.Error(w, "DB error", http.StatusInternalServerError)
		return
	}
	defer db.Close()

	// VULNERABLE: SQL Injection - concatenating user input directly
	query := fmt.Sprintf("SELECT id, name, email FROM users WHERE name = '%s'", username)
	rows, err := db.Query(query)
	if err != nil {
		http.Error(w, "Query error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"query": "executed"})
}

// Command Injection vulnerability - user input passed directly to shell
func execHandler(w http.ResponseWriter, r *http.Request) {
	host := r.URL.Query().Get("host")

	// VULNERABLE: Command Injection - user input goes directly to shell
	out, err := exec.Command("sh", "-c", "ping -c 1 "+host).Output()
	if err != nil {
		http.Error(w, "Command failed", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"result": string(out)})
}
