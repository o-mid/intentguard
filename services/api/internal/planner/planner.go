package planner

import (
	"context"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
)

type Planner interface {
	Plan(ctx context.Context, intentText string) (planschema.Plan, error)
}
