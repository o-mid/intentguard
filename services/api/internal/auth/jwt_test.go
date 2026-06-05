package auth

import (
	"testing"
	"time"
)

func TestIssueAndParseAccess(t *testing.T) {
	issuer, err := NewTokenIssuer("test-secret", time.Minute, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	toks, err := issuer.Issue("user-1")
	if err != nil {
		t.Fatal(err)
	}
	claims, err := issuer.ParseAccess(toks.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if claims.UserID != "user-1" || claims.Kind != TokenAccess {
		t.Fatalf("claims=%+v", claims)
	}
	if _, err := issuer.ParseAccess(toks.RefreshToken); err == nil {
		t.Fatal("refresh must not parse as access")
	}
}
