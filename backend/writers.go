package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

func newID(prefix string) string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	return prefix + "-" + hex.EncodeToString(b)
}

// ---- Write path: the decision loop can finally close -----------------------

type raiseReq struct {
	Title       string `json:"title"`
	Body        string `json:"body"`
	ScopeLabel  string `json:"scope_label"`
	CustomerID  string `json:"customer_id"`
	Severity    string `json:"severity"`
	Tone        string `json:"tone"`
	Owner       string `json:"owner"`
	ActionLabel string `json:"action_label"`
	ActionView  string `json:"action_view"`
	DueAt       string `json:"due_at"` // YYYY-MM-DD, optional
}

// POST /api/journal — raise a new risk (origin='manual'). Appends the opening
// movement so the audit spine is populated from the first event.
func (s *server) raiseRisk(w http.ResponseWriter, r *http.Request) {
	var req raiseReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
		return
	}
	if req.Title == "" || req.CustomerID == "" || req.Owner == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "title, customer_id and owner are required"})
		return
	}
	id := newID("jr")
	ref := "RSK-" + id[len(id)-4:]
	now := time.Now().UTC()
	sev, tone := req.Severity, req.Tone
	if sev == "" {
		sev = "P2"
	}
	if tone == "" {
		tone = "warn"
	}

	var dueAt any
	if req.DueAt != "" {
		dueAt = req.DueAt
	}

	if err := s.exec(`
		INSERT INTO audit.journal_entry
		(id, risk_ref, severity, tone, title, body, scope_label, cluster_id,
		 movement_from, movement_to, state, owner, due_note, due_at, exposure_pennies,
		 action_label, action_view, origin, created_at, author)
		VALUES (?,?,?,?,?,?,?,NULL,'New','Open',?,?,NULL,?,NULL,?,?, 'manual', ?, ?)`,
		id, ref, sev, tone, req.Title, req.Body, req.ScopeLabel,
		"open", req.Owner, dueAt, nullify(req.ActionLabel), nullify(req.ActionView),
		now, req.Owner); err != nil {
		s.fail(w, err)
		return
	}
	if err := s.exec(`INSERT INTO audit.journal_entry_customer VALUES (?, ?)`, id, req.CustomerID); err != nil {
		s.fail(w, err)
		return
	}
	if err := s.exec(`INSERT INTO audit.journal_movement VALUES (?,?,?,?,?,?,?,?)`,
		newID("jm"), id, 1, "New", "Open", "Raised in Meridian", req.Owner, now); err != nil {
		s.fail(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id, "risk_ref": ref})
}

type moveReq struct {
	JournalID string `json:"journal_id"`
	ToState   string `json:"to_state"`
	Note      string `json:"note"`
	Actor     string `json:"actor"`
}

