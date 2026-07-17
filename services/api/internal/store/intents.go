package store

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Intent struct {
	ID        string
	UserID    string
	Text      string
	Status    string
	CreatedAt time.Time
}

type Intents struct {
	pool *pgxpool.Pool
}

func NewIntents(pool *pgxpool.Pool) *Intents {
	return &Intents{pool: pool}
}

func (s *Intents) Create(ctx context.Context, userID, text, status string) (Intent, error) {
	const q = `
		INSERT INTO intents (user_id, text, status)
		VALUES ($1, $2, $3)
		RETURNING id::text, user_id::text, text, status, created_at
	`
	var in Intent
	err := s.pool.QueryRow(ctx, q, userID, text, status).
		Scan(&in.ID, &in.UserID, &in.Text, &in.Status, &in.CreatedAt)
	return in, err
}

func (s *Intents) UpdateStatus(ctx context.Context, id, status string) error {
	const q = `UPDATE intents SET status = $2 WHERE id = $1`
	_, err := s.pool.Exec(ctx, q, id, status)
	return err
}

// IntentPlanRef pairs an intent with its latest plan id.
type IntentPlanRef struct {
	Intent Intent
	PlanID string
}

func (s *Intents) ListByUser(ctx context.Context, userID string) ([]IntentPlanRef, error) {
	const q = `
		SELECT i.id::text, i.user_id::text, i.text, i.status, i.created_at,
		       p.id::text
		FROM intents i
		JOIN LATERAL (
			SELECT id FROM plans WHERE intent_id = i.id ORDER BY created_at DESC LIMIT 1
		) p ON true
		WHERE i.user_id = $1
		ORDER BY i.created_at DESC
		LIMIT 50
	`
	rows, err := s.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []IntentPlanRef
	for rows.Next() {
		var ref IntentPlanRef
		if err := rows.Scan(
			&ref.Intent.ID, &ref.Intent.UserID, &ref.Intent.Text, &ref.Intent.Status,
			&ref.Intent.CreatedAt, &ref.PlanID,
		); err != nil {
			return nil, err
		}
		out = append(out, ref)
	}
	return out, rows.Err()
}
