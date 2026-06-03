package config

import "testing"

func TestLoad_ok(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("DATABASE_URL", "postgres://intentguard:intentguard@localhost:5432/intentguard?sslmode=disable")
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
	if cfg.DatabaseURL == "" {
		t.Fatal("missing database url")
	}
}

func TestLoad_defaultPort(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("DATABASE_URL", "postgres://localhost/intentguard")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 {
		t.Fatalf("port=%d want 8080", cfg.Port)
	}
}

func TestLoad_badPort(t *testing.T) {
	t.Setenv("PORT", "nope")
	t.Setenv("DATABASE_URL", "postgres://localhost/intentguard")
	if _, err := Load(); err == nil {
		t.Fatal("expected error")
	}
}

func TestLoad_missingDatabaseURL(t *testing.T) {
	t.Setenv("PORT", "8080")
	t.Setenv("DATABASE_URL", "")
	if _, err := Load(); err == nil {
		t.Fatal("expected error")
	}
}
