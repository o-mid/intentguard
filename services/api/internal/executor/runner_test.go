package executor

import (
	"context"
	"encoding/json"
	"testing"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

type memSteps struct {
	plan store.Plan
}

func (m *memSteps) ByIDForUser(context.Context, string, string) (store.Plan, error) {
	return m.plan, nil
}

func (m *memSteps) ClaimStep(_ context.Context, _ string, index int) (store.PlanStep, error) {
	st := m.plan.Steps[index]
	if st.Status == StepSucceeded || st.Status == StepSubmitting {
		return store.PlanStep{}, store.ErrConflict
	}
	st.Status = StepSubmitting
	m.plan.Steps[index] = st
	return st, nil
}

func (m *memSteps) FinishStep(_ context.Context, _ string, index int, status string, txHash, errMsg *string) (store.PlanStep, error) {
	st := m.plan.Steps[index]
	st.Status = status
	st.TxHash = txHash
	st.Error = errMsg
	m.plan.Steps[index] = st
	return st, nil
}

func TestApproveStep_idempotentSucceeded(t *testing.T) {
	hash := "0xabc"
	payload, _ := json.Marshal(planschema.Step{Action: "approve", Token: "MOCK_USDC", Spender: "MockSwapRouter", Amount: "1"})
	r := Runner{
		Plans: &memSteps{plan: store.Plan{
			Status: "awaiting_approval",
			Steps: []store.PlanStep{{
				Index: 0, Action: "approve", Status: StepSucceeded, TxHash: &hash, PayloadJSON: payload,
			}},
		}},
		Deployments: testDeployments(),
	}
	res, err := r.ApproveStep(context.Background(), "u", "p", 0)
	if err != nil {
		t.Fatal(err)
	}
	if res.TxHash != hash || res.Step.Status != StepSucceeded {
		t.Fatalf("got %+v", res)
	}
}
