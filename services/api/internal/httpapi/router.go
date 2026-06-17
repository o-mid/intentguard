package httpapi

import "net/http"

func NewMux(authHandlers AuthHandlers, intentHandlers IntentHandlers, tokens accessParser) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", Health)
	mux.HandleFunc("POST /auth/register", authHandlers.Register)
	mux.HandleFunc("POST /auth/login", authHandlers.Login)
	mux.HandleFunc("GET /auth/me", RequireAuth(tokens, authHandlers.Me))
	mux.HandleFunc("POST /intents", RequireAuth(tokens, intentHandlers.Create))
	mux.HandleFunc("GET /plans/{id}", RequireAuth(tokens, intentHandlers.GetPlan))
	return mux
}
