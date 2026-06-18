package intentsvc

import (
	"context"
	"encoding/json"
	"fmt"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
	"github.com/o-mid/intentguard/services/api/internal/planner"
	"github.com/o-mid/intentguard/services/api/internal/policy"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

const (
	StatusPlanning         = "planning"
	StatusAwaitingApproval = "awaiting_approval"
	StatusRejectedSchema   = "rejected_schema"
	StatusRejectedPolicy   = "rejected_policy"
	StepPending            = "pending"
)

type intentStore interface {
	Create(ctx context.Context, userID, text, status string) (store.Intent, error)
	UpdateStatus(ctx context.Context, id, status string) error
}

type planStore interface {
	Create(ctx context.Context, p store.Plan, steps []store.PlanStep) (store.Plan, error)
	ByIDForUser(ctx context.Context, planID, userID string) (store.Plan, error)
}

type Service struct {
	Intents intentStore
	Plans   planStore
	Planner planner.Planner
	Policy  policy.Config
}

type Result struct {
	Intent store.Intent
	Plan   store.Plan
}

func (s Service) Submit(ctx context.Context, userID, text string) (Result, error) {
	intent, err := s.Intents.Create(ctx, userID, text, StatusPlanning)
	if err != nil {
		return Result{}, err
	}

	planned, err := s.Planner.Plan(ctx, text)
	if err != nil {
		_ = s.Intents.UpdateStatus(ctx, intent.ID, StatusRejectedSchema)
		return Result{}, fmt.Errorf("planner: %w", err)
	}

	raw, err := json.Marshal(planned)
	if err != nil {
		return Result{}, err
	}

	if err := planschema.ValidateJSON(raw); err != nil {
		plan, perr := s.persistRejected(ctx, intent.ID, planned, raw, StatusRejectedSchema, []string{"schema_invalid"})
		if perr != nil {
			return Result{}, perr
		}
		intent.Status = StatusRejectedSchema
		_ = s.Intents.UpdateStatus(ctx, intent.ID, StatusRejectedSchema)
		return Result{Intent: intent, Plan: plan}, nil
	}

	violations := policy.Check(planned, s.Policy)
	if len(violations) > 0 {
		reasons := rejectionCodes(violations)
		plan, perr := s.persistRejected(ctx, intent.ID, planned, raw, StatusRejectedPolicy, reasons)
		if perr != nil {
			return Result{}, perr
		}
		intent.Status = StatusRejectedPolicy
		_ = s.Intents.UpdateStatus(ctx, intent.ID, StatusRejectedPolicy)
		return Result{Intent: intent, Plan: plan}, nil
	}

	steps := make([]store.PlanStep, 0, len(planned.Steps))
	for i, st := range planned.Steps {
		payload, err := json.Marshal(st)
		if err != nil {
			return Result{}, err
		}
		steps = append(steps, store.PlanStep{
			Index:          i,
			Action:         st.Action,
			PayloadJSON:    payload,
			DecodedSummary: decodeSummary(st),
			Status:         StepPending,
		})
	}

	plan, err := s.Plans.Create(ctx, store.Plan{
		IntentID:         intent.ID,
		SchemaVersion:    planned.SchemaVersion,
		Status:           StatusAwaitingApproval,
		Summary:          planned.Summary,
		RawModelJSON:     raw,
		RejectionReasons: json.RawMessage("[]"),
	}, steps)
	if err != nil {
		return Result{}, err
	}
	intent.Status = StatusAwaitingApproval
	_ = s.Intents.UpdateStatus(ctx, intent.ID, StatusAwaitingApproval)
	return Result{Intent: intent, Plan: plan}, nil
}

func (s Service) GetPlan(ctx context.Context, userID, planID string) (store.Plan, error) {
	return s.Plans.ByIDForUser(ctx, planID, userID)
}

func (s Service) persistRejected(ctx context.Context, intentID string, planned planschema.Plan, raw []byte, status string, reasons []string) (store.Plan, error) {
	reasonsJSON, err := json.Marshal(reasons)
	if err != nil {
		return store.Plan{}, err
	}
	steps := make([]store.PlanStep, 0, len(planned.Steps))
	for i, st := range planned.Steps {
		payload, err := json.Marshal(st)
		if err != nil {
			return store.Plan{}, err
		}
		steps = append(steps, store.PlanStep{
			Index:          i,
			Action:         st.Action,
			PayloadJSON:    payload,
			DecodedSummary: decodeSummary(st),
			Status:         status,
		})
	}
	return s.Plans.Create(ctx, store.Plan{
		IntentID:         intentID,
		SchemaVersion:    planned.SchemaVersion,
		Status:           status,
		Summary:          planned.Summary,
		RawModelJSON:     raw,
		RejectionReasons: reasonsJSON,
	}, steps)
}

func rejectionCodes(vs []policy.Violation) []string {
	out := make([]string, 0, len(vs))
	seen := map[string]struct{}{}
	for _, v := range vs {
		code := string(v.Code)
		if _, ok := seen[code]; ok {
			continue
		}
		seen[code] = struct{}{}
		out = append(out, code)
	}
	return out
}

func decodeSummary(st planschema.Step) string {
	switch st.Action {
	case "approve":
		return fmt.Sprintf("Approve %s %s for %s", st.Amount, st.Token, st.Spender)
	case "swap":
		return fmt.Sprintf("Swap %s %s → %s", st.AmountIn, st.TokenIn, st.TokenOut)
	case "transfer":
		return fmt.Sprintf("Transfer %s %s to %s", st.Amount, st.Token, st.To)
	default:
		return st.Action
	}
}
