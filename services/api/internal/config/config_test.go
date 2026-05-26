package config

import "testing"

func TestLoad_defaultPort(t *testing.T) {
	t.Setenv("PORT", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 {
		t.Fatalf("port=%d want 8080", cfg.Port)
	}
}

func TestLoad_customPort(t *testing.T) {
	t.Setenv("PORT", "9090")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 9090 {
		t.Fatalf("port=%d want 9090", cfg.Port)
	}
	if cfg.Addr() != ":9090" {
		t.Fatalf("addr=%q", cfg.Addr())
	}
}

func TestLoad_badPort(t *testing.T) {
	t.Setenv("PORT", "nope")
	if _, err := Load(); err == nil {
		t.Fatal("expected error")
	}
}
