package httpapi

import "net/http"

func NewMux(authHandlers AuthHandlers) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", Health)
	mux.HandleFunc("POST /auth/register", authHandlers.Register)
	mux.HandleFunc("POST /auth/login", authHandlers.Login)
	return mux
}
