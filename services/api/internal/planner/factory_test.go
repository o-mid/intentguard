package planner

import "testing"

func TestNewFromMode_defaultMock(t *testing.T) {
	p, err := NewFromMode("", LLMOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := p.(*MockPlanner); !ok {
		t.Fatalf("got %T want *MockPlanner", p)
	}
}

func TestNewFromMode_llmNeedsKey(t *testing.T) {
	if _, err := NewFromMode(ModeLLM, LLMOptions{}); err == nil {
		t.Fatal("expected error")
	}
}

func TestNewFromMode_llmOk(t *testing.T) {
	p, err := NewFromMode(ModeLLM, LLMOptions{APIKey: "sk-test"})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := p.(*LLMPlanner); !ok {
		t.Fatalf("got %T want *LLMPlanner", p)
	}
}