// POST /api/journal/move — append a state movement (append-only; the head row's
// denormalised state is updated to match, but the movement log is never mutated).
func (s *server) moveRisk(w http.ResponseWriter, r *http.Request) {
	var req moveReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
		return
	}
	if req.JournalID == "" || req.ToState == "" || req.Actor == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "journal_id, to_state and actor are required"})
		return
	}
	cur, err := s.queryRows(`SELECT movement_to, state FROM audit.journal_entry WHERE id = ?`, req.JournalID)
	if err != nil {
		s.fail(w, err)
		return
	}
	if len(cur) == 0 {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "unknown journal id"})
		return
	}
	fromLabel, _ := cur[0]["movement_to"].(string)
	now := time.Now().UTC()
	seqRows, err := s.queryRows(`SELECT COALESCE(MAX(seq),0)+1 AS seq FROM audit.journal_movement WHERE journal_id = ?`, req.JournalID)
	if err != nil {
		s.fail(w, err)
		return
	}
	seq := seqRows[0]["seq"]
	newState := "open"
	if req.ToState == "Closed" {
		newState = "closed"
	} else if req.ToState == "Escalated" {
		newState = "escalated"
	}
	if err := s.exec(`INSERT INTO audit.journal_movement VALUES (?,?,?,?,?,?,?,?)`,
		newID("jm"), req.JournalID, seq, fromLabel, req.ToState, req.Note, req.Actor, now); err != nil {
		s.fail(w, err)
		return
	}
	if err := s.exec(`UPDATE audit.journal_entry SET movement_from = ?, movement_to = ?, state = ? WHERE id = ?`,
		fromLabel, req.ToState, newState, req.JournalID); err != nil {
		s.fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type decisionReq struct {
	JournalID string `json:"journal_id"`
	Option    string `json:"option"`
	Rationale string `json:"rationale"`
	DecidedBy string `json:"decided_by"`
	VerifyBy  string `json:"verify_by"` // YYYY-MM-DD, optional
}

// POST /api/decisions — record a decision on a risk (raised→DECIDED). Does NOT
// close the risk: execution continues; the decision is its own auditable record.
func (s *server) decide(w http.ResponseWriter, r *http.Request) {
	var req decisionReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
		return
	}
	if req.JournalID == "" || req.Option == "" || req.DecidedBy == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "journal_id, option and decided_by are required"})
		return
	}
	now := time.Now().UTC()
	var verifyBy any
	if req.VerifyBy != "" {
		verifyBy = req.VerifyBy
	}
	if err := s.exec(`INSERT INTO audit.decision VALUES (?,?,?,?,?,?,?,?)`,
		newID("dec"), req.JournalID, req.Option, req.Rationale, req.DecidedBy, now, verifyBy, "decided"); err != nil {
		s.fail(w, err)
		return
	}
	seqRows, _ := s.queryRows(`SELECT COALESCE(MAX(seq),0)+1 AS seq FROM audit.journal_movement WHERE journal_id = ?`, req.JournalID)
	if len(seqRows) > 0 {
		_ = s.exec(`INSERT INTO audit.journal_movement VALUES (?,?,?,?,?,?,?,?)`,
			newID("jm"), req.JournalID, seqRows[0]["seq"], NULL, "Decided", "Decision: "+req.Option, req.DecidedBy, now)
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

// NULL sentinel for the movement from_state on a decision (no state change).
var NULL any = nil

func nullify(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// ---- Startup jobs: a real control + a snapshot writer ----------------------

// writeSnapshotIfStale keeps the RAG baseline fresh. A real deployment would run
// this weekly; here we upsert today's snapshot on boot if the newest is missing
// or older than 7 days, so the RAG board never diffs against a dead baseline.
func (s *server) writeSnapshotIfStale() error {
	rows, err := s.queryRows(`SELECT COALESCE(MAX(snapshot_date), DATE '1900-01-01') AS latest FROM audit.signal_snapshot`)
	if err != nil {
		return err
	}
	ageRows, err := s.queryRows(`SELECT DATE_DIFF('day', COALESCE(MAX(snapshot_date), DATE '1900-01-01'), CURRENT_DATE) AS age,
	                                    CAST(COUNT(*) FILTER (WHERE snapshot_date = CURRENT_DATE) AS BIGINT) AS today
	                             FROM audit.signal_snapshot`)
	if err != nil {
		return err
	}
	_ = rows
	age, _ := toInt(ageRows[0]["age"])
	today, _ := toInt(ageRows[0]["today"])
	if today > 0 || age < 7 {
		return nil // fresh enough
	}
	return s.exec(`
		INSERT INTO audit.signal_snapshot
		SELECT CURRENT_DATE, customer_id, health_band, outcomes_on_track, outcomes_total,
		       clause_breaches, clauses_at_risk, utilisation_pct, velocity_delta_pct, open_risks
		FROM semantic.v_customer_signal`)
}

// evaluateMilestoneGates is a REAL control (the plan's Phase-0 exit): it reads
// core.evidence and writes clause_evaluation rows with method='evaluated', so at
// least one control is genuinely live rather than seeded. Runs on boot.
func (s *server) evaluateMilestoneGates() error {
	// Idempotent across restarts: clear prior live verdicts before re-evaluating.
	if err := s.exec(`DELETE FROM audit.clause_evaluation WHERE method = 'evaluated'`); err != nil {
		return err
	}
	clauses, err := s.queryRows(`
		SELECT id, engagement_id, ref, remedy_amount_pennies
		FROM core.clause WHERE category = 'milestone_gate' AND tier = 'auto'`)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	for _, c := range clauses {
		cid := c["id"]
		ev, err := s.queryRows(`
			SELECT requirement, state FROM core.evidence
			WHERE clause_id = ?`, cid)
		if err != nil {
			return err
		}
		verdict, note := "met", "all required evidence verified"
		missing := 0
		for _, e := range ev {
			st, _ := e["state"].(string)
			if st != "verified" {
				missing++
			}
		}
		if len(ev) == 0 {
			verdict, note = "cannot_evaluate", "no evidence records to check"
		} else if missing > 0 {
			verdict = "breach"
			note = fmt.Sprintf("%d of %d required artifacts not verified", missing, len(ev))
		}
		var money any
		if verdict == "breach" && c["remedy_amount_pennies"] != nil {
			amt, _ := toInt(c["remedy_amount_pennies"])
			money = fmt.Sprintf("£%dk held", amt/100000)
		}
		if err := s.exec(`INSERT INTO audit.clause_evaluation VALUES (?,?,?,?,?,?,?, 'evaluated', ?)`,
			newID("ev"), cid, 1, now, verdict, note, money, `{"evaluator":"milestone_gate"}`); err != nil {
			return err
		}
	}
	return nil
}

func toInt(v any) (int64, bool) {
	switch t := v.(type) {
	case int64:
		return t, true
	case int32:
		return int64(t), true
	case float64:
		return int64(t), true
	default:
		return 0, false
	}
}
