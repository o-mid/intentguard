package planschema

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExamplesValidate(t *testing.T) {
	entries, err := os.ReadDir("examples")
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		raw, err := os.ReadFile(filepath.Join("examples", e.Name()))
		if err != nil {
			t.Fatal(err)
		}
		if err := ValidateJSON(raw); err != nil {
			t.Fatalf("%s: %v", e.Name(), err)
		}
	}
}

func TestValidateJSON_rejectsUnknownAction(t *testing.T) {
	raw := []byte(`{
		"schemaVersion":"1",
		"summary":"bridge",
		"steps":[{"action":"bridge","token":"MOCK_USDC","amount":"1","to":"self"}]
	}`)
	if err := ValidateJSON(raw); err == nil {
		t.Fatal("expected schema rejection")
	}
}
