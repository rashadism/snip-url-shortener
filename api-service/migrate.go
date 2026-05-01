package main

import (
	"context"
	_ "embed"
	"fmt"
	"log/slog"
	"time"
)

//go:embed schema.sql
var schemaSQL string

func (s *Store) Migrate(ctx context.Context) error {
	deadline := time.Now().Add(30 * time.Second)
	for {
		execCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		_, err := s.db.ExecContext(execCtx, schemaSQL)
		cancel()
		if err == nil {
			slog.Info("schema migration applied")
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("migrate: %w", err)
		}
		slog.Warn("migration failed, retrying", "error", err)
		time.Sleep(2 * time.Second)
	}
}
