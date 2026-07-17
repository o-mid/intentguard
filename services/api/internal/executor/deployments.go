package executor

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
)

type Deployments struct {
	ChainID        int64             `json:"chainId"`
	RPCURL         string            `json:"rpcUrl"`
	DemoAccount    string            `json:"demoAccount"`
	Tokens         map[string]string `json:"tokens"`
	MockSwapRouter string            `json:"MockSwapRouter"`
}

func LoadDeployments(path string) (Deployments, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return Deployments{}, err
	}
	var d Deployments
	if err := json.Unmarshal(raw, &d); err != nil {
		return Deployments{}, err
	}
	if d.MockSwapRouter == "" || len(d.Tokens) == 0 {
		return Deployments{}, fmt.Errorf("deployments incomplete: %s", path)
	}
	return d, nil
}

func (d Deployments) Token(symbol string) (common.Address, error) {
	addr, ok := d.Tokens[symbol]
	if !ok || addr == "" {
		return common.Address{}, fmt.Errorf("unknown token %q", symbol)
	}
	return common.HexToAddress(addr), nil
}

func (d Deployments) Spender(name string) (common.Address, error) {
	switch strings.TrimSpace(name) {
	case "MockSwapRouter":
		return common.HexToAddress(d.MockSwapRouter), nil
	default:
		if common.IsHexAddress(name) {
			return common.HexToAddress(name), nil
		}
		return common.Address{}, fmt.Errorf("unknown spender %q", name)
	}
}

func (d Deployments) Router() common.Address {
	return common.HexToAddress(d.MockSwapRouter)
}
