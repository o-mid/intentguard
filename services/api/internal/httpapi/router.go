package httpapi

import "net/http"

func NewMux(authHandlers AuthHandlers, tokens accessParser) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", Health)
	mux.HandleFunc("POST /auth/register", authHandlers.Register)
	mux.HandleFunc("POST /auth/login", authHandlers.Login)
	mux.HandleFunc("GET /auth/me", RequireAuth(tokens, authHandlers.Me))
	return mux
}
