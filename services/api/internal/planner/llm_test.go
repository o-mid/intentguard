package planner

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
)

func TestLLMPlanner_happyPath(t *testing.T) {
	planJSON := `{
		"schemaVersion":"1",
		"summary":"Swap 10 MOCK_USDC",
		"steps":[
			{"action":"approve","token":"MOCK_USDC","spender":"MockSwapRouter","amount":"10"},
			{"action":"swap","tokenIn":"MOCK_USDC","tokenOut":"MOCK_ETH","amountIn":"10","minAmountOut":"0.009","maxSlippageBps":100}
		]
	}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/chat/completions" {
			t.Fatalf("path=%s", r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer sk-test" {
			t.Fatalf("auth=%q", got)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"choices": []map[string]any{
				{"message": map[string]string{"role": "assistant", "content": planJSON}},
			},
		})
	}))
	defer srv.Close()

	p, err := NewLLM(LLMOptions{
		BaseURL:    srv.URL,
		APIKey:     "sk-test",
		HTTPClient: srv.Client(),
	})
	if err != nil {
		t.Fatal(err)
	}
	plan, err := p.Plan(context.Background(), "swap 10 USDC")
	if err != nil {
		t.Fatal(err)
	}
	if plan.Summary == "" || len(plan.Steps) != 2 {
		t.Fatalf("plan=%+v", plan)
	}
}

func TestLLMPlanner_stripsMarkdownFence(t *testing.T) {
	content := "```json\n{\"schemaVersion\":\"1\",\"summary\":\"Transfer\",\"steps\":[{\"action\":\"transfer\",\"token\":\"MOCK_USDC\",\"to\":\"0x1111111111111111111111111111111111111111\",\"amount\":\"5\"}]}\n```"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"choices": []map[string]any{
				{"message": map[string]string{"content": content}},
			},
		})
	}))
	defer srv.Close()

	p, err := NewLLM(LLMOptions{BaseURL: srv.URL, APIKey: "k", HTTPClient: srv.Client()})
	if err != nil {
		t.Fatal(err)
	}
	plan, err := p.Plan(context.Background(), "transfer 5 USDC")
	if err != nil {
		t.Fatal(err)
	}
	if len(plan.Steps) != 1 || plan.Steps[0].Action != "transfer" {
		t.Fatalf("steps=%+v", plan.Steps)
	}
}

func TestLLMPlanner_retriesThenUnavailable(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.WriteHeader(http.StatusBadGateway)
		_, _ = io.WriteString(w, `{"error":{"message":"upstream"}}`)
	}))
	defer srv.Close()

	p, err := NewLLM(LLMOptions{BaseURL: srv.URL, APIKey: "k", HTTPClient: srv.Client()})
	if err != nil {
		t.Fatal(err)
	}
	_, err = p.Plan(context.Background(), "swap 10 USDC")
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err=%v want ErrUnavailable", err)
	}
	if hits.Load() != 2 {
		t.Fatalf("hits=%d want 2", hits.Load())
	}
}

func TestLLMPlanner_badJSONUnavailable(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"choices": []map[string]any{
				{"message": map[string]string{"content": "not a plan"}},
			},
		})
	}))
	defer srv.Close()

	p, err := NewLLM(LLMOptions{BaseURL: srv.URL, APIKey: "k", HTTPClient: srv.Client()})
	if err != nil {
		t.Fatal(err)
	}
	_, err = p.Plan(context.Background(), "swap 10 USDC")
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err=%v want ErrUnavailable", err)
	}
}

func TestLLMPlanner_noRetryOnClientError(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = io.WriteString(w, `{"error":{"message":"bad key"}}`)
	}))
	defer srv.Close()

	p, err := NewLLM(LLMOptions{BaseURL: srv.URL, APIKey: "k", HTTPClient: srv.Client()})
	if err != nil {
		t.Fatal(err)
	}
	_, err = p.Plan(context.Background(), "swap 10 USDC")
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err=%v", err)
	}
	if hits.Load() != 1 {
		t.Fatalf("hits=%d want 1", hits.Load())
	}
}
