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
	"github.com/o-mid/intentguard/services/api/internal/executor"
	"github.com/o-mid/intentguard/services/api/internal/httpapi"
	"github.com/o-mid/intentguard/services/api/internal/intentsvc"
	"github.com/o-mid/intentguard/services/api/internal/logging"
	"github.com/o-mid/intentguard/services/api/internal/planner"
	"github.com/o-mid/intentguard/services/api/internal/policy"
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

	deployments, err := executor.LoadDeployments(cfg.DeploymentsPath)
	if err != nil {
		log.Error("deployments", "err", err)
		os.Exit(1)
	}

	chain, err := executor.Dial(ctx, cfg.ChainRPCURL, cfg.ExecutorPrivateKey)
	if err != nil {
		log.Error("chain", "err", err)
		os.Exit(1)
	}
	defer chain.Close()

	plans := store.NewPlans(pool)
	runner := executor.Runner{
		Plans:       plans,
		Chain:       chain,
		Deployments: deployments,
	}

	authHandlers := httpapi.AuthHandlers{
		Users:  store.NewUsers(pool),
		Tokens: tokens,
	}
	p, err := planner.NewFromMode(cfg.PlannerMode, planner.LLMOptions{
		BaseURL: cfg.LLMBaseURL,
		APIKey:  cfg.LLMAPIKey,
		Model:   cfg.LLMModel,
	})
	if err != nil {
		log.Error("planner", "err", err)
		os.Exit(1)
	}
	log.Info("planner", "mode", cfg.PlannerMode)

	svc := intentsvc.Service{
		Intents: store.NewIntents(pool),
		Plans:   plans,
		Planner: p,
		Policy:  policy.DefaultConfig(),
	}
	intentHandlers := httpapi.IntentHandlers{Service: svc}
	stepHandlers := httpapi.StepHandlers{Executor: runner}
	health := httpapi.HealthHandler{RPC: chain}.ServeHTTP

	srv := &http.Server{
		Addr:              cfg.Addr(),
		Handler:           httpapi.NewMux(authHandlers, intentHandlers, stepHandlers, tokens, health),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Info("api listening", "addr", cfg.Addr(), "from", chain.From().Hex())
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
