package auth

import "testing"

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("correct-horse")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(hash, "correct-horse") {
		t.Fatal("expected match")
	}
	if CheckPassword(hash, "wrong-pass") {
		t.Fatal("expected mismatch")
	}
}
