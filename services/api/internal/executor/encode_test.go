package executor

import (
	"math/big"
	"testing"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

func testDeployments() Deployments {
	return Deployments{
		ChainID:     31337,
		DemoAccount: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
		Tokens: map[string]string{
			"MOCK_USDC": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
			"MOCK_ETH":  "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
		},
		MockSwapRouter: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
	}
}

func TestParseAmount(t *testing.T) {
	n, err := ParseAmount("10", 18)
	if err != nil {
		t.Fatal(err)
	}
	want := new(big.Int).Exp(big.NewInt(10), big.NewInt(19), nil) // 10 * 10^18
	if n.Cmp(want) != 0 {
		t.Fatalf("got %s want %s", n, want)
	}
}

func TestEncodeApproveAndSwap(t *testing.T) {
	d := testDeployments()
	approve, err := EncodeStep(planschema.Step{
		Action: "approve", Token: "MOCK_USDC", Spender: "MockSwapRouter", Amount: "10",
	}, d)
	if err != nil {
		t.Fatal(err)
	}
	if approve.To.Hex() != d.Tokens["MOCK_USDC"] {
		t.Fatalf("to=%s", approve.To.Hex())
	}
	if len(approve.Data) < 4 {
		t.Fatal("missing calldata")
	}

	swap, err := EncodeStep(planschema.Step{
		Action: "swap", TokenIn: "MOCK_USDC", TokenOut: "MOCK_ETH",
		AmountIn: "10", MinAmountOut: "0.009", MaxSlippageBps: 100,
	}, d)
	if err != nil {
		t.Fatal(err)
	}
	if swap.To.Hex() != d.MockSwapRouter {
		t.Fatalf("router=%s", swap.To.Hex())
	}
}
