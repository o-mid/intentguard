package planschema

import (
	"encoding/json"
)

type Plan struct {
	SchemaVersion string `json:"schemaVersion"`
	Summary       string `json:"summary"`
	Steps         []Step `json:"steps"`
}

type Step struct {
	Action string `json:"action"`

	// approve / transfer
	Token  string `json:"token,omitempty"`
	Amount string `json:"amount,omitempty"`

	// approve
	Spender string `json:"spender,omitempty"`

	// transfer
	To string `json:"to,omitempty"`

	// swap
	TokenIn         string `json:"tokenIn,omitempty"`
	TokenOut        string `json:"tokenOut,omitempty"`
	AmountIn        string `json:"amountIn,omitempty"`
	MinAmountOut    string `json:"minAmountOut,omitempty"`
	MaxSlippageBps  int    `json:"maxSlippageBps,omitempty"`
}

func Parse(raw []byte) (Plan, error) {
	var p Plan
	if err := json.Unmarshal(raw, &p); err != nil {
		return Plan{}, err
	}
	return p, nil
}
