package policy

import (
	"fmt"
	"math/big"
	"strings"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

type Code string

const (
	CodeTooManySteps     Code = "too_many_steps"
	CodeAmountOverCap    Code = "amount_over_cap"
	CodeBadToken         Code = "bad_token"
	CodeBadRecipient     Code = "bad_recipient"
	CodeBadSpender       Code = "bad_spender"
	CodeInfiniteApprove  Code = "infinite_approve"
	CodeSlippageTooHigh  Code = "slippage_too_high"
	CodeUnknownAction    Code = "unknown_action"
	CodeBadAmount        Code = "bad_amount"
)

type Violation struct {
	Code    Code   `json:"code"`
	Message string `json:"message"`
}

func (v Violation) Error() string {
	return fmt.Sprintf("%s: %s", v.Code, v.Message)
}

type Config struct {
	MaxSteps           int
	MaxAmount          *big.Rat // mock USDC-equivalent units
	AllowedTokens      map[string]struct{}
	AllowedRecipients  map[string]struct{}
	AllowedSpenders    map[string]struct{}
	AllowSelfRecipient bool
	SelfAddress        string
	MaxSlippageBps     int
}

func DefaultConfig() Config {
	return Config{
		MaxSteps: 5,
		MaxAmount: new(big.Rat).SetInt64(100),
		AllowedTokens: map[string]struct{}{
			"MOCK_USDC": {},
			"MOCK_ETH":  {},
		},
		AllowedRecipients: map[string]struct{}{
			"0x1111111111111111111111111111111111111111": {},
		},
		AllowedSpenders: map[string]struct{}{
			"MockSwapRouter": {},
		},
		AllowSelfRecipient: true,
		SelfAddress:        "self",
		MaxSlippageBps:     100,
	}
}

func Check(plan planschema.Plan, cfg Config) []Violation {
	var out []Violation

	if len(plan.Steps) > cfg.MaxSteps {
		out = append(out, Violation{
			Code:    CodeTooManySteps,
			Message: fmt.Sprintf("steps=%d max=%d", len(plan.Steps), cfg.MaxSteps),
		})
	}

	total := new(big.Rat)
	for i, step := range plan.Steps {
		vs := checkStep(step, i, cfg, total)
		out = append(out, vs...)
	}

	if cfg.MaxAmount != nil && total.Cmp(cfg.MaxAmount) > 0 {
		out = append(out, Violation{
			Code:    CodeAmountOverCap,
			Message: fmt.Sprintf("total=%s cap=%s", total.FloatString(8), cfg.MaxAmount.FloatString(8)),
		})
	}
	return out
}

func checkStep(step planschema.Step, index int, cfg Config, total *big.Rat) []Violation {
	var out []Violation
	switch step.Action {
	case "approve":
		out = append(out, checkToken(step.Token, index, cfg)...)
		if !allowed(cfg.AllowedSpenders, step.Spender) {
			out = append(out, Violation{Code: CodeBadSpender, Message: fmt.Sprintf("step=%d spender=%s", index, step.Spender)})
		}
		if isInfiniteApprove(step.Amount) {
			out = append(out, Violation{Code: CodeInfiniteApprove, Message: fmt.Sprintf("step=%d", index)})
		}
		if amt, err := parseAmount(step.Amount); err != nil {
			out = append(out, Violation{Code: CodeBadAmount, Message: fmt.Sprintf("step=%d", index)})
		} else {
			total.Add(total, amt)
		}
	case "swap":
		out = append(out, checkToken(step.TokenIn, index, cfg)...)
		out = append(out, checkToken(step.TokenOut, index, cfg)...)
		if step.MaxSlippageBps > cfg.MaxSlippageBps {
			out = append(out, Violation{
				Code:    CodeSlippageTooHigh,
				Message: fmt.Sprintf("step=%d bps=%d max=%d", index, step.MaxSlippageBps, cfg.MaxSlippageBps),
			})
		}
		if amt, err := parseAmount(step.AmountIn); err != nil {
			out = append(out, Violation{Code: CodeBadAmount, Message: fmt.Sprintf("step=%d", index)})
		} else {
			total.Add(total, amt)
		}
	case "transfer":
		out = append(out, checkToken(step.Token, index, cfg)...)
		if !recipientAllowed(step.To, cfg) {
			out = append(out, Violation{Code: CodeBadRecipient, Message: fmt.Sprintf("step=%d to=%s", index, step.To)})
		}
		if amt, err := parseAmount(step.Amount); err != nil {
			out = append(out, Violation{Code: CodeBadAmount, Message: fmt.Sprintf("step=%d", index)})
		} else {
			total.Add(total, amt)
		}
	default:
		// Unknown actions never pass — executor only maps allowlisted verbs.
		out = append(out, Violation{
			Code:    CodeUnknownAction,
			Message: fmt.Sprintf("step=%d action=%s", index, step.Action),
		})
	}
	return out
}

func checkToken(token string, index int, cfg Config) []Violation {
	if allowed(cfg.AllowedTokens, token) {
		return nil
	}
	return []Violation{{Code: CodeBadToken, Message: fmt.Sprintf("step=%d token=%s", index, token)}}
}

func recipientAllowed(to string, cfg Config) bool {
	if cfg.AllowSelfRecipient && (to == cfg.SelfAddress || strings.EqualFold(to, "self")) {
		return true
	}
	return allowed(cfg.AllowedRecipients, to)
}

func allowed(set map[string]struct{}, value string) bool {
	_, ok := set[value]
	return ok
}

func parseAmount(s string) (*big.Rat, error) {
	r := new(big.Rat)
	if _, ok := r.SetString(s); !ok {
		return nil, fmt.Errorf("bad amount")
	}
	if r.Sign() < 0 {
		return nil, fmt.Errorf("negative amount")
	}
	return r, nil
}

// Treats common "unlimited" encodings as infinite approve.
func isInfiniteApprove(amount string) bool {
	a := strings.TrimSpace(strings.ToLower(amount))
	switch a {
	case "max", "unlimited", "infinite", "uint256_max":
		return true
	}
	// 2^256-1 decimal
	if a == "115792089237316195423570985008687907853269984665640564039457584007913129639935" {
		return true
	}
	return false
}
