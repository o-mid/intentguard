package intentsvc

import (
	"context"
	"encoding/json"
	"strconv"
	"sync"
	"testing"

	"github.com/o-mid/intentguard/services/api/internal/planner"
	"github.com/o-mid/intentguard/services/api/internal/policy"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

type memIntents struct {
	mu   sync.Mutex
	byID map[string]store.Intent
	seq  int
}

func newMemIntents() *memIntents {
	return &memIntents{byID: map[string]store.Intent{}}
}

func (m *memIntents) Create(_ context.Context, userID, text, status string) (store.Intent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seq++
	id := "intent-" + strconv.Itoa(m.seq)
	in := store.Intent{ID: id, UserID: userID, Text: text, Status: status}
	m.byID[id] = in
	return in, nil
}

func (m *memIntents) UpdateStatus(_ context.Context, id, status string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	in, ok := m.byID[id]
	if !ok {
		return store.ErrNotFound
	}
	in.Status = status
	m.byID[id] = in
	return nil
}

func (m *memIntents) ListByUser(_ context.Context, userID string) ([]store.IntentPlanRef, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []store.IntentPlanRef
	for _, in := range m.byID {
		if in.UserID != userID {
			continue
		}
		out = append(out, store.IntentPlanRef{Intent: in, PlanID: ""})
	}
	return out, nil
}

type memPlans struct {
	mu   sync.Mutex
	byID map[string]store.Plan
	seq  int
}

func newMemPlans() *memPlans {
	return &memPlans{byID: map[string]store.Plan{}}
}

func (m *memPlans) Create(_ context.Context, p store.Plan, steps []store.PlanStep) (store.Plan, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seq++
	p.ID = "plan-" + strconv.Itoa(m.seq)
	for i := range steps {
		steps[i].ID = "step-" + strconv.Itoa(m.seq) + "-" + strconv.Itoa(i)
		steps[i].PlanID = p.ID
	}
	p.Steps = steps
	m.byID[p.ID] = p
	return p, nil
}

func (m *memPlans) ByIDForUser(_ context.Context, planID, _ string) (store.Plan, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.byID[planID]
	if !ok {
		return store.Plan{}, store.ErrNotFound
	}
	return p, nil
}

func (m *memPlans) CancelForUser(_ context.Context, planID, _ string) (store.Plan, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.byID[planID]
	if !ok {
		return store.Plan{}, store.ErrNotFound
	}
	if p.Status != StatusAwaitingApproval && p.Status != "executing" {
		return store.Plan{}, store.ErrNotFound
	}
	p.Status = "cancelled"
	m.byID[planID] = p
	return p, nil
}

func newService() Service {
	return Service{
		Intents: newMemIntents(),
		Plans:   newMemPlans(),
		Planner: planner.NewMock(),
		Policy:  policy.DefaultConfig(),
	}
}

func TestSubmit_swapHappyPath(t *testing.T) {
	svc := newService()
	res, err := svc.Submit(context.Background(), "user-1", planner.FixtureSwap10USDC)
	if err != nil {
		t.Fatal(err)
	}
	if res.Plan.Status != StatusAwaitingApproval {
		t.Fatalf("status=%s", res.Plan.Status)
	}
	if len(res.Plan.Steps) != 2 {
		t.Fatalf("steps=%d", len(res.Plan.Steps))
	}
	if res.Plan.Steps[0].Action != "approve" || res.Plan.Steps[1].Action != "swap" {
		t.Fatalf("actions=%s,%s", res.Plan.Steps[0].Action, res.Plan.Steps[1].Action)
	}
}

func TestSubmit_rejects(t *testing.T) {
	tests := []struct {
		name   string
		text   string
		status string
		code   string
	}{
		{name: "rejected_schema", text: planner.FixtureBridge, status: StatusRejectedSchema, code: "schema_invalid"},
		{name: "rejected_policy_recipient", text: planner.FixtureTransferUnknown, status: StatusRejectedPolicy, code: "bad_recipient"},
		{name: "rejected_policy_cap", text: planner.FixtureSwapOverCap, status: StatusRejectedPolicy, code: "amount_over_cap"},
		{name: "rejected_schema_infinite", text: planner.FixtureInfiniteApprove, status: StatusRejectedSchema, code: "schema_invalid"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := newService()
			res, err := svc.Submit(context.Background(), "user-1", tt.text)
			if err != nil {
				t.Fatal(err)
			}
			if res.Plan.Status != tt.status {
				t.Fatalf("status=%s want %s", res.Plan.Status, tt.status)
			}
			var reasons []string
			if err := json.Unmarshal(res.Plan.RejectionReasons, &reasons); err != nil {
				t.Fatal(err)
			}
			found := false
			for _, r := range reasons {
				if r == tt.code {
					found = true
					break
				}
			}
			if !found {
				t.Fatalf("reasons=%v want %s", reasons, tt.code)
			}
		})
	}
}
