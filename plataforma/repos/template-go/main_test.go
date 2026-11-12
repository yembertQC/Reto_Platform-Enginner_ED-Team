package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func get(t *testing.T, h http.HandlerFunc, path string) (int, map[string]string) {
	t.Helper()
	w := httptest.NewRecorder()
	h(w, httptest.NewRequest(http.MethodGet, path, nil))
	var body map[string]string
	_ = json.NewDecoder(w.Body).Decode(&body)
	return w.Code, body
}

func TestHello(t *testing.T) {
	code, body := get(t, helloHandler, "/")
	if code != http.StatusOK || body["message"] != "Hola ED Team" {
		t.Fatalf("GET / = %d %v", code, body)
	}
}

func TestHelloNotFound(t *testing.T) {
	if code, _ := get(t, helloHandler, "/otra"); code != http.StatusNotFound {
		t.Fatalf("GET /otra = %d, se esperaba 404", code)
	}
}

func TestHealth(t *testing.T) {
	code, body := get(t, healthHandler, "/health")
	if code != http.StatusOK || body["status"] != "healthy" {
		t.Fatalf("GET /health = %d %v", code, body)
	}
}
