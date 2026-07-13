package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/o-mid/intentguard/services/api/internal/intentsvc"
	"github.com/o-mid/intentguard/services/api/internal/planner"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

type intentService interface {
	Submit(ctx context.Context, userID, text string) (intentsvc.Result, error)
	GetPlan(ctx context.Context, userID, planID string) (store.Plan, error)
	RejectPlan(ctx context.Context, userID, planID string) (store.Plan, error)
	ListIntents(ctx context.Context, userID string) ([]intentsvc.Result, error)
}

type IntentHandlers struct {
	Service intentService
}

type createIntentRequest struct {
	Text string `json:"text"`
}

type stepResponse struct {
	Index          int             `json:"index"`
	Action         string          `json:"action"`
	DecodedSummary string          `json:"decoded_summary"`
	Status         string          `json:"status"`
	Payload        json.RawMessage `json:"payload"`
	TxHash         *string         `json:"tx_hash,omitempty"`
	Error          *string         `json:"error,omitempty"`
}

type planResponse struct {
	ID               string          `json:"id"`
	IntentID         string          `json:"intent_id"`
	Status           string          `json:"status"`
	Summary          string          `json:"summary"`
	SchemaVersion    string          `json:"schema_version"`
	RejectionReasons json.RawMessage `json:"rejection_reasons"`
	Steps            []stepResponse  `json:"steps"`
}

type intentResponse struct {
	ID     string       `json:"id"`
	Text   string       `json:"text"`
	Status string       `json:"status"`
	Plan   planResponse `json:"plan"`
}

func (h IntentHandlers) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req createIntentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	text := strings.TrimSpace(req.Text)
	if text == "" {
		writeError(w, http.StatusBadRequest, "invalid_intent")
		return
	}

	res, err := h.Service.Submit(r.Context(), userID, text)
	if err != nil {
		if errors.Is(err, planner.ErrUnavailable) {
			writeError(w, http.StatusServiceUnavailable, "planner_unavailable")
			return
		}
		writeError(w, http.StatusBadRequest, "planner_failed")
		return
	}
	writeJSON(w, http.StatusCreated, toIntentResponse(res))
}

func (h IntentHandlers) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	items, err := h.Service.ListIntents(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list_failed")
		return
	}
	out := make([]intentResponse, 0, len(items))
	for _, item := range items {
		out = append(out, toIntentResponse(item))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h IntentHandlers) GetPlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	planID := r.PathValue("id")
	if planID == "" {
		writeError(w, http.StatusBadRequest, "invalid_plan_id")
		return
	}
	plan, err := h.Service.GetPlan(r.Context(), userID, planID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "lookup_failed")
		return
	}
	writeJSON(w, http.StatusOK, toPlanResponse(plan))
}

func (h IntentHandlers) RejectPlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	planID := r.PathValue("id")
	if planID == "" {
		writeError(w, http.StatusBadRequest, "invalid_plan_id")
		return
	}
	plan, err := h.Service.RejectPlan(r.Context(), userID, planID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "reject_failed")
		return
	}
	writeJSON(w, http.StatusOK, toPlanResponse(plan))
}

func toIntentResponse(res intentsvc.Result) intentResponse {
	return intentResponse{
		ID:     res.Intent.ID,
		Text:   res.Intent.Text,
		Status: res.Intent.Status,
		Plan:   toPlanResponse(res.Plan),
	}
}

func toPlanResponse(p store.Plan) planResponse {
	steps := make([]stepResponse, 0, len(p.Steps))
	for _, st := range p.Steps {
		steps = append(steps, stepResponse{
			Index:          st.Index,
			Action:         st.Action,
			DecodedSummary: st.DecodedSummary,
			Status:         st.Status,
			Payload:        st.PayloadJSON,
			TxHash:         st.TxHash,
			Error:          st.Error,
		})
	}
	reasons := p.RejectionReasons
	if len(reasons) == 0 {
		reasons = json.RawMessage("[]")
	}
	return planResponse{
		ID:               p.ID,
		IntentID:         p.IntentID,
		Status:           p.Status,
		Summary:          p.Summary,
		SchemaVersion:    p.SchemaVersion,
		RejectionReasons: reasons,
		Steps:            steps,
	}
}
