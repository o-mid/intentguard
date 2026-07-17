package executor

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

var (
	erc20ABI = mustABI(`[
		{"name":"approve","type":"function","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"type":"bool"}]},
		{"name":"transfer","type":"function","stateMutability":"nonpayable","inputs":[{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"type":"bool"}]}
	]`)
	routerABI = mustABI(`[
		{"name":"swap","type":"function","stateMutability":"nonpayable","inputs":[
			{"name":"tokenIn","type":"address"},
			{"name":"tokenOut","type":"address"},
			{"name":"amountIn","type":"uint256"},
			{"name":"minAmountOut","type":"uint256"}
		],"outputs":[{"name":"amountOut","type":"uint256"}]}
	]`)
)

type Call struct {
	To   common.Address
	Data []byte
}

func EncodeStep(step planschema.Step, d Deployments) (Call, error) {
	switch step.Action {
	case "approve":
		token, err := d.Token(step.Token)
		if err != nil {
			return Call{}, err
		}
		spender, err := d.Spender(step.Spender)
		if err != nil {
			return Call{}, err
		}
		amount, err := ParseAmount(step.Amount, 18)
		if err != nil {
			return Call{}, err
		}
		data, err := erc20ABI.Pack("approve", spender, amount)
		if err != nil {
			return Call{}, err
		}
		return Call{To: token, Data: data}, nil

	case "transfer":
		token, err := d.Token(step.Token)
		if err != nil {
			return Call{}, err
		}
		to := resolveRecipient(step.To, d)
		amount, err := ParseAmount(step.Amount, 18)
		if err != nil {
			return Call{}, err
		}
		data, err := erc20ABI.Pack("transfer", to, amount)
		if err != nil {
			return Call{}, err
		}
		return Call{To: token, Data: data}, nil

	case "swap":
		tokenIn, err := d.Token(step.TokenIn)
		if err != nil {
			return Call{}, err
		}
		tokenOut, err := d.Token(step.TokenOut)
		if err != nil {
			return Call{}, err
		}
		amountIn, err := ParseAmount(step.AmountIn, 18)
		if err != nil {
			return Call{}, err
		}
		minOut, err := ParseAmount(step.MinAmountOut, 18)
		if err != nil {
			return Call{}, err
		}
		data, err := routerABI.Pack("swap", tokenIn, tokenOut, amountIn, minOut)
		if err != nil {
			return Call{}, err
		}
		return Call{To: d.Router(), Data: data}, nil

	default:
		return Call{}, fmt.Errorf("unknown action %q", step.Action)
	}
}

func ParseAmount(decimal string, decimals int) (*big.Int, error) {
	s := strings.TrimSpace(decimal)
	if s == "" {
		return nil, fmt.Errorf("empty amount")
	}
	parts := strings.Split(s, ".")
	if len(parts) > 2 {
		return nil, fmt.Errorf("bad amount %q", decimal)
	}
	whole := parts[0]
	frac := ""
	if len(parts) == 2 {
		frac = parts[1]
	}
	if len(frac) > decimals {
		return nil, fmt.Errorf("too many decimals in %q", decimal)
	}
	frac = frac + strings.Repeat("0", decimals-len(frac))
	joined := whole + frac
	joined = strings.TrimLeft(joined, "0")
	if joined == "" {
		return big.NewInt(0), nil
	}
	n, ok := new(big.Int).SetString(joined, 10)
	if !ok {
		return nil, fmt.Errorf("bad amount %q", decimal)
	}
	return n, nil
}

func resolveRecipient(to string, d Deployments) common.Address {
	if strings.EqualFold(to, "self") {
		return common.HexToAddress(d.DemoAccount)
	}
	return common.HexToAddress(to)
}

func mustABI(raw string) abi.ABI {
	parsed, err := abi.JSON(strings.NewReader(raw))
	if err != nil {
		panic(err)
	}
	return parsed
}
