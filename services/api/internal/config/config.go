package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Port int
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
	return Config{Port: port}, nil
}

func (c Config) Addr() string {
	return fmt.Sprintf(":%d", c.Port)
}
