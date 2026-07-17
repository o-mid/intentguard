package planner

import (
	"context"
	"fmt"
	"regexp"
	"strings"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

// MockPlanner returns deterministic plans from keyword fixtures.
// No network. Used as the default planner until a real provider is wired.
type MockPlanner struct{}

func NewMock() *MockPlanner {
	return &MockPlanner{}
}

var amountRe = regexp.MustCompile(`(?i)(\d+(?:\.\d+)?)\s*usdc`)

func (m *MockPlanner) Plan(_ context.Context, intentText string) (planschema.Plan, error) {
	text := strings.TrimSpace(intentText)
	lower := strings.ToLower(text)

	switch {
	case strings.Contains(lower, "infinite approve"), strings.Contains(lower, "unlimited approve"):
		return planschema.Plan{
			SchemaVersion: "1",
			Summary:       "Approve unlimited MOCK_USDC",
			Steps: []planschema.Step{
				{
					Action:  "approve",
					Token:   "MOCK_USDC",
					Spender: "MockSwapRouter",
					Amount:  "unlimited",
				},
			},
		}, nil

	case strings.Contains(lower, "bridge"):
		// Intentionally invalid against schema (unknown action).
		return planschema.Plan{
			SchemaVersion: "1",
			Summary:       "Bridge funds",
			Steps: []planschema.Step{
				{
					Action: "bridge",
					Token:  "MOCK_USDC",
					Amount: "1",
					To:     "self",
				},
			},
		}, nil

	case strings.Contains(lower, "transfer") && strings.Contains(lower, "unknown"):
		return planschema.Plan{
			SchemaVersion: "1",
			Summary:       "Transfer to unknown recipient",
			Steps: []planschema.Step{
				{
					Action: "transfer",
					Token:  "MOCK_USDC",
					To:     "0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddead",
					Amount: "5",
				},
			},
		}, nil

	case strings.Contains(lower, "swap"):
		amount := "10"
		if m := amountRe.FindStringSubmatch(lower); len(m) == 2 {
			amount = m[1]
		}
		return planschema.Plan{
			SchemaVersion: "1",
			Summary:       fmt.Sprintf("Swap %s MOCK_USDC to MOCK_ETH", amount),
			Steps: []planschema.Step{
				{
					Action:  "approve",
					Token:   "MOCK_USDC",
					Spender: "MockSwapRouter",
					Amount:  amount,
				},
				{
					Action:         "swap",
					TokenIn:        "MOCK_USDC",
					TokenOut:       "MOCK_ETH",
					AmountIn:       amount,
					MinAmountOut:   "0.009",
					MaxSlippageBps: 100,
				},
			},
		}, nil

	case strings.Contains(lower, "transfer"):
		return planschema.Plan{
			SchemaVersion: "1",
			Summary:       "Transfer 5 MOCK_USDC to allowlisted recipient",
			Steps: []planschema.Step{
				{
					Action: "transfer",
					Token:  "MOCK_USDC",
					To:     "0x1111111111111111111111111111111111111111",
					Amount: "5",
				},
			},
		}, nil

	default:
		return planschema.Plan{}, fmt.Errorf("unsupported intent")
	}
}
