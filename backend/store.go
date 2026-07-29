package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"math/big"
	"net/http"
	"time"
)

type server struct {
	db *sql.DB
}

// queryRows runs a query and returns rows as []map[string]any keyed by the
// SQL column names — the API's JSON shape is defined by the SQL itself.
func (s *server) queryRows(query string, args ...any) ([]map[string]any, error) {
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	out := make([]map[string]any, 0, 16)
	for rows.Next() {
		vals := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}
		m := make(map[string]any, len(cols))
		for i, c := range cols {
			m[c] = normalize(vals[i])
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// normalize converts DuckDB driver types into JSON-friendly values.
func normalize(v any) any {
	switch t := v.(type) {
	case *big.Int: // DuckDB HUGEINT (e.g. SUM over integers)
		return t.Int64()
	case time.Time:
		return t.UTC().Format(time.RFC3339)
	case []byte:
		return string(t)
	default:
		return v
	}
}

// exec runs a statement that returns no rows (INSERT/UPDATE).
func (s *server) exec(query string, args ...any) error {
	_, err := s.db.Exec(query, args...)
	return err
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("encode: %v", err)
	}
}

func (s *server) fail(w http.ResponseWriter, err error) {
	log.Printf("query error: %v", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
}
