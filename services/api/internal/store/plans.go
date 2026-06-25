package store

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Plan struct {
	ID                string
	IntentID          string
	SchemaVersion     string
	Status            string
	Summary           string
	RawModelJSON      json.RawMessage
	RejectionReasons  json.RawMessage
	CreatedAt         time.Time
	Steps             []PlanStep
	UserID            string
}

type PlanStep struct {
	ID              string
	PlanID          string
	Index           int
	Action          string
	PayloadJSON     json.RawMessage
	DecodedSummary  string
	Status          string
	TxHash          *string
	Error           *string
}

type Plans struct {
	pool *pgxpool.Pool
}

func NewPlans(pool *pgxpool.Pool) *Plans {
	return &Plans{pool: pool}
}

func (s *Plans) Create(ctx context.Context, p Plan, steps []PlanStep) (Plan, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Plan{}, err
	}
	defer tx.Rollback(ctx)

	const q = `
		INSERT INTO plans (intent_id, schema_version, status, summary, raw_model_json, rejection_reasons)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id::text, intent_id::text, schema_version, status, summary, raw_model_json, rejection_reasons, created_at
	`
	var out Plan
	err = tx.QueryRow(ctx, q,
		p.IntentID, p.SchemaVersion, p.Status, p.Summary, p.RawModelJSON, p.RejectionReasons,
	).Scan(&out.ID, &out.IntentID, &out.SchemaVersion, &out.Status, &out.Summary, &out.RawModelJSON, &out.RejectionReasons, &out.CreatedAt)
	if err != nil {
		return Plan{}, err
	}

	const sq = `
		INSERT INTO plan_steps (plan_id, step_index, action, payload_json, decoded_summary, status)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id::text, plan_id::text, step_index, action, payload_json, decoded_summary, status, tx_hash, error
	`
	for _, st := range steps {
		var saved PlanStep
		err = tx.QueryRow(ctx, sq, out.ID, st.Index, st.Action, st.PayloadJSON, st.DecodedSummary, st.Status).
			Scan(&saved.ID, &saved.PlanID, &saved.Index, &saved.Action, &saved.PayloadJSON, &saved.DecodedSummary, &saved.Status, &saved.TxHash, &saved.Error)
		if err != nil {
			return Plan{}, err
		}
		out.Steps = append(out.Steps, saved)
	}

	if err := tx.Commit(ctx); err != nil {
		return Plan{}, err
	}
	return out, nil
}

func (s *Plans) ByIDForUser(ctx context.Context, planID, userID string) (Plan, error) {
	const q = `
		SELECT p.id::text, p.intent_id::text, p.schema_version, p.status, p.summary,
		       p.raw_model_json, p.rejection_reasons, p.created_at, i.user_id::text
		FROM plans p
		JOIN intents i ON i.id = p.intent_id
		WHERE p.id = $1 AND i.user_id = $2
	`
	var out Plan
	err := s.pool.QueryRow(ctx, q, planID, userID).Scan(
		&out.ID, &out.IntentID, &out.SchemaVersion, &out.Status, &out.Summary,
		&out.RawModelJSON, &out.RejectionReasons, &out.CreatedAt, &out.UserID,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Plan{}, ErrNotFound
	}
	if err != nil {
		return Plan{}, err
	}

	const sq = `
		SELECT id::text, plan_id::text, step_index, action, payload_json, decoded_summary, status, tx_hash, error
		FROM plan_steps
		WHERE plan_id = $1
		ORDER BY step_index
	`
	rows, err := s.pool.Query(ctx, sq, out.ID)
	if err != nil {
		return Plan{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var st PlanStep
		if err := rows.Scan(&st.ID, &st.PlanID, &st.Index, &st.Action, &st.PayloadJSON, &st.DecodedSummary, &st.Status, &st.TxHash, &st.Error); err != nil {
			return Plan{}, err
		}
		out.Steps = append(out.Steps, st)
	}
	return out, rows.Err()
}

func (s *Plans) UpdateStepStatus(ctx context.Context, planID string, index int, status string) error {
	const q = `
		UPDATE plan_steps
		SET status = $3
		WHERE plan_id = $1 AND step_index = $2
	`
	tag, err := s.pool.Exec(ctx, q, planID, index, status)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	_, _ = s.pool.Exec(ctx, `UPDATE plans SET status = 'executing' WHERE id = $1 AND status = 'awaiting_approval'`, planID)
	return nil
}

func (s *Plans) FinishStep(ctx context.Context, planID string, index int, status string, txHash, errMsg *string) (PlanStep, error) {
	const q = `
		UPDATE plan_steps
		SET status = $3, tx_hash = $4, error = $5
		WHERE plan_id = $1 AND step_index = $2
		RETURNING id::text, plan_id::text, step_index, action, payload_json, decoded_summary, status, tx_hash, error
	`
	var st PlanStep
	err := s.pool.QueryRow(ctx, q, planID, index, status, txHash, errMsg).
		Scan(&st.ID, &st.PlanID, &st.Index, &st.Action, &st.PayloadJSON, &st.DecodedSummary, &st.Status, &st.TxHash, &st.Error)
	if errors.Is(err, pgx.ErrNoRows) {
		return PlanStep{}, ErrNotFound
	}
	if err != nil {
		return PlanStep{}, err
	}

	// If all steps succeeded, mark plan completed.
	const doneQ = `
		UPDATE plans SET status = 'completed'
		WHERE id = $1
		  AND NOT EXISTS (
		    SELECT 1 FROM plan_steps WHERE plan_id = $1 AND status <> 'succeeded'
		  )
	`
	_, _ = s.pool.Exec(ctx, doneQ, planID)
	return st, nil
}
