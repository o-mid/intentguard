package planner

import "errors"

// ErrUnavailable means the planner timed out, failed after retry, or returned unusable output.
var ErrUnavailable = errors.New("planner_unavailable")
