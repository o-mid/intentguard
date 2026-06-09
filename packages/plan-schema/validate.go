package planschema

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"

	"github.com/santhosh-tekuri/jsonschema/v5"
)

//go:embed plan.schema.json
var schemaBytes []byte

var compiled *jsonschema.Schema

func init() {
	c := jsonschema.NewCompiler()
	if err := c.AddResource("plan.schema.json", bytes.NewReader(schemaBytes)); err != nil {
		panic(err)
	}
	s, err := c.Compile("plan.schema.json")
	if err != nil {
		panic(err)
	}
	compiled = s
}

func ValidateJSON(raw []byte) error {
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return fmt.Errorf("invalid json: %w", err)
	}
	if err := compiled.Validate(v); err != nil {
		return fmt.Errorf("schema: %w", err)
	}
	return nil
}

func ValidatePlan(p Plan) error {
	raw, err := json.Marshal(p)
	if err != nil {
		return err
	}
	return ValidateJSON(raw)
}
