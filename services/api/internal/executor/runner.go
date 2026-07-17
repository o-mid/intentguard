package executor

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

const (
	StepPending    = "pending"
	StepApproved   = "approved"
	StepSubmitting = "submitting"
	StepSucceeded  = "succeeded"
	StepFailed     = "failed"
)

var (
	ErrPlanNotReady = errors.New("plan not awaiting approval")
	ErrStepOrder    = errors.New("prior steps incomplete")
	ErrBadStep      = errors.New("step not found")
)

type stepStore interface {
	ByIDForUser(ctx context.Context, planID, userID string) (store.Plan, error)
	ClaimStep(ctx context.Context, planID string, index int) (store.PlanStep, error)
	FinishStep(ctx context.Context, planID string, index int, status string, txHash, errMsg *string) (store.PlanStep, error)
}

type Runner struct {
	Plans       stepStore
	Chain       *Chain
	Deployments Deployments
}

type ExecResult struct {
	Step   store.PlanStep
	TxHash string
}

func (r Runner) ApproveStep(ctx context.Context, userID, planID string, index int) (ExecResult, error) {
	plan, err := r.Plans.ByIDForUser(ctx, planID, userID)
	if err != nil {
		return ExecResult{}, err
	}
	if plan.Status != "awaiting_approval" && plan.Status != "executing" {
		return ExecResult{}, ErrPlanNotReady
	}
	if index < 0 || index >= len(plan.Steps) {
		return ExecResult{}, ErrBadStep
	}
	for i := 0; i < index; i++ {
		if plan.Steps[i].Status != StepSucceeded {
			return ExecResult{}, ErrStepOrder
		}
	}

	step := plan.Steps[index]
	// Idempotent: already mined — return the same result without re-sending.
	if step.Status == StepSucceeded {
		hash := ""
		if step.TxHash != nil {
			hash = *step.TxHash
		}
		return ExecResult{Step: step, TxHash: hash}, nil
	}

	var payload planschema.Step
	if err := json.Unmarshal(step.PayloadJSON, &payload); err != nil {
		return ExecResult{}, err
	}
	call, err := EncodeStep(payload, r.Deployments)
	if err != nil {
		return ExecResult{}, err
	}

	if _, err := r.Plans.ClaimStep(ctx, planID, index); err != nil {
		// Another request won the claim; if it finished, surface that result.
		plan, _ = r.Plans.ByIDForUser(ctx, planID, userID)
		if index < len(plan.Steps) && plan.Steps[index].Status == StepSucceeded {
			st := plan.Steps[index]
			hash := ""
			if st.TxHash != nil {
				hash = *st.TxHash
			}
			return ExecResult{Step: st, TxHash: hash}, nil
		}
		return ExecResult{}, err
	}

	txHash, err := r.Chain.Send(ctx, call)
	if err != nil {
		msg := err.Error()
		st, _ := r.Plans.FinishStep(ctx, planID, index, StepFailed, nil, &msg)
		return ExecResult{Step: st}, err
	}
	receipt, err := r.Chain.WaitReceipt(ctx, txHash)
	if err != nil {
		msg := err.Error()
		hash := txHash.Hex()
		st, _ := r.Plans.FinishStep(ctx, planID, index, StepFailed, &hash, &msg)
		return ExecResult{Step: st, TxHash: hash}, err
	}
	hash := txHash.Hex()
	if receipt.Status != 1 {
		msg := "transaction reverted"
		st, _ := r.Plans.FinishStep(ctx, planID, index, StepFailed, &hash, &msg)
		return ExecResult{Step: st, TxHash: hash}, fmt.Errorf("%s", msg)
	}
	st, err := r.Plans.FinishStep(ctx, planID, index, StepSucceeded, &hash, nil)
	if err != nil {
		return ExecResult{}, err
	}
	return ExecResult{Step: st, TxHash: hash}, nil
}
