package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strconv"

	"github.com/o-mid/intentguard/services/api/internal/executor"
)

type stepExecutor interface {
	ApproveStep(ctx context.Context, userID, planID string, index int) (executor.ExecResult, error)
}

type StepHandlers struct {
	Executor stepExecutor
}

type stepExecResponse struct {
	Index  int    `json:"index"`
	Status string `json:"status"`
	TxHash string `json:"tx_hash,omitempty"`
	Error  string `json:"error,omitempty"`
}

func (h StepHandlers) Approve(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	planID := r.PathValue("id")
	n, err := strconv.Atoi(r.PathValue("n"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_step")
		return
	}
	res, err := h.Executor.ApproveStep(r.Context(), userID, planID, n)
	if err != nil {
		switch {
		case errors.Is(err, executor.ErrPlanNotReady):
			writeError(w, http.StatusConflict, "plan_not_ready")
		case errors.Is(err, executor.ErrStepOrder):
			writeError(w, http.StatusConflict, "step_order")
		case errors.Is(err, executor.ErrBadStep):
			writeError(w, http.StatusNotFound, "step_not_found")
		default:
			writeError(w, http.StatusBadGateway, "execute_failed")
		}
		return
	}
	out := stepExecResponse{
		Index:  res.Step.Index,
		Status: res.Step.Status,
		TxHash: res.TxHash,
	}
	if res.Step.Error != nil {
		out.Error = *res.Step.Error
	}
	writeJSON(w, http.StatusOK, out)
}
