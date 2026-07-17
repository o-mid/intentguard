package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	planschema "github.com/o-mid/intentguard/packages/plan-schema"
	"github.com/o-mid/intentguard/services/api/internal/planner"
	"github.com/o-mid/intentguard/services/api/internal/policy"
	"gopkg.in/yaml.v3"
)

type evalCase struct {
	ID     string   `yaml:"id"`
	Intent string   `yaml:"intent"`
	Expect string   `yaml:"expect"`
	Codes  []string `yaml:"codes"`
}

func main() {
	dir := flag.String("dir", "", "path to evals/cases")
	flag.Parse()
	if *dir == "" {
		fmt.Fprintln(os.Stderr, "usage: evals -dir path/to/evals/cases")
		os.Exit(2)
	}

	cases, err := loadCases(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "load: %v\n", err)
		os.Exit(1)
	}
	if len(cases) < 10 {
		fmt.Fprintf(os.Stderr, "need ≥10 cases, got %d\n", len(cases))
		os.Exit(1)
	}

	p := planner.NewMock()
	cfg := policy.DefaultConfig()
	failed := 0
	for _, c := range cases {
		got, codes, err := runCase(p, cfg, c.Intent)
		if err != nil {
			fmt.Printf("FAIL %s: %v\n", c.ID, err)
			failed++
			continue
		}
		if got != c.Expect {
			fmt.Printf("FAIL %s: expect=%s got=%s codes=%v\n", c.ID, c.Expect, got, codes)
			failed++
			continue
		}
		if len(c.Codes) > 0 && !containsAll(codes, c.Codes) {
			fmt.Printf("FAIL %s: missing codes want=%v got=%v\n", c.ID, c.Codes, codes)
			failed++
			continue
		}
		fmt.Printf("ok   %s\n", c.ID)
	}
	if failed > 0 {
		fmt.Fprintf(os.Stderr, "%d/%d failed\n", failed, len(cases))
		os.Exit(1)
	}
	fmt.Printf("%d cases passed\n", len(cases))
}

func runCase(p planner.Planner, cfg policy.Config, intent string) (string, []string, error) {
	plan, err := p.Plan(context.Background(), intent)
	if err != nil {
		return "planner_error", nil, nil
	}
	raw, err := json.Marshal(plan)
	if err != nil {
		return "", nil, err
	}
	if err := planschema.ValidateJSON(raw); err != nil {
		return "reject_schema", nil, nil
	}
	vs := policy.Check(plan, cfg)
	if len(vs) > 0 {
		codes := make([]string, 0, len(vs))
		seen := map[string]struct{}{}
		for _, v := range vs {
			code := string(v.Code)
			if _, ok := seen[code]; ok {
				continue
			}
			seen[code] = struct{}{}
			codes = append(codes, code)
		}
		sort.Strings(codes)
		return "reject_policy", codes, nil
	}
	return "accept", nil, nil
}

func loadCases(dir string) ([]evalCase, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []evalCase
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".yaml") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return nil, err
		}
		var c evalCase
		if err := yaml.Unmarshal(raw, &c); err != nil {
			return nil, fmt.Errorf("%s: %w", e.Name(), err)
		}
		if c.ID == "" || c.Intent == "" || c.Expect == "" {
			return nil, fmt.Errorf("%s: id, intent, expect required", e.Name())
		}
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func containsAll(have, want []string) bool {
	set := map[string]struct{}{}
	for _, h := range have {
		set[h] = struct{}{}
	}
	for _, w := range want {
		if _, ok := set[w]; !ok {
			return false
		}
	}
	return true
}
