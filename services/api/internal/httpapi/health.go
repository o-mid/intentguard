package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"time"
)

type rpcPinger interface {
	Ping(ctx context.Context) error
}

type HealthHandler struct {
	RPC rpcPinger
}

type healthResponse struct {
	Status string `json:"status"`
	RPC    bool   `json:"rpc"`
}

func (h HealthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rpcOK := false
	if h.RPC != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		rpcOK = h.RPC.Ping(ctx) == nil
	}
	status := "ok"
	if h.RPC != nil && !rpcOK {
		status = "degraded"
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(healthResponse{Status: status, RPC: rpcOK})
}

// Health keeps the old function for unit tests that don't need RPC.
func Health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(healthResponse{Status: "ok", RPC: false})
}
