package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Port           int
	DatabaseURL    string
	JWTSecret      string
	AccessTokenTTL time.Duration
	RefreshTokenTTL time.Duration
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

	return Config{
		Port:            port,
		DatabaseURL:     dbURL,
		JWTSecret:       secret,
		AccessTokenTTL:  accessTTL,
		RefreshTokenTTL: refreshTTL,
	}, nil
}

func (c Config) Addr() string {
	return fmt.Sprintf(":%d", c.Port)
}
