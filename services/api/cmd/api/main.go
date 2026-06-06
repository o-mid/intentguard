package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/o-mid/intentguard/services/api/internal/auth"
	"github.com/o-mid/intentguard/services/api/internal/config"
	"github.com/o-mid/intentguard/services/api/internal/db"
	"github.com/o-mid/intentguard/services/api/internal/httpapi"
	"github.com/o-mid/intentguard/services/api/internal/logging"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

func main() {
	log := logging.New()

	cfg, err := config.Load()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}

	migrationsPath := os.Getenv("MIGRATIONS_PATH")
	if migrationsPath == "" {
		migrationsPath = filepath.Join("migrations")
	}
	if err := db.Migrate(cfg.DatabaseURL, migrationsPath); err != nil {
		log.Error("migrate", "err", err)
		os.Exit(1)
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Error("db", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	tokens, err := auth.NewTokenIssuer(cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	if err != nil {
		log.Error("jwt", "err", err)
		os.Exit(1)
	}

	authHandlers := httpapi.AuthHandlers{
		Users:  store.NewUsers(pool),
		Tokens: tokens,
	}

	srv := &http.Server{
		Addr:              cfg.Addr(),
		Handler:           httpapi.NewMux(authHandlers, tokens),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Info("api listening", "addr", cfg.Addr())
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown", "err", err)
		os.Exit(1)
	}
}
