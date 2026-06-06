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

type tokenIssuer interface {
	Issue(userID string) (auth.Tokens, error)
}

type AuthHandlers struct {
	Users  userStore
	Tokens tokenIssuer
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type userResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type tokenResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	User         userResponse `json:"user"`
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

	h.writeTokens(w, http.StatusCreated, u)
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

	h.writeTokens(w, http.StatusOK, u)
}

func (h AuthHandlers) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	u, err := h.Users.ByID(r.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "lookup_failed")
		return
	}
	writeJSON(w, http.StatusOK, userResponse{ID: u.ID, Email: u.Email})
}

func (h AuthHandlers) writeTokens(w http.ResponseWriter, status int, u store.User) {
	toks, err := h.Tokens.Issue(u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_failed")
		return
	}
	writeJSON(w, status, tokenResponse{
		AccessToken:  toks.AccessToken,
		RefreshToken: toks.RefreshToken,
		User:         userResponse{ID: u.ID, Email: u.Email},
	})
}
