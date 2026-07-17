package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Port              int
	DatabaseURL       string
	JWTSecret         string
	AccessTokenTTL    time.Duration
	RefreshTokenTTL   time.Duration
	ChainRPCURL       string
	ExecutorPrivateKey string
	DeploymentsPath   string
}

func Load() (Config, error) {
	port := 8080
	if raw := os.Getenv("PORT"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil {
			return Config{}, fmt.Errorf("PORT: %w", err)
		}
		port = n
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		return Config{}, fmt.Errorf("JWT_SECRET is required")
	}

	accessTTL := 15 * time.Minute
	if raw := os.Getenv("JWT_ACCESS_TTL"); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil {
			return Config{}, fmt.Errorf("JWT_ACCESS_TTL: %w", err)
		}
		accessTTL = d
	}

	refreshTTL := 168 * time.Hour
	if raw := os.Getenv("JWT_REFRESH_TTL"); raw != "" {
		d, err := time.ParseDuration(raw)
		if err != nil {
			return Config{}, fmt.Errorf("JWT_REFRESH_TTL: %w", err)
		}
		refreshTTL = d
	}

	rpc := os.Getenv("CHAIN_RPC_URL")
	if rpc == "" {
		rpc = "http://127.0.0.1:8545"
	}
	pk := os.Getenv("EXECUTOR_PRIVATE_KEY")
	if pk == "" {
		// Anvil account #0 — local demo only.
		pk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
	}
	deployments := os.Getenv("DEPLOYMENTS_PATH")
	if deployments == "" {
		deployments = "../../contracts/deployments/anvil.json"
	}

	return Config{
		Port:               port,
		DatabaseURL:        dbURL,
		JWTSecret:          secret,
		AccessTokenTTL:     accessTTL,
		RefreshTokenTTL:    refreshTTL,
		ChainRPCURL:        rpc,
		ExecutorPrivateKey: pk,
		DeploymentsPath:    deployments,
	}, nil
}

func (c Config) Addr() string {
	return fmt.Sprintf(":%d", c.Port)
}
