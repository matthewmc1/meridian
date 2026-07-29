package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"

	_ "github.com/marcboeker/go-duckdb/v2"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// bootstrap applies db/schema.sql on first run and loads db/seed.sql only when
// core.customer is empty. All data lives in the lake; the app ships none.
func bootstrap(db *sql.DB) error {
	var n int
	err := db.QueryRow(`SELECT count(*) FROM information_schema.tables
		WHERE table_schema = 'core' AND table_name = 'customer'`).Scan(&n)
	if err != nil {
		return err
	}
	if n == 0 {
		if err := execFile(db, env("MERIDIAN_SCHEMA", "db/schema.sql")); err != nil {
			return err
		}
	}
	if env("MERIDIAN_SEED", "1") == "1" {
		if err := db.QueryRow(`SELECT count(*) FROM core.customer`).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			if err := execFile(db, env("MERIDIAN_SEED_FILE", "db/seed.sql")); err != nil {
				return err
			}
			log.Println("loaded dev fixtures from db/seed.sql (set MERIDIAN_SEED=0 to disable)")
		}
	}
	return nil
}

func execFile(db *sql.DB, path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	_, err = db.Exec(string(raw))
	return err
}

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", env("MERIDIAN_CORS_ORIGIN", "*"))
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func main() {
	db, err := sql.Open("duckdb", env("MERIDIAN_DB", "meridian.duckdb"))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := bootstrap(db); err != nil {
		log.Fatalf("bootstrap: %v", err)
	}

	s := &server{db: db}

	// Startup jobs: run one REAL control (milestone-gate evaluator writes
	// method='evaluated' verdicts) and keep the RAG snapshot baseline fresh.
	if err := s.evaluateMilestoneGates(); err != nil {
		log.Printf("gate evaluator: %v", err)
	}
	if err := s.writeSnapshotIfStale(); err != nil {
		log.Printf("snapshot writer: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/definitions", s.definitions)
	mux.HandleFunc("GET /api/signal", s.signal)
	mux.HandleFunc("GET /api/customers/{id}", s.customer360)
	mux.HandleFunc("GET /api/customers/{id}/delivery", s.delivery)
	mux.HandleFunc("GET /api/journal", s.journal)
	mux.HandleFunc("GET /api/correlation", s.correlation)
	mux.HandleFunc("GET /api/rag", s.rag)
	mux.HandleFunc("GET /api/qbr/{id}", s.qbr)
	// Write path — the decision loop closes here.
	mux.HandleFunc("POST /api/journal", s.raiseRisk)
	mux.HandleFunc("POST /api/journal/move", s.moveRisk)
	mux.HandleFunc("POST /api/decisions", s.decide)

	addr := env("MERIDIAN_ADDR", ":8787")
	log.Printf("meridian api on %s (db=%s)", addr, env("MERIDIAN_DB", "meridian.duckdb"))
	log.Fatal(http.ListenAndServe(addr, cors(mux)))
}
