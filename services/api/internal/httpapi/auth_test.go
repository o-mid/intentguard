package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/o-mid/intentguard/services/api/internal/auth"
	"github.com/o-mid/intentguard/services/api/internal/store"
)

type memUsers struct {
	mu    sync.Mutex
	byID  map[string]store.User
	email map[string]string
	seq   int
}

func newMemUsers() *memUsers {
	return &memUsers{
		byID:  map[string]store.User{},
		email: map[string]string{},
	}
}

func (m *memUsers) Create(_ context.Context, email, passwordHash string) (store.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.email[email]; ok {
		return store.User{}, store.ErrEmailTaken
	}
	m.seq++
	id := "user-" + strconv.Itoa(m.seq)
	u := store.User{
		ID:           id,
		Email:        email,
		PasswordHash: passwordHash,
		CreatedAt:    time.Now().UTC(),
	}
	m.byID[id] = u
	m.email[email] = id
	return u, nil
}

func (m *memUsers) ByEmail(_ context.Context, email string) (store.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	id, ok := m.email[email]
	if !ok {
		return store.User{}, store.ErrNotFound
	}
	return m.byID[id], nil
}

func (m *memUsers) ByID(_ context.Context, id string) (store.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	u, ok := m.byID[id]
	if !ok {
		return store.User{}, store.ErrNotFound
	}
	return u, nil
}

func newTestMux(t *testing.T) (*http.ServeMux, *memUsers, *auth.TokenIssuer) {
	t.Helper()
	users := newMemUsers()
	tokens, err := auth.NewTokenIssuer("test-secret", time.Minute, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	h := AuthHandlers{Users: users, Tokens: tokens}
	return NewMux(h, IntentHandlers{}, StepHandlers{}, tokens, nil), users, tokens
}

func TestAuthHandlers(t *testing.T) {
	tests := []struct {
		name  string
		steps func(t *testing.T, mux *http.ServeMux)
	}{
		{
			name: "ok",
			steps: func(t *testing.T, mux *http.ServeMux) {
				reg := httptest.NewRequest(http.MethodPost, "/auth/register", bytes.NewBufferString(`{
					"email":"alice@wallet.test","password":"password123"
				}`))
				rr := httptest.NewRecorder()
				mux.ServeHTTP(rr, reg)
				if rr.Code != http.StatusCreated {
					t.Fatalf("register status=%d body=%s", rr.Code, rr.Body.String())
				}
				var regBody tokenResponse
				if err := json.NewDecoder(rr.Body).Decode(&regBody); err != nil {
					t.Fatal(err)
				}
				if regBody.AccessToken == "" || regBody.RefreshToken == "" {
					t.Fatal("missing tokens")
				}

				login := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewBufferString(`{
					"email":"alice@wallet.test","password":"password123"
				}`))
				rr = httptest.NewRecorder()
				mux.ServeHTTP(rr, login)
				if rr.Code != http.StatusOK {
					t.Fatalf("login status=%d body=%s", rr.Code, rr.Body.String())
				}
				var loginBody tokenResponse
				if err := json.NewDecoder(rr.Body).Decode(&loginBody); err != nil {
					t.Fatal(err)
				}

				me := httptest.NewRequest(http.MethodGet, "/auth/me", nil)
				me.Header.Set("Authorization", "Bearer "+loginBody.AccessToken)
				rr = httptest.NewRecorder()
				mux.ServeHTTP(rr, me)
				if rr.Code != http.StatusOK {
					t.Fatalf("me status=%d body=%s", rr.Code, rr.Body.String())
				}
				var meBody userResponse
				if err := json.NewDecoder(rr.Body).Decode(&meBody); err != nil {
					t.Fatal(err)
				}
				if meBody.Email != "alice@wallet.test" {
					t.Fatalf("email=%q", meBody.Email)
				}
			},
		},
		{
			name: "duplicate_email",
			steps: func(t *testing.T, mux *http.ServeMux) {
				body := `{"email":"bob@wallet.test","password":"password123"}`
				rr := httptest.NewRecorder()
				mux.ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/auth/register", bytes.NewBufferString(body)))
				if rr.Code != http.StatusCreated {
					t.Fatalf("first register status=%d", rr.Code)
				}
				rr = httptest.NewRecorder()
				mux.ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/auth/register", bytes.NewBufferString(body)))
				if rr.Code != http.StatusConflict {
					t.Fatalf("dup status=%d body=%s", rr.Code, rr.Body.String())
				}
			},
		},
		{
			name: "bad_login",
			steps: func(t *testing.T, mux *http.ServeMux) {
				rr := httptest.NewRecorder()
				mux.ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/auth/register", bytes.NewBufferString(
					`{"email":"cara@wallet.test","password":"password123"}`,
				)))
				if rr.Code != http.StatusCreated {
					t.Fatalf("register status=%d", rr.Code)
				}
				rr = httptest.NewRecorder()
				mux.ServeHTTP(rr, httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewBufferString(
					`{"email":"cara@wallet.test","password":"wrong-password"}`,
				)))
				if rr.Code != http.StatusUnauthorized {
					t.Fatalf("login status=%d", rr.Code)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mux, _, _ := newTestMux(t)
			tt.steps(t, mux)
		})
	}
}
