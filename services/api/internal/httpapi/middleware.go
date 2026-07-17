package httpapi

import (
	"context"
	"net/http"
	"strings"

	"github.com/o-mid/intentguard/services/api/internal/auth"
)

type contextKey string

const userIDKey contextKey = "user_id"

type accessParser interface {
	ParseAccess(token string) (auth.Claims, error)
}

func RequireAuth(tokens accessParser, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		raw := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		claims, err := tokens.ParseAccess(raw)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		ctx := context.WithValue(r.Context(), userIDKey, claims.UserID)
		next(w, r.WithContext(ctx))
	}
}

func UserIDFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok && id != ""
}
