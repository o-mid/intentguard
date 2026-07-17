package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type TokenKind string

const (
	TokenAccess  TokenKind = "access"
	TokenRefresh TokenKind = "refresh"
)

type Claims struct {
	UserID string    `json:"uid"`
	Kind   TokenKind `json:"kind"`
	jwt.RegisteredClaims
}

type Tokens struct {
	AccessToken  string
	RefreshToken string
}

type TokenIssuer struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}

func NewTokenIssuer(secret string, accessTTL, refreshTTL time.Duration) (*TokenIssuer, error) {
	if secret == "" {
		return nil, errors.New("jwt secret is required")
	}
	return &TokenIssuer{
		secret:     []byte(secret),
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}, nil
}

func (t *TokenIssuer) Issue(userID string) (Tokens, error) {
	access, err := t.sign(userID, TokenAccess, t.accessTTL)
	if err != nil {
		return Tokens{}, err
	}
	refresh, err := t.sign(userID, TokenRefresh, t.refreshTTL)
	if err != nil {
		return Tokens{}, err
	}
	return Tokens{AccessToken: access, RefreshToken: refresh}, nil
}

func (t *TokenIssuer) ParseAccess(token string) (Claims, error) {
	claims, err := t.parse(token)
	if err != nil {
		return Claims{}, err
	}
	if claims.Kind != TokenAccess {
		return Claims{}, fmt.Errorf("expected access token")
	}
	return claims, nil
}

func (t *TokenIssuer) sign(userID string, kind TokenKind, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID,
		Kind:   kind,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(t.secret)
}

func (t *TokenIssuer) parse(token string) (Claims, error) {
	parsed, err := jwt.ParseWithClaims(token, &Claims{}, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return t.secret, nil
	})
	if err != nil {
		return Claims{}, err
	}
	claims, ok := parsed.Claims.(*Claims)
	if !ok || !parsed.Valid {
		return Claims{}, errors.New("invalid token")
	}
	return *claims, nil
}
