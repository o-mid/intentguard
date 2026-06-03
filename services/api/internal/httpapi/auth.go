package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/o-mid/intentguard/services/api/internal/auth"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

type userStore interface {
	Create(ctx context.Context, email, passwordHash string) (store.User, error)
	ByEmail(ctx context.Context, email string) (store.User, error)
	ByID(ctx context.Context, id string) (store.User, error)
}

type AuthHandlers struct {
	Users userStore
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type userResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

func (h AuthHandlers) Register(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	email := strings.TrimSpace(strings.ToLower(req.Email))
	if email == "" || len(req.Password) < 8 {
		writeError(w, http.StatusBadRequest, "invalid_credentials")
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "hash_failed")
		return
	}

	u, err := h.Users.Create(r.Context(), email, hash)
	if errors.Is(err, store.ErrEmailTaken) {
		writeError(w, http.StatusConflict, "email_taken")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "create_failed")
		return
	}

	writeJSON(w, http.StatusCreated, userResponse{ID: u.ID, Email: u.Email})
}

func (h AuthHandlers) Login(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	email := strings.TrimSpace(strings.ToLower(req.Email))
	if email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "invalid_credentials")
		return
	}

	u, err := h.Users.ByEmail(r.Context(), email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusUnauthorized, "invalid_credentials")
			return
		}
		writeError(w, http.StatusInternalServerError, "lookup_failed")
		return
	}
	if !auth.CheckPassword(u.PasswordHash, req.Password) {
		writeError(w, http.StatusUnauthorized, "invalid_credentials")
		return
	}

	writeJSON(w, http.StatusOK, userResponse{ID: u.ID, Email: u.Email})
}
