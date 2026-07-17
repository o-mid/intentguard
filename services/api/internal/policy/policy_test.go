package policy

import (
	"math/big"
	"testing"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

func hasCode(vs []Violation, code Code) bool {
	for _, v := range vs {
		if v.Code == code {
			return true
		}
	}
	return false
}

func TestCheck(t *testing.T) {
	cfg := DefaultConfig()

	tests := []struct {
		name    string
		plan    planschema.Plan
		wantCode Code
		wantOK  bool
	}{
		{
			name: "ok",
			plan: planschema.Plan{
				SchemaVersion: "1",
				Summary:       "swap",
				Steps: []planschema.Step{
					{Action: "approve", Token: "MOCK_USDC", Spender: "MockSwapRouter", Amount: "10"},
					{Action: "swap", TokenIn: "MOCK_USDC", TokenOut: "MOCK_ETH", AmountIn: "10", MinAmountOut: "0.009", MaxSlippageBps: 50},
				},
			},
			wantOK: true,
		},
		{
			name: "over_cap",
			plan: planschema.Plan{
				SchemaVersion: "1",
				Summary:       "big swap",
				Steps: []planschema.Step{
					{Action: "approve", Token: "MOCK_USDC", Spender: "MockSwapRouter", Amount: "80"},
					{Action: "swap", TokenIn: "MOCK_USDC", TokenOut: "MOCK_ETH", AmountIn: "80", MinAmountOut: "0.01", MaxSlippageBps: 50},
				},
			},
			wantCode: CodeAmountOverCap,
		},
		{
			name: "bad_action",
			plan: planschema.Plan{
				SchemaVersion: "1",
				Summary:       "bridge",
				Steps: []planschema.Step{
					{Action: "bridge", Token: "MOCK_USDC", Amount: "1", To: "self"},
				},
			},
			wantCode: CodeUnknownAction,
		},
		{
			name: "infinite_approve",
			plan: planschema.Plan{
				SchemaVersion: "1",
				Summary:       "unlimited",
				Steps: []planschema.Step{
					{Action: "approve", Token: "MOCK_USDC", Spender: "MockSwapRouter", Amount: "unlimited"},
				},
			},
			wantCode: CodeInfiniteApprove,
		},
		{
			name: "bad_recipient",
			plan: planschema.Plan{
				SchemaVersion: "1",
				Summary:       "send away",
				Steps: []planschema.Step{
					{Action: "transfer", Token: "MOCK_USDC", To: "0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddead", Amount: "1"},
				},
			},
			wantCode: CodeBadRecipient,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vs := Check(tt.plan, cfg)
			if tt.wantOK {
				if len(vs) != 0 {
					t.Fatalf("violations=%v", vs)
				}
				return
			}
			if !hasCode(vs, tt.wantCode) {
				t.Fatalf("want %s got %v", tt.wantCode, vs)
			}
		})
	}
}

func TestCheck_customCap(t *testing.T) {
	cfg := DefaultConfig()
	cfg.MaxAmount = big.NewRat(5, 1)
	plan := planschema.Plan{
		Steps: []planschema.Step{
			{Action: "transfer", Token: "MOCK_USDC", To: "self", Amount: "6"},
		},
	}
	vs := Check(plan, cfg)
	if !hasCode(vs, CodeAmountOverCap) {
		t.Fatalf("got %v", vs)
	}
}
