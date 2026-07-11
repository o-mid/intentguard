package planner

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

const defaultLLMBaseURL = "https://api.openai.com/v1"
const defaultLLMModel = "gpt-4o-mini"

const systemPrompt = `You are IntentGuard's plan generator.
Given a user DeFi intent, return ONLY a JSON object matching this shape:
{
  "schemaVersion": "1",
  "summary": "short human summary",
  "steps": [ ... ]
}
Allowed step actions: approve, swap, transfer.
Use token symbols MOCK_USDC and MOCK_ETH, spender MockSwapRouter for swaps.
Never invent calldata or hex. Never include fields outside the schema.
No markdown fences. No commentary.`

// LLMPlanner calls an OpenAI-compatible chat completions API and parses a plan JSON.
// Output is still schema+policy validated by intentsvc before any execution.
type LLMPlanner struct {
	baseURL string
	apiKey  string
	model   string
	client  *http.Client
}

type LLMOptions struct {
	BaseURL    string
	APIKey     string
	Model      string
	HTTPClient *http.Client
}

func NewLLM(opts LLMOptions) (*LLMPlanner, error) {
	if strings.TrimSpace(opts.APIKey) == "" {
		return nil, fmt.Errorf("llm api key required")
	}
	base := strings.TrimRight(strings.TrimSpace(opts.BaseURL), "/")
	if base == "" {
		base = defaultLLMBaseURL
	}
	model := strings.TrimSpace(opts.Model)
	if model == "" {
		model = defaultLLMModel
	}
	client := opts.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	return &LLMPlanner{
		baseURL: base,
		apiKey:  opts.APIKey,
		model:   model,
		client:  client,
	}, nil
}

func (p *LLMPlanner) Plan(ctx context.Context, intentText string) (planschema.Plan, error) {
	raw, err := p.complete(ctx, intentText)
	if err != nil {
		return planschema.Plan{}, err
	}
	plan, err := planschema.Parse([]byte(raw))
	if err != nil {
		return planschema.Plan{}, fmt.Errorf("llm plan json: %w", err)
	}
	return plan, nil
}

type chatRequest struct {
	Model    string        `json:"model"`
	Messages []chatMessage `json:"messages"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

func (p *LLMPlanner) complete(ctx context.Context, intentText string) (string, error) {
	body, err := json.Marshal(chatRequest{
		Model: p.model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: intentText},
		},
	})
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+p.apiKey)
	req.Header.Set("Content-Type", "application/json")

	res, err := p.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("llm request: %w", err)
	}
	defer res.Body.Close()

	payload, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("llm read: %w", err)
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return "", fmt.Errorf("llm status %d: %s", res.StatusCode, truncate(string(payload), 200))
	}

	var parsed chatResponse
	if err := json.Unmarshal(payload, &parsed); err != nil {
		return "", fmt.Errorf("llm response json: %w", err)
	}
	if parsed.Error != nil && parsed.Error.Message != "" {
		return "", fmt.Errorf("llm api: %s", parsed.Error.Message)
	}
	if len(parsed.Choices) == 0 {
		return "", fmt.Errorf("llm empty choices")
	}
	return extractJSON(parsed.Choices[0].Message.Content), nil
}

func extractJSON(content string) string {
	s := strings.TrimSpace(content)
	if strings.HasPrefix(s, "```") {
		s = strings.TrimPrefix(s, "```json")
		s = strings.TrimPrefix(s, "```JSON")
		s = strings.TrimPrefix(s, "```")
		if i := strings.LastIndex(s, "```"); i >= 0 {
			s = s[:i]
		}
		s = strings.TrimSpace(s)
	}
	if i := strings.Index(s, "{"); i >= 0 {
		if j := strings.LastIndex(s, "}"); j > i {
			return s[i : j+1]
		}
	}
	return s
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
