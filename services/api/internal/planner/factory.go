package planner

import (
	"fmt"
	"strings"
)

const (
	ModeMock = "mock"
	ModeLLM  = "llm"
)

// NewFromMode returns MockPlanner for CI/local default, or LLMPlanner when mode=llm.
func NewFromMode(mode string, opts LLMOptions) (Planner, error) {
	switch strings.ToLower(strings.TrimSpace(mode)) {
	case "", ModeMock:
		return NewMock(), nil
	case ModeLLM:
		return NewLLM(opts)
	default:
		return nil, fmt.Errorf("unknown PLANNER_MODE %q (want mock|llm)", mode)
	}
}
