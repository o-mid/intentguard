package planner

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

const defaultLLMBaseURL = "https://api.openai.com/v1"
const defaultLLMModel = "gpt-4o-mini"
const defaultLLMTimeout = 15 * time.Second

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
	Timeout    time.Duration
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
		timeout := opts.Timeout
		if timeout <= 0 {
			timeout = defaultLLMTimeout
		}
		client = &http.Client{Timeout: timeout}
	}
	return &LLMPlanner{
		baseURL: base,
		apiKey:  opts.APIKey,
		model:   model,
		client:  client,
	}, nil
}

func (p *LLMPlanner) Plan(ctx context.Context, intentText string) (planschema.Plan, error) {
	var last error
	for attempt := 0; attempt < 2; attempt++ {
		plan, err := p.planOnce(ctx, intentText)
		if err == nil {
			return plan, nil
		}
		last = err
		if !isRetryable(err) || attempt == 1 {
			break
		}
	}
	return planschema.Plan{}, fmt.Errorf("%w: %v", ErrUnavailable, last)
}

func (p *LLMPlanner) planOnce(ctx context.Context, intentText string) (planschema.Plan, error) {
	raw, err := p.complete(ctx, intentText)
	if err != nil {
		return planschema.Plan{}, err
	}
	plan, err := planschema.Parse([]byte(raw))
	if err != nil {
		return planschema.Plan{}, fmt.Errorf("llm plan json: %w", err)
	}
	// Schema + policy run in intentsvc after Plan returns — never execute raw model hex.
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
		return "", &httpStatusError{code: res.StatusCode, body: truncate(string(payload), 200)}
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

type httpStatusError struct {
	code int
	body string
}

func (e *httpStatusError) Error() string {
	return fmt.Sprintf("llm status %d: %s", e.code, e.body)
}

func isRetryable(err error) bool {
	if err == nil {
		return false
	}
	var status *httpStatusError
	if errors.As(err, &status) {
		return status.code == 429 || status.code >= 500
	}
	// Timeouts / transport errors are retryable; bad JSON from the model is not.
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return true
	}
	msg := err.Error()
	if strings.Contains(msg, "llm request:") || strings.Contains(msg, "llm read:") {
		return true
	}
	return false
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
