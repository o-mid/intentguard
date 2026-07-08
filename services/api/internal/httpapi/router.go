package httpapi

import "net/http"

func NewMux(authHandlers AuthHandlers, intentHandlers IntentHandlers, stepHandlers StepHandlers, tokens accessParser, health http.HandlerFunc) *http.ServeMux {
	mux := http.NewServeMux()
	if health == nil {
		health = Health
	}
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("POST /auth/register", authHandlers.Register)
	mux.HandleFunc("POST /auth/login", authHandlers.Login)
	mux.HandleFunc("GET /auth/me", RequireAuth(tokens, authHandlers.Me))
	mux.HandleFunc("POST /intents", RequireAuth(tokens, intentHandlers.Create))
	mux.HandleFunc("GET /plans/{id}", RequireAuth(tokens, intentHandlers.GetPlan))
	mux.HandleFunc("POST /plans/{id}/reject", RequireAuth(tokens, intentHandlers.RejectPlan))
	mux.HandleFunc("POST /plans/{id}/steps/{n}/approve", RequireAuth(tokens, stepHandlers.Approve))
	return mux
}
