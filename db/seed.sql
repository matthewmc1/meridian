-- ============================================================================
-- DEV FIXTURES ONLY.
-- This file exists to exercise the schema and the UI while connectors are
-- built. It is the ONLY place fixture data lives — the frontend and backend
-- contain no data. Replace by truncating core.*/audit.* and pointing the
-- connectors at real sources; nothing else changes.
-- ============================================================================

-- Source freshness (drives the sidebar dots) --------------------------------
INSERT INTO staging.sync_status VALUES
  ('salesforce', TIMESTAMP '2026-07-28 09:08:00', NULL, 360),
  ('workday',    TIMESTAMP '2026-07-28 07:14:00', NULL, 7200),
  ('jira',       TIMESTAMP '2026-07-28 09:00:00', NULL, 840),
  ('jsm',        TIMESTAMP '2026-07-28 09:06:00', NULL, 480),
  ('confluence', TIMESTAMP '2026-07-28 08:20:00', NULL, 3240),
  ('gdrive',     TIMESTAMP '2026-07-28 08:45:00', NULL, 1740);

-- Customers & engagements -----------------------------------------------------
INSERT INTO core.customer VALUES
  ('cust-nr', 'Northwind Rail',    'NR', 'Transport & infrastructure', 'Priya Raman'),
  ('cust-hh', 'Halcyon Health',    'HH', 'Public health',              'Priya Raman'),
  ('cust-cb', 'Castellan Bank',    'CB', 'Financial services',         'Priya Raman'),
  ('cust-vu', 'Verdant Utilities', 'VU', 'Energy & utilities',         'Priya Raman'),
  ('cust-ol', 'Orrery Logistics',  'OL', 'Logistics',                  'Priya Raman'),
  ('cust-sm', 'Solent Marine',     'SM', 'Defence',                    'Priya Raman'),
  ('cust-pm', 'Pellucid Media',    'PM', 'Media',                      'Priya Raman'),
  ('cust-kp', 'Kestrel Pharma',    'KP', 'Life sciences',              'Priya Raman');

INSERT INTO core.engagement VALUES
  ('eng-nr', 'cust-nr', 'Rail platform delivery',   'D. Okafor',    'active'),
  ('eng-hh', 'cust-hh', 'Health data platform',     'S. Adeyemi',   'active'),
  ('eng-cb', 'cust-cb', 'Payments modernisation',   'J. Whitfield', 'active'),
  ('eng-vu', 'cust-vu', 'Grid telemetry run',       'L. Marsh',     'active'),
  ('eng-ol', 'cust-ol', 'Fulfilment analytics',     'T. Nakamura',  'active'),
  ('eng-sm', 'cust-sm', 'Fleet maintenance system', 'A. Lindqvist', 'active'),
  ('eng-pm', 'cust-pm', 'Streaming ops retainer',   'R. Costa',     'active'),
  ('eng-kp', 'cust-kp', 'Trial data pipeline',      'M. Chen',      'active');

INSERT INTO core.contract_instrument VALUES
  ('ci-nr', 'eng-nr', 'MSA-2023-041 + SOW-14', 'sow',       'MSA + SOW-14 · fixed price',    420000000, 1160000000, 'GBP', DATE '2026-11-12', 90, '+£0.4m CO'),
  ('ci-hh', 'eng-hh', 'RM6187-CO-7',           'call_off',  'Framework RM6187 call-off',     510000000, NULL,       'GBP', DATE '2026-09-03', 60, '−£0.2m'),
  ('ci-cb', 'eng-cb', 'MSA-2021-009',          'msa',       'MSA + 3 SOWs · T&M',            840000000, NULL,       'GBP', DATE '2027-02-28', 90, '+£1.1m CO'),
  ('ci-vu', 'eng-vu', 'MS-2024-3',             'managed',   'Managed service · run',         330000000, NULL,       'GBP', DATE '2026-12-19', 60, NULL),
  ('ci-ol', 'eng-ol', 'SOW-22',                'sow',       'SOW-22 · fixed price',          260000000, NULL,       'GBP', DATE '2027-01-14', 30, '+£0.3m CO'),
  ('ci-sm', 'eng-sm', 'DEFCON-CO-3',           'call_off',  'DEFCON call-off',               190000000, NULL,       'GBP', DATE '2026-09-30', 30, '−£0.4m'),
  ('ci-pm', 'eng-pm', 'RET-2025-1',            'retainer',  'Retainer · rolling',            110000000, NULL,       'GBP', NULL,              90, NULL),
  ('ci-kp', 'eng-kp', 'MSA-2024-2 + SOW-08',   'sow',       'MSA + SOW-08',                  370000000, NULL,       'GBP', DATE '2026-10-22', 60, '+£0.1m');

-- Crosswalk (pilot accounts are hand-seeded — the real thing starts this way too)
INSERT INTO core.crosswalk VALUES
  ('xw-1', 'engagement', 'eng-nr', 'jira',       'jira_project',     'NWR',  'manual'),
  ('xw-2', 'engagement', 'eng-nr', 'salesforce', 'sf_account',       '0015f000NR', 'manual'),
  ('xw-3', 'engagement', 'eng-nr', 'workday',    'wd_project',       'NWR-DELIV',  'manual'),
  ('xw-4', 'customer',   'cust-nr','jsm',        'jsm_org',          'northwind',  'manual'),
  ('xw-5', 'engagement', 'eng-nr', 'confluence', 'confluence_space', 'NWR',  'manual'),
  ('xw-6', 'engagement', 'eng-nr', 'gdrive',     'gdrive_drive',     '0ANorthwindRail', 'manual');

-- Clauses (full set for Northwind; representative sets elsewhere) -------------
INSERT INTO core.clause VALUES
  ('cl-nr-72',  'ci-nr', 'eng-nr', '§7.2',  'Milestone gate — Release 4 evidence', 'Signed UAT pack + release note within 5 working days of gate date', '{"all_of":[{"evidence":"uat_pack","state":"verified","within_working_days_of":"gate_date","days":5},{"evidence":"release_note","state":"verified","within_working_days_of":"gate_date","days":5}]}', 1, 'auto', 'milestone_gate', 'milestone_hold', 34000000, 15),
  ('cl-nr-41',  'ci-nr', 'eng-nr', '§4.1',  'Availability — passenger app', '≥ 99.5% monthly, credits at 99.0%', '{"metric":"crash_free_rate","gte":99.5,"credit_at":99.0,"window_days":30}', 1, 'auto', 'sla', 'sla_credit', 6200000, 15),
  ('cl-nr-94',  'ci-nr', 'eng-nr', '§9.4',  'Change control — scope variation', 'All variation > £50k signed by both parties before work starts', '{"co_signed_before_work":true,"threshold_pennies":5000000}', 1, 'assisted', 'change_control', NULL, NULL, 60),
  ('cl-nr-121', 'ci-nr', 'eng-nr', '§12.1', 'Key personnel continuity', 'Named roles ≥ 80% continuity per quarter', '{"metric":"continuity_pct","gte":80,"window":"quarter"}', 1, 'auto', 'personnel', NULL, NULL, 60),
  ('cl-nr-63',  'ci-nr', 'eng-nr', '§6.3',  'Security remediation window', 'Critical CVE patched within 14 days of disclosure', '{"cve_patched_within_days":14}', 1, 'auto', 'security_remediation', NULL, NULL, 10),
  ('cl-nr-152', 'ci-nr', 'eng-nr', '§15.2', 'Reporting cadence', 'Monthly service report by 5th working day', '{"report_by_working_day":5}', 1, 'auto', 'reporting', NULL, NULL, 1440),
  ('cl-hh-63',  'ci-hh', 'eng-hh', 'Sch 2.4','Security remediation window', 'Critical CVE patched within 14 days — uncapped availability credit', '{"cve_patched_within_days":14}', 1, 'auto', 'security_remediation', 'uncapped_credit', NULL, 10),
  ('cl-hh-72',  'ci-hh', 'eng-hh', '§7.2',  'Milestone gate — Phase 2 evidence', 'Signed acceptance within 5 working days of gate', '{"evidence":"uat_pack","days":5}', 1, 'auto', 'milestone_gate', 'milestone_hold', 34000000, 15),
  ('cl-hh-41',  'ci-hh', 'eng-hh', '§4.1',  'Availability — clinician portal', '≥ 99.9% monthly', '{"metric":"availability_pct","gte":99.9}', 1, 'auto', 'sla', 'sla_credit', 4100000, 15),
  ('cl-cb-112', 'ci-cb', 'eng-cb', '§11.2', 'Release freeze', 'No production change during declared freeze windows', '{"freeze_until":"2026-08-14"}', 1, 'assisted', 'change_control', NULL, NULL, 60),
  ('cl-cb-41',  'ci-cb', 'eng-cb', '§4.1',  'Availability — payments API', '≥ 99.95% monthly', '{"metric":"availability_pct","gte":99.95}', 1, 'auto', 'sla', 'sla_credit', 9000000, 15),
  ('cl-vu-52',  'ci-vu', 'eng-vu', '§5.2',  'Telemetry data freshness', 'Grid readings delivered within 15 min for 99% of sites', '{"metric":"freshness_ok_pct","gte":99}', 1, 'auto', 'sla', 'sla_credit', 2500000, 15),
  ('cl-ol-31',  'ci-ol', 'eng-ol', '§3.1',  'Delivery milestones', 'Milestones delivered per plan ±10 days', '{"milestone_slip_days_lte":10}', 1, 'assisted', 'milestone_gate', NULL, NULL, 1440),
  ('cl-sm-21',  'ci-sm', 'eng-sm', '§2.1',  'Availability — maintenance system', '≥ 99.0% monthly', '{"metric":"availability_pct","gte":99.0}', 1, 'auto', 'sla', 'sla_credit', 1500000, 15),
  ('cl-pm-11',  'ci-pm', 'eng-pm', '§1.1',  'Response times', 'P1 response within 30 min', '{"metric":"p1_response_mins","lte":30}', 1, 'auto', 'sla', NULL, NULL, 15),
  ('cl-kp-81',  'ci-kp', 'eng-kp', '§8.1',  'GxP change notice', '30-day change notice + validation re-run for ingest-path changes', '{"change_notice_days":30}', 1, 'manual_attest', 'change_control', NULL, NULL, 1440),
  ('cl-kp-41',  'ci-kp', 'eng-kp', '§4.1',  'Pipeline availability', '≥ 99.5% monthly', '{"metric":"availability_pct","gte":99.5}', 1, 'auto', 'sla', 'sla_credit', 3000000, 15),
  ('cl-vu-71',  'ci-vu', 'eng-vu', '§7.1',  'Service reporting cadence', 'Monthly service report by 5th working day', '{"report_by_working_day":5}', 1, 'auto', 'reporting', NULL, NULL, 1440),
  ('cl-ol-88',  'ci-ol', 'eng-ol', '§8.8',  'Benefit case verification', 'Forecast-accuracy benefit independently verified each quarter', '{"benefit_verified_quarterly":true}', 1, 'assisted', 'benefit_case', NULL, NULL, 10080),
  ('cl-pm-52',  'ci-pm', 'eng-pm', '§5.2',  'Key personnel continuity', 'Named roles ≥ 80% continuity per quarter', '{"metric":"continuity_pct","gte":80}', 1, 'auto', 'personnel', NULL, NULL, 1440),
  ('cl-sm-91',  'ci-sm', 'eng-sm', '§9.1',  'Security patching window', 'Critical CVE patched within 21 days of disclosure', '{"cve_patched_within_days":21}', 1, 'auto', 'security_remediation', NULL, NULL, 60);

-- Latest clause evaluations. method='seeded' = a fixture, NOT a live control.
-- The backend re-evaluates §7.2 for real on startup and appends an 'evaluated'
-- row, so the console can honestly badge which verdicts a live control produced.
-- cols: id, clause_id, spec_version, evaluated_at, verdict, evidence_note, money_note, method, detail.
INSERT INTO audit.clause_evaluation VALUES
  ('ev-nr-72',  'cl-nr-72',  1, TIMESTAMP '2026-07-28 09:00:00', 'breach',  'Evidence missing · UAT pack not attached', '£340k held', 'seeded', '{"missing":["uat_pack"],"gate_date":"2026-07-17"}'),
  ('ev-nr-41',  'cl-nr-41',  1, TIMESTAMP '2026-07-28 09:00:00', 'at_risk', 'Rolling 30d: 99.1%', '£62k credit', 'seeded', '{"value":99.1,"threshold":99.5}'),
  ('ev-nr-94',  'cl-nr-94',  1, TIMESTAMP '2026-07-28 09:00:00', 'met',     'CO-2026-11 signed 14 Jul', NULL, 'seeded', '{}'),
  ('ev-nr-121', 'cl-nr-121', 1, TIMESTAMP '2026-07-28 08:10:00', 'met',     'Workday: 88% continuity', NULL, 'seeded', '{"value":88}'),
  ('ev-nr-63',  'cl-nr-63',  1, TIMESTAMP '2026-07-28 09:06:00', 'at_risk', 'CVE-2026-1180 · day 3 of 14', 'uncapped', 'seeded', '{"cve":"CVE-2026-1180","day":3,"window":14}'),
  ('ev-nr-152', 'cl-nr-152', 1, TIMESTAMP '2026-07-27 09:00:00', 'met',     '4 of 4 delivered on time', NULL, 'seeded', '{}'),
  ('ev-hh-63',  'cl-hh-63',  1, TIMESTAMP '2026-07-28 09:06:00', 'breach',  'CVE-2026-1180 · internet-facing prod unpatched', 'uncapped', 'seeded', '{"cve":"CVE-2026-1180"}'),
  ('ev-hh-72',  'cl-hh-72',  1, TIMESTAMP '2026-07-28 09:00:00', 'breach',  'Gate 3 evidence 9 days overdue', '£340k held', 'seeded', '{}'),
  ('ev-hh-41',  'cl-hh-41',  1, TIMESTAMP '2026-07-28 09:00:00', 'at_risk', 'Rolling 30d: 99.87%', NULL, 'seeded', '{"value":99.87}'),
  ('ev-cb-112', 'cl-cb-112', 1, TIMESTAMP '2026-07-28 08:00:00', 'met',     'Freeze respected · no prod change since 01 Jul', NULL, 'seeded', '{}'),
  ('ev-cb-41',  'cl-cb-41',  1, TIMESTAMP '2026-07-28 09:00:00', 'met',     'Rolling 30d: 99.98%', NULL, 'seeded', '{"value":99.98}'),
  ('ev-vu-52',  'cl-vu-52',  1, TIMESTAMP '2026-07-28 09:00:00', 'at_risk', 'Freshness 98.4% · threshold 99%', NULL, 'seeded', '{"value":98.4}'),
  ('ev-ol-31',  'cl-ol-31',  1, TIMESTAMP '2026-07-27 18:00:00', 'met',     'All milestones within window', NULL, 'seeded', '{}'),
  ('ev-sm-21',  'cl-sm-21',  1, TIMESTAMP '2026-07-28 09:00:00', 'breach',  'Rolling 30d: 98.2%', '£15k credit', 'seeded', '{"value":98.2}'),
  ('ev-pm-11',  'cl-pm-11',  1, TIMESTAMP '2026-07-28 09:00:00', 'met',     'P1 median response 12 min', NULL, 'seeded', '{"value":12}'),
  ('ev-kp-81',  'cl-kp-81',  1, TIMESTAMP '2026-07-27 12:00:00', 'at_risk', 'Ingest patch requires notice · window 02 Sep', NULL, 'seeded', '{}'),
  ('ev-kp-41',  'cl-kp-41',  1, TIMESTAMP '2026-07-28 09:00:00', 'met',     'Rolling 30d: 99.7%', NULL, 'seeded', '{"value":99.7}'),
  ('ev-vu-71',  'cl-vu-71',  1, TIMESTAMP '2026-07-27 09:00:00', 'met',     '4 of 4 delivered on time', NULL, 'seeded', '{}'),
  ('ev-ol-88',  'cl-ol-88',  1, TIMESTAMP '2026-07-20 09:00:00', 'met',     'Q2 benefit verified 94% vs 92% target', NULL, 'seeded', '{"value":94}'),
  ('ev-pm-52',  'cl-pm-52',  1, TIMESTAMP '2026-07-28 08:00:00', 'met',     'Workday: 91% continuity', NULL, 'seeded', '{"value":91}'),
  ('ev-sm-91',  'cl-sm-91',  1, TIMESTAMP '2026-07-28 09:06:00', 'at_risk', 'Edge telemetry agent v1.6.2 · advisory pending triage', NULL, 'seeded', '{}');

-- Outcomes — now with CLIENT-AGREED tolerance floors (behind_floor, at_risk_floor)
-- in the metric's own units. cols: id, eng, name, target, target_display, dir,
-- behind_floor, at_risk_floor, window_kind, window_days, metric, source.
INSERT INTO core.outcome VALUES
  ('out-nr-1', 'eng-nr', 'Passenger app crash-free rate', 99.5, '99.5%',    'gte', 99.3, 99.0, 'rolling', 30, 'crash_free_rate',   'jira'),
  ('out-nr-2', 'eng-nr', 'Depot telemetry coverage',      90,   '90 sites', 'gte', 85,   78,   'cumulative', NULL, 'telemetry_sites', 'jira'),
  ('out-nr-3', 'eng-nr', 'Mean incident response',        15,   '15 min',   'lte', 17,   20,   'rolling', 30, 'incident_response_mins', 'jsm'),
  ('out-nr-4', 'eng-nr', 'Ticketing throughput uplift',   15,   '+15%',     'gte', 13,   10,   'period', 91, 'ticketing_uplift_pct', 'derived'),
  ('out-nr-5', 'eng-nr', 'Legacy decommission',           7,    '7 systems','gte', 6,    5,    'cumulative', NULL, 'legacy_decommissioned', 'jira'),
  ('out-nr-6', 'eng-nr', 'Ops team certification',        40,   '40 staff', 'gte', 38,   35,   'cumulative', NULL, 'ops_certified', 'workday'),
  ('out-hh-1', 'eng-hh', 'Clinician portal availability', 99.9, '99.9%',    'gte', 99.8, 99.5, 'rolling', 30, 'availability_pct', 'jsm'),
  ('out-hh-2', 'eng-hh', 'Records migrated',              12,   '12m records','gte',10,   8,    'cumulative', NULL, 'records_migrated_m', 'jira'),
  ('out-cb-1', 'eng-cb', 'Payments API availability',     99.95,'99.95%',   'gte', 99.9, 99.8, 'rolling', 30, 'availability_pct', 'jsm'),
  ('out-cb-2', 'eng-cb', 'Batch cut-over milestones',     3,    '3 waves',  'gte', 2,    1,    'cumulative', NULL, 'cutover_waves', 'jira'),
  ('out-vu-1', 'eng-vu', 'Telemetry freshness',           99,   '99%',      'gte', 98.5, 98.0, 'rolling', 30, 'freshness_ok_pct', 'jsm'),
  ('out-vu-2', 'eng-vu', 'Site onboarding',               400,  '400 sites','gte', 370,  340,  'cumulative', NULL, 'sites_onboarded', 'jira'),
  ('out-ol-1', 'eng-ol', 'Forecast accuracy',             92,   '92%',      'gte', 90,   87,   'rolling', 30, 'forecast_accuracy_pct', 'derived'),
  ('out-ol-2', 'eng-ol', 'Warehouse dashboards live',     6,    '6 sites',  'gte', 5,    4,    'cumulative', NULL, 'dashboards_live', 'jira'),
  ('out-sm-1', 'eng-sm', 'System availability',           99,   '99%',      'gte', 98.5, 98.0, 'rolling', 30, 'availability_pct', 'jsm'),
  ('out-sm-2', 'eng-sm', 'Maintenance backlog reduction', 30,   '−30%',     'gte', 25,   18,   'period', 91, 'backlog_reduction_pct', 'derived'),
  ('out-pm-1', 'eng-pm', 'Stream uptime',                 99.9, '99.9%',    'gte', 99.7, 99.5, 'rolling', 30, 'availability_pct', 'jsm'),
  ('out-pm-2', 'eng-pm', 'Cost per stream hour',          0.8,  '≤ £0.80',  'lte', 0.9,  1.0,  'rolling', 30, 'cost_per_stream_hr', 'derived'),
  ('out-kp-1', 'eng-kp', 'Pipeline availability',         99.5, '99.5%',    'gte', 99.3, 99.0, 'rolling', 30, 'availability_pct', 'jsm'),
  ('out-kp-2', 'eng-kp', 'Trial sites live',              24,   '24 sites', 'gte', 20,   16,   'cumulative', NULL, 'trial_sites_live', 'jira');

-- Measurements: outcome actuals -------------------------------------------------
INSERT INTO core.measurement VALUES
  ('m-nr-cfr', 'eng-nr', 'crash_free_rate',        99.1, '99.1%',    TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'NWR-401'),
  ('m-nr-tel', 'eng-nr', 'telemetry_sites',        74,   '74 sites', TIMESTAMP '2026-04-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'NWR-482'),
  ('m-nr-inc', 'eng-nr', 'incident_response_mins', 11,   '11 min',   TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',  'INC-*'),
  ('m-nr-tik', 'eng-nr', 'ticketing_uplift_pct',   18,   '+18%',     TIMESTAMP '2026-04-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'derived', 'signed 02 Jul'),
  ('m-nr-leg', 'eng-nr', 'legacy_decommissioned',  3,    '3 of 7',   TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'NWR-388'),
  ('m-nr-ops', 'eng-nr', 'ops_certified',          46,   '46 staff', TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'LRN-2026'),
  ('m-hh-av',  'eng-hh', 'availability_pct', 99.87, '99.87%', TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'HAL-SLA'),
  ('m-hh-rec', 'eng-hh', 'records_migrated_m', 7.2, '7.2m',   TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'HAL-482'),
  ('m-cb-av',  'eng-cb', 'availability_pct', 99.98, '99.98%', TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'CB-SLA'),
  ('m-cb-cut', 'eng-cb', 'cutover_waves', 3, '3 of 3',        TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'CB-CUT'),
  ('m-vu-fr',  'eng-vu', 'freshness_ok_pct', 98.4, '98.4%',   TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'VU-SLA'),
  ('m-vu-si',  'eng-vu', 'sites_onboarded', 372, '372 sites', TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'VU-ONB'),
  ('m-ol-fa',  'eng-ol', 'forecast_accuracy_pct', 94, '94%',  TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived', 'OL-FCST'),
  ('m-ol-db',  'eng-ol', 'dashboards_live', 6, '6 of 6',      TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'OL-DASH'),
  ('m-sm-av',  'eng-sm', 'availability_pct', 98.2, '98.2%',   TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'SM-SLA'),
  ('m-sm-bl',  'eng-sm', 'backlog_reduction_pct', 12, '−12%', TIMESTAMP '2026-04-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived', 'SM-BLG'),
  ('m-pm-av',  'eng-pm', 'availability_pct', 99.95, '99.95%', TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'PM-SLA'),
  ('m-pm-co',  'eng-pm', 'cost_per_stream_hr', 0.74, '£0.74', TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived', 'PM-COST'),
  ('m-kp-av',  'eng-kp', 'availability_pct', 99.7, '99.7%',   TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'KP-SLA'),
  ('m-kp-ts',  'eng-kp', 'trial_sites_live', 19, '19 sites',  TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'KP-TRIAL');

-- Measurements: capacity & margin (Workday) --------------------------------------
INSERT INTO core.measurement VALUES
  ('m-nr-ut', 'eng-nr', 'utilisation_pct', 103, '103%', TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-nr-mg', 'eng-nr', 'margin_pct',      11,  '11%',  TIMESTAMP '2026-07-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-hh-ut', 'eng-hh', 'utilisation_pct', 88,  '88%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'HAL-DELIV'),
  ('m-hh-mg', 'eng-hh', 'margin_pct',      14,  '14%',  TIMESTAMP '2026-07-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'HAL-DELIV'),
  ('m-cb-ut', 'eng-cb', 'utilisation_pct', 94,  '94%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'CB-DELIV'),
  ('m-cb-mg', 'eng-cb', 'margin_pct',      21,  '21%',  TIMESTAMP '2026-07-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'CB-DELIV'),
  ('m-vu-ut', 'eng-vu', 'utilisation_pct', 71,  '71%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'VU-DELIV'),
  ('m-ol-ut', 'eng-ol', 'utilisation_pct', 97,  '97%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'OL-DELIV'),
  ('m-sm-ut', 'eng-sm', 'utilisation_pct', 64,  '64%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'SM-DELIV'),
  ('m-pm-ut', 'eng-pm', 'utilisation_pct', 91,  '91%',  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'PM-DELIV'),
  ('m-kp-ut', 'eng-kp', 'utilisation_pct', 108, '108%', TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'workday', 'KP-DELIV');

-- Measurements: sprint velocity (Jira; sprints 34–40 for NR, last 3 elsewhere) ---
INSERT INTO core.measurement VALUES
  ('m-nr-v34', 'eng-nr', 'velocity_points', 47, NULL, TIMESTAMP '2026-05-04 00:00:00', TIMESTAMP '2026-05-18 00:00:00', 'jira', 'sprint-34'),
  ('m-nr-v35', 'eng-nr', 'velocity_points', 46, NULL, TIMESTAMP '2026-05-18 00:00:00', TIMESTAMP '2026-06-01 00:00:00', 'jira', 'sprint-35'),
  ('m-nr-v36', 'eng-nr', 'velocity_points', 41, NULL, TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-06-15 00:00:00', 'jira', 'sprint-36'),
  ('m-nr-v37', 'eng-nr', 'velocity_points', 38, NULL, TIMESTAMP '2026-06-15 00:00:00', TIMESTAMP '2026-06-29 00:00:00', 'jira', 'sprint-37'),
  ('m-nr-v38', 'eng-nr', 'velocity_points', 36, NULL, TIMESTAMP '2026-06-29 00:00:00', TIMESTAMP '2026-07-06 00:00:00', 'jira', 'sprint-38'),
  ('m-nr-v39', 'eng-nr', 'velocity_points', 33, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-39'),
  ('m-nr-v40', 'eng-nr', 'velocity_points', 31, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-40'),
  ('m-hh-v1', 'eng-hh', 'velocity_points', 30, NULL, TIMESTAMP '2026-06-29 00:00:00', TIMESTAMP '2026-07-06 00:00:00', 'jira', 'sprint-21'),
  ('m-hh-v2', 'eng-hh', 'velocity_points', 28, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-22'),
  ('m-hh-v3', 'eng-hh', 'velocity_points', 27, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-23'),
  ('m-cb-v1', 'eng-cb', 'velocity_points', 40, NULL, TIMESTAMP '2026-06-29 00:00:00', TIMESTAMP '2026-07-06 00:00:00', 'jira', 'sprint-30'),
  ('m-cb-v2', 'eng-cb', 'velocity_points', 43, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-31'),
  ('m-cb-v3', 'eng-cb', 'velocity_points', 44, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-32'),
  ('m-ol-v1', 'eng-ol', 'velocity_points', 22, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-18'),
  ('m-ol-v2', 'eng-ol', 'velocity_points', 25, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-19'),
  ('m-sm-v1', 'eng-sm', 'velocity_points', 18, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-12'),
  ('m-sm-v2', 'eng-sm', 'velocity_points', 14, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-13'),
  ('m-kp-v1', 'eng-kp', 'velocity_points', 26, NULL, TIMESTAMP '2026-07-06 00:00:00', TIMESTAMP '2026-07-20 00:00:00', 'jira', 'sprint-15'),
  ('m-kp-v2', 'eng-kp', 'velocity_points', 24, NULL, TIMESTAMP '2026-07-20 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira', 'sprint-16');

-- Delivery outcomes: what capacity is actually driving (distinct from the
-- contracted outcomes above; contracted_outcome_id links where one supports one)
-- cols: id, eng, name, description, status, target_date, contracted_outcome_id, clause_id
INSERT INTO core.delivery_outcome VALUES
  ('do-nr-1', 'eng-nr', 'Wave 3 live across 16 depots',        'Depot telemetry rollout wave 3 — remaining 16 sites',            'at_risk',  DATE '2026-08-14', 'out-nr-2', NULL),
  ('do-nr-2', 'eng-nr', 'Crash-free ≥ 99.5% sustained',        'Passenger app stability programme to contractual threshold',     'at_risk',  DATE '2026-09-01', 'out-nr-1', NULL),
  -- CVE work defends §6.3 — now recorded as clause-aligned, not "operational"
  ('do-nr-3', 'eng-nr', 'CVE-2026-1180 remediated in prod',    'Ingest Gateway patched to v4.1.3 inside the §6.3 window',        'on_track', DATE '2026-08-10', NULL, 'cl-nr-63'),
  ('do-nr-4', 'eng-nr', 'Legacy ticketing systems 4–7 retired','Decommission wave blocked behind wave 3 capacity',               'late',     DATE '2026-10-30', 'out-nr-5', NULL);

-- Team assignments (Workday) — capacity is committed to delivery outcomes
INSERT INTO core.assignment VALUES
  ('as-nr-1', 'eng-nr', 'Delivery lead',            1, 1,   100, NULL,           NULL),
  ('as-nr-2', 'eng-nr', 'Platform engineering ×6',  6, 6,   112, 'ATTRITION ×2', 'do-nr-3'),
  ('as-nr-3', 'eng-nr', 'Data engineering ×4',      4, 4,   108, NULL,           'do-nr-1'),
  ('as-nr-4', 'eng-nr', 'QA ×3',                    3, 3,   96,  NULL,           'do-nr-2'),
  ('as-nr-5', 'eng-nr', 'Site reliability ×2',      3, 2,   62,  'OPEN ROLE ×1', 'do-nr-3');

-- Work items (Jira) — linked to the delivery outcome they drive -------------------
INSERT INTO core.work_item VALUES
  ('wi-nr-482', 'eng-nr', 'NWR-482', 'epic', 'Depot telemetry rollout — wave 3',   'gate',        '§7.2', TIMESTAMP '2026-07-19 09:00:00', 'do-nr-1'),
  ('wi-nr-455', 'eng-nr', 'NWR-455', 'epic', 'Ingest Gateway remediation',          'in_progress', NULL,   NULL,                            'do-nr-3'),
  ('wi-nr-401', 'eng-nr', 'NWR-401', 'epic', 'Passenger app stability programme',   'in_progress', NULL,   TIMESTAMP '2026-07-26 09:00:00', 'do-nr-2'),
  ('wi-nr-388', 'eng-nr', 'NWR-388', 'epic', 'Legacy ticketing decommission 4–7',   'not_started', NULL,   TIMESTAMP '2026-07-14 09:00:00', 'do-nr-4'),
  ('wi-nr-390', 'eng-nr', 'NWR-390', 'story','Ticketing benefit verification',      'done',        NULL,   NULL,                            NULL),
  ('wi-nr-501', 'eng-nr', 'NWR-501', 'story','Gateway v4.1.3 canary in staging',    'in_progress', NULL,   NULL,                            'do-nr-3'),
  ('wi-hh-482', 'eng-hh', 'HAL-482', 'epic', 'Phase 2 acceptance evidence pack',    'gate',        '§7.2', TIMESTAMP '2026-07-19 08:00:00', NULL),
  ('wi-hh-501', 'eng-hh', 'HAL-501', 'epic', 'Ingest Gateway emergency patch',      'in_progress', NULL,   NULL,                            NULL),
  ('wi-hh-460', 'eng-hh', 'HAL-460', 'epic', 'Records migration wave 4',            'in_progress', NULL,   TIMESTAMP '2026-07-24 09:00:00', NULL),
  ('wi-kp-341', 'eng-kp', 'KP-341',  'epic', 'Trial site onboarding batch 5',       'in_progress', NULL,   NULL,                            NULL),
  ('wi-kp-322', 'eng-kp', 'KP-322',  'story','GxP validation protocol prep',        'in_progress', NULL,   TIMESTAMP '2026-07-23 09:00:00', NULL),
  ('wi-sm-201', 'eng-sm', 'SM-201',  'epic', 'Legacy data import rework',           'in_progress', NULL,   TIMESTAMP '2026-07-07 09:00:00', NULL),
  ('wi-vu-140', 'eng-vu', 'VU-140',  'epic', 'Evening-peak gap investigation',      'in_progress', NULL,   TIMESTAMP '2026-07-21 09:00:00', NULL);

-- Evidence — including the missing UAT pack that breaches §7.2 ---------------------
INSERT INTO core.artifact_ref VALUES
  ('ar-1', 'jira_attachment', 'att-90211', NULL, 'https://jira.example/secure/attachment/90211', 'sha256:aa1'),
  ('ar-2', 'gdrive_file', '1xYzBenefitCase', 'rev-14', 'https://drive.google.com/file/d/1xYzBenefitCase', 'sha256:bb2'),
  ('ar-3', 'confluence_page', '55001', 'v7', 'https://confluence.example/pages/55001', 'sha256:cc3');

INSERT INTO core.evidence VALUES
  ('evd-nr-uat', 'eng-nr', 'cl-nr-72', 'uat_pack',            NULL,  'missing',  TIMESTAMP '2026-07-24 17:00:00', NULL, NULL),
  ('evd-nr-rel', 'eng-nr', 'cl-nr-72', 'release_note',        'ar-1','attached', TIMESTAMP '2026-07-24 17:00:00', NULL, NULL),
  ('evd-nr-ben', 'eng-nr', NULL,       'signed_benefit_case', 'ar-2','verified', NULL, TIMESTAMP '2026-07-02 10:00:00', 'P. Raman'),
  ('evd-nr-run', 'eng-nr', NULL,       'runbook',             'ar-3','verified', NULL, TIMESTAMP '2026-06-20 10:00:00', 'D. Okafor'),
  -- Halcyon Phase-2 gate evidence: UAT pack missing → the live evaluator breaches §7.2
  ('evd-hh-uat', 'eng-hh', 'cl-hh-72', 'uat_pack',            NULL,  'missing',  TIMESTAMP '2026-07-19 17:00:00', NULL, NULL);

-- Correlation backbone --------------------------------------------------------------
INSERT INTO core.shared_service VALUES
  ('svc-ig',  'Ingest Gateway v4',    '4.1.3'),
  ('svc-id',  'Identity broker v2',   '2.8.0'),
  ('svc-bus', 'Event bus (managed)',  '5.2.1'),
  ('svc-wh',  'Reporting warehouse',  '3.4.0'),
  ('svc-tel', 'Edge telemetry agent', '1.9.2');

INSERT INTO core.deployment VALUES
  ('dep-ig-nr', 'svc-ig', 'cust-nr', 'v4.1.0', 'prod',    'prod',              'internal'),
  ('dep-ig-hh', 'svc-ig', 'cust-hh', 'v4.1.2', 'prod',    'prod + 2 regional', 'internet_facing'),
  ('dep-ig-kp', 'svc-ig', 'cust-kp', 'v4.0.8', 'staging', 'staging only',      'none'),
  ('dep-ig-cb', 'svc-ig', 'cust-cb', 'v3.9.4', 'prod',    'prod',              'internal'),
  ('dep-ig-ol', 'svc-ig', 'cust-ol', 'v4.1.3', 'prod',    'prod',              'internal'),
  ('dep-id-nr', 'svc-id', 'cust-nr', 'v2.8.0', 'prod',    'prod',              'internal'),
  ('dep-id-hh', 'svc-id', 'cust-hh', 'v2.6.1', 'prod',    'prod',              'internal'),
  ('dep-tel-nr','svc-tel','cust-nr', 'v1.7.0', 'prod',    'prod',              'internal'),
  ('dep-tel-sm','svc-tel','cust-sm', 'v1.6.2', 'prod',    'prod',              'internal');

INSERT INTO core.vulnerability VALUES
  ('vul-1180', 'CVE-2026-1180', 'svc-ig', 'Deserialisation flaw in shared ingest component',
   'Deserialisation flaw in the shared ingest component. Correlated across customers by service inventory, then re-scored against each customer''s contractual obligations.',
   TIMESTAMP '2026-07-25 08:00:00', '4.1.3');

INSERT INTO core.vulnerability_affected_version VALUES
  ('vul-1180', 'v4.1.0'), ('vul-1180', 'v4.1.1'), ('vul-1180', 'v4.1.2'), ('vul-1180', 'v4.0.8');

INSERT INTO core.ticket VALUES
  ('tk-1', 'cust-kp', 'KP-311', 'incident', 'Malformed payload error on batch ingest',      'ingest:deserialise:payload', NULL, TIMESTAMP '2026-07-26 10:11:00', 'open',           'medium', 9,  0, 4, TIMESTAMP '2026-07-28 08:30:00'),
  ('tk-2', 'cust-kp', 'KP-314', 'incident', 'Ingest job fails on nested payload',           'ingest:deserialise:payload', NULL, TIMESTAMP '2026-07-27 08:40:00', 'open',           'medium', 5,  0, 3, TIMESTAMP '2026-07-28 07:55:00'),
  ('tk-3', 'cust-kp', 'KP-317', 'question', 'Repeated deserialisation warnings in staging', 'ingest:deserialise:payload', NULL, TIMESTAMP '2026-07-27 15:02:00', 'waiting_us',     'low',    3,  0, 2, TIMESTAMP '2026-07-27 17:40:00'),
  ('tk-4', 'cust-nr', 'NW-208', 'incident', 'Ingest latency p99 4× above baseline',         'ingest:latency:p99',         NULL, TIMESTAMP '2026-07-25 09:20:00', 'open',           'high',   14, 1, 6, TIMESTAMP '2026-07-28 09:05:00'),
  ('tk-5', 'cust-hh', 'HL-455', 'incident', 'Ingest latency spike on clinician portal',     'ingest:latency:p99',         NULL, TIMESTAMP '2026-07-25 10:00:00', 'open',           'high',   11, 0, 5, TIMESTAMP '2026-07-28 08:50:00'),
  ('tk-6', 'cust-vu', 'VU-188', 'incident', 'Grid telemetry gaps during evening peak',      'telemetry:freshness:gap',    NULL, TIMESTAMP '2026-07-14 18:20:00', 'waiting_client', 'medium', 34, 2, 7, TIMESTAMP '2026-07-28 06:10:00'),
  ('tk-7', 'cust-sm', 'SM-097', 'incident', 'Maintenance sync fails after nightly batch',   'sync:batch:timeout',         NULL, TIMESTAMP '2026-07-19 07:45:00', 'open',           'medium', 21, 3, 5, TIMESTAMP '2026-07-27 22:15:00'),
  ('tk-8', 'cust-nr', 'NW-214', 'request',  'Access request for depot dashboard pilots',    'access:provisioning',        NULL, TIMESTAMP '2026-07-27 11:00:00', 'waiting_client', 'low',    2,  0, 2, TIMESTAMP '2026-07-27 16:20:00');

-- Weekly signal snapshots (last written 21 Jul) — the RAG board diffs against these
INSERT INTO audit.signal_snapshot VALUES
  (DATE '2026-07-21', 'cust-nr', 'watch',    4, 6, 0, 2, 101, -9,  2),
  (DATE '2026-07-21', 'cust-hh', 'watch',    1, 2, 1, 1, 90,  -4,  1),
  (DATE '2026-07-21', 'cust-cb', 'on_track', 2, 2, 0, 0, 95,  4,   0),
  (DATE '2026-07-21', 'cust-vu', 'watch',    1, 2, 0, 1, 74,  0,   0),
  (DATE '2026-07-21', 'cust-ol', 'on_track', 2, 2, 0, 0, 96,  9,   0),
  (DATE '2026-07-21', 'cust-sm', 'watch',    1, 2, 0, 1, 70,  -14, 1),
  (DATE '2026-07-21', 'cust-pm', 'on_track', 2, 2, 0, 0, 92,  2,   0),
  (DATE '2026-07-21', 'cust-kp', 'watch',    1, 2, 0, 1, 104, -5,  1);

-- Client artifact library --------------------------------------------------------
INSERT INTO core.artifact VALUES
  ('af-nr-1', 'cust-nr', 'eng-nr', 'site_visit_report',   'Site visit — Doncaster depot, June 2026', 'Telemetry install review across 4 depots; 2 cabling blockers noted for wave 3.', 'final',    'gdrive',     '1SvDoncasterJun26', 'https://drive.google.com/file/d/1SvDoncasterJun26', 'rev-3', 'D. Okafor',  TIMESTAMP '2026-06-18 16:00:00'),
  ('af-nr-2', 'cust-nr', 'eng-nr', 'target_architecture', 'Target architecture v3',                  'Approved end-state: all depot and passenger feeds route through Ingest Gateway v4 as the sole ingest path.', 'approved', 'confluence', '55014', 'https://confluence.example/pages/55014', 'v3', 'S. Varga',   TIMESTAMP '2026-05-02 11:00:00'),
  ('af-nr-3', 'cust-nr', 'eng-nr', 'capacity_plan',       'Capacity plan H2 FY26',                   'Staffing plan through renewal; assumes 21 FTE — currently 18.5 assigned.', 'in_review', 'gdrive',     '1CapPlanH2FY26', 'https://drive.google.com/file/d/1CapPlanH2FY26', 'rev-7', 'P. Raman',   TIMESTAMP '2026-07-10 09:30:00'),
  ('af-nr-4', 'cust-nr', 'eng-nr', 'incident_review',     'PIR — ingest latency event, 25 Jul',      'p99 4× baseline for 3h10m; traced to deserialisation retries on Ingest Gateway v4.1.0.', 'final', 'confluence', '55021', 'https://confluence.example/pages/55021', 'v2', 'SRE rota',   TIMESTAMP '2026-07-26 14:00:00'),
  ('af-nr-5', 'cust-nr', 'eng-nr', 'feature_request',     'Passenger app offline mode',              'Requested by client ops; scoped at 6 wks; awaiting CO.', 'open',      'jira',       'NWR-511', 'https://jira.example/browse/NWR-511', NULL, 'Client PO',  TIMESTAMP '2026-07-08 10:15:00'),
  ('af-nr-6', 'cust-nr', 'eng-nr', 'feature_request',     'Depot analytics dashboard',               'Wave-3 dependent; bundled into Q4 roadmap review.', 'in_review', 'jira',       'NWR-498', 'https://jira.example/browse/NWR-498', NULL, 'Client PO',  TIMESTAMP '2026-06-30 13:40:00'),
  ('af-nr-7', 'cust-nr', 'eng-nr', 'accelerator',         'Meridian ingest blueprint',               'Standard ingest topology adopted at kickoff; cut integration build by ~5 wks.', 'adopted',   'confluence', '54900', 'https://confluence.example/pages/54900', 'v5', 'Platform team', TIMESTAMP '2026-02-12 09:00:00'),
  ('af-hh-1', 'cust-hh', 'eng-hh', 'target_architecture', 'Target architecture v2',                  'Clinician portal and regional feeds consolidated onto shared Ingest Gateway v4 tier.', 'approved', 'confluence', '61002', 'https://confluence.example/pages/61002', 'v2', 'S. Adeyemi', TIMESTAMP '2026-04-14 10:00:00'),
  ('af-hh-2', 'cust-hh', 'eng-hh', 'capacity_plan',       'Ingest tier capacity plan',               'Peak load at 82% of provisioned capacity — no headroom for re-processing bursts.', 'final',    'gdrive',     '1HHCapIngest', 'https://drive.google.com/file/d/1HHCapIngest', 'rev-2', 'S. Adeyemi', TIMESTAMP '2026-06-05 15:20:00'),
  ('af-hh-3', 'cust-hh', 'eng-hh', 'site_visit_report',   'Site visit — regional DC, May 2026',      'Regional failover exercise; both regions confirmed on shared ingest tier.', 'final',    'gdrive',     '1HHSvMay26', 'https://drive.google.com/file/d/1HHSvMay26', 'rev-1', 'S. Adeyemi', TIMESTAMP '2026-05-22 17:00:00'),
  ('af-hh-4', 'cust-hh', 'eng-hh', 'accelerator',         'FHIR interface toolkit',                  'Accelerator adopted for records migration; drives the 12m-records outcome.', 'adopted',   'confluence', '60940', 'https://confluence.example/pages/60940', 'v3', 'Platform team', TIMESTAMP '2026-03-01 09:00:00'),
  ('af-kp-1', 'cust-kp', 'eng-kp', 'target_architecture', 'Trial pipeline architecture v1',          'Staging mirrors prod ingest path exactly — any ingest change triggers GxP validation re-run.', 'approved', 'confluence', '70211', 'https://confluence.example/pages/70211', 'v1', 'M. Chen',    TIMESTAMP '2026-04-28 12:00:00'),
  ('af-kp-2', 'cust-kp', 'eng-kp', 'feature_request',     'Batch ingest API for site uploads',       'Client-requested; on hold pending §8.1 change window.', 'open',      'jira',       'KP-290', 'https://jira.example/browse/KP-290', NULL, 'Client QA lead', TIMESTAMP '2026-07-02 09:45:00'),
  ('af-cb-1', 'cust-cb', 'eng-cb', 'runbook',             'Ingest Gateway v3.9.4 remediation runbook','Reference remediation for CVE-2026-1180 — reused for the cross-customer patch wave.', 'final', 'confluence', '58230', 'https://confluence.example/pages/58230', 'v4', 'J. Whitfield', TIMESTAMP '2026-06-20 11:30:00');

-- Products launched with each client, linked to their source -----------------------
INSERT INTO core.product VALUES
  ('pr-nr-app',  'cust-nr', 'eng-nr', 'Passenger App',           'mobile_app',   'ga',    DATE '2025-11-03', 'svc-id',  'https://github.example/northwind/passenger-app',   'v3.8.2'),
  ('pr-nr-tel',  'cust-nr', 'eng-nr', 'Depot Telemetry Pipeline','data_pipeline','beta',  DATE '2026-03-15', 'svc-ig',  'https://github.example/northwind/depot-telemetry', 'v0.9.4'),
  ('pr-nr-tik',  'cust-nr', 'eng-nr', 'Ticketing Platform',      'platform',     'ga',    DATE '2025-06-20', 'svc-ig',  'https://github.example/northwind/ticketing',       'v2.4.0'),
  ('pr-hh-por',  'cust-hh', 'eng-hh', 'Clinician Portal',        'portal',       'ga',    DATE '2025-09-10', 'svc-ig',  'https://github.example/halcyon/clinician-portal',  'v5.1.1'),
  ('pr-kp-pipe', 'cust-kp', 'eng-kp', 'Trial Data Pipeline',     'data_pipeline','pilot', DATE '2026-05-01', 'svc-ig',  'https://github.example/kestrel/trial-pipeline',    'v0.4.0'),
  ('pr-cb-pay',  'cust-cb', 'eng-cb', 'Payments API',            'api',          'ga',    DATE '2024-12-01', 'svc-ig',  'https://github.example/castellan/payments-api',    'v7.2.3'),
  ('pr-vu-grid', 'cust-vu', 'eng-vu', 'Grid Telemetry Portal',   'portal',       'ga',    DATE '2025-08-14', 'svc-tel', 'https://github.example/verdant/grid-portal',       'v2.1.0'),
  ('pr-sm-cmd',  'cust-sm', 'eng-sm', 'Maintenance Command',     'platform',     'ga',    DATE '2025-04-30', 'svc-tel', 'https://github.example/solent/maint-command',      'v1.6.0'),
  ('pr-ol-dash', 'cust-ol', 'eng-ol', 'Fulfilment Dashboard',    'portal',       'ga',    DATE '2026-01-20', 'svc-wh',  'https://github.example/orrery/fulfilment-dash',    'v1.2.2'),
  ('pr-pm-ops',  'cust-pm', 'eng-pm', 'Streaming Ops Console',   'platform',     'ga',    DATE '2025-10-05', 'svc-bus', 'https://github.example/pellucid/streaming-ops',    'v4.0.1');

-- Product telemetry -----------------------------------------------------------------
INSERT INTO core.telemetry VALUES
  ('tel-nr-app-cf',  'pr-nr-app',  'crash_free_pct',  99.1,  '99.1%',        99.5, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jira',  'Crashlytics export'),
  ('tel-nr-app-p99', 'pr-nr-app',  'p99_latency_ms',  340,   '340 ms',       310,  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'APM weekly'),
  ('tel-nr-app-mau', 'pr-nr-app',  'mau',             1200000,'1.2m MAU',    NULL, TIMESTAMP '2026-07-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived','analytics'),
  ('tel-nr-tel-up',  'pr-nr-tel',  'uptime_pct',      99.4,  '99.4%',        99.9, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-nr-tel-p99', 'pr-nr-tel',  'p99_latency_ms',  1280,  '1.28 s · 4× baseline', 320, TIMESTAMP '2026-07-25 00:00:00', TIMESTAMP '2026-07-26 00:00:00', 'jsm', 'INC NW-208'),
  ('tel-nr-tik-thr', 'pr-nr-tik',  'throughput_rps',  118,   '+18% vs plan', 100,  TIMESTAMP '2026-04-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'derived','benefit case'),
  ('tel-hh-por-p99', 'pr-hh-por',  'p99_latency_ms',  890,   '890 ms · 4× baseline', 210, TIMESTAMP '2026-07-25 00:00:00', TIMESTAMP '2026-07-26 00:00:00', 'jsm', 'INC HL-455'),
  ('tel-hh-por-up',  'pr-hh-por',  'uptime_pct',      99.87, '99.87%',       99.9, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-kp-pipe-er', 'pr-kp-pipe', 'error_rate_pct',  2.1,   '2.1% errors',  0.5,  TIMESTAMP '2026-07-25 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'KP-311/314/317'),
  ('tel-kp-pipe-up', 'pr-kp-pipe', 'uptime_pct',      99.7,  '99.7%',        99.5, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-cb-pay-up',  'pr-cb-pay',  'uptime_pct',      99.98, '99.98%',       99.95,TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-cb-pay-p99', 'pr-cb-pay',  'p99_latency_ms',  95,    '95 ms',        110,  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'APM weekly'),
  ('tel-cb-pay-thr', 'pr-cb-pay',  'throughput_rps',  2400,  '2.4k rps',     NULL, TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived','APM weekly'),
  ('tel-vu-grid-fr', 'pr-vu-grid', 'uptime_pct',      99.6,  '99.6%',        99.5, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-vu-grid-er', 'pr-vu-grid', 'error_rate_pct',  1.6,   '1.6% evening peak', 0.4, TIMESTAMP '2026-07-14 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'VU-188'),
  ('tel-sm-cmd-up',  'pr-sm-cmd',  'uptime_pct',      98.2,  '98.2%',        99.0, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-sm-cmd-er',  'pr-sm-cmd',  'error_rate_pct',  3.4,   '3.4% after nightly batch', 0.8, TIMESTAMP '2026-07-19 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm', 'SM-097'),
  ('tel-ol-dash-up', 'pr-ol-dash', 'uptime_pct',      99.9,  '99.9%',        99.5, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-ol-dash-mau','pr-ol-dash', 'mau',             8400,  '8.4k MAU',     NULL, TIMESTAMP '2026-07-01 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'derived','analytics'),
  ('tel-pm-ops-up',  'pr-pm-ops',  'uptime_pct',      99.95, '99.95%',       99.9, TIMESTAMP '2026-06-28 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'SLA cycle'),
  ('tel-pm-ops-p99', 'pr-pm-ops',  'p99_latency_ms',  180,   '180 ms',       200,  TIMESTAMP '2026-07-21 00:00:00', TIMESTAMP '2026-07-28 00:00:00', 'jsm',   'APM weekly');

-- Platform gaps blocking clients ------------------------------------------------
INSERT INTO core.platform_gap VALUES
  ('gap-1', 'Ingest Gateway v4.1.3 rollout wave', 'Patched gateway build is canaried but not yet GA across client environments; blocks CVE remediation and everything queued behind it.', 'in_progress', DATE '2026-08-10', 'Platform team'),
  ('gap-2', 'Self-serve sandbox environments',    'No client-facing sandbox provisioning; pilots and client-side integration testing queue on platform engineers.', 'in_design',   DATE '2026-10-01', 'Platform team'),
  ('gap-3', 'Bulk historical replay API',         'No way to replay historical event windows; incident investigations that need reprocessing stall.', 'backlog',     DATE '2026-09-15', 'Platform team');

-- cols: gap_id, customer_id, blocking_note, linked_ref, blocks_kind, clause_id.
-- blocks_kind drives severity ranking (clause > gate > incident > feature_request).
INSERT INTO core.platform_gap_customer VALUES
  ('gap-1', 'cust-nr', 'Wave 3 capacity stays diverted until the patch ships; §6.3 clock at day 3 of 14.', 'NWR-455', 'clause', 'cl-nr-63'),
  ('gap-1', 'cust-hh', 'Uncapped availability credit exposure until patched; leads the wave.', 'HAL-501', 'clause', 'cl-hh-63'),
  ('gap-1', 'cust-kp', 'Patch forces GxP validation re-run; queued for the 02 Sep window.', 'KP-322', 'clause', 'cl-kp-81'),
  ('gap-2', 'cust-nr', 'Depot dashboard pilots waiting on environment access.', 'NW-214', 'feature_request', NULL),
  ('gap-2', 'cust-kp', 'Batch ingest API feature request on hold — no sandbox to validate against.', 'KP-290', 'feature_request', NULL),
  ('gap-3', 'cust-vu', 'Evening-peak gap investigation needs historical replay to reproduce.', 'VU-188', 'incident', NULL),
  ('gap-3', 'cust-sm', 'Nightly batch sync fix cannot be verified without replaying failed windows.', 'SM-097', 'incident', NULL);

-- Definitions served from the lake so the console explains its own numbers AND
-- reads its thresholds from ONE place. cols: key, title, definition, formula,
-- inputs, thresholds(JSON). The frontend consumes `thresholds` — no concept's
-- cutoffs are hard-coded in two places any more.
INSERT INTO core.definition VALUES
  ('velocity', 'How velocity is defined',
   'Velocity is completed story points per sprint from Jira, scoped to the engagement. The trend compares the latest sprint to the mean of the six sprints before it. Falling velocity never alarms on its own — it only matters when it correlates with an at-risk outcome or clause, because activity is not the promise; outcomes are.',
   'delta_pct = (latest_sprint_points − mean(previous 6 sprints)) / mean(previous 6 sprints)',
   'core.measurement where metric = velocity_points (Jira sprint closes) → semantic.v_velocity_trend',
   '{"crit_pct":-15,"warn_pct":0,"gated_on":"only shown as a risk when an at-risk outcome or clause co-occurs"}'),
  ('delivery_risk', 'How delivery risk is defined',
   'A risk is a journal entry linked to the client that is not closed. Risks are raised automatically by controls (clause breach, missing evidence, sustained over-utilisation, renewal runway, cross-customer correlation) or manually by the CSM. Every risk carries severity, an owner, a due date and links to the evidence that justifies it — a risk with no evidence link fails review.',
   'open_risks = count(audit.journal_entry where state ≠ closed, joined via journal_entry_customer)',
   'audit.journal_entry + journal_entry_link (clause refs, Jira/JSM keys, CVEs, money at stake)',
   NULL),
  ('blocked', 'How blocked is defined',
   'Work is blocked when its Jira status-transition history shows no forward movement since blocked_since — it is derived from the source system, never self-reported. Blocked age is calendar days since that timestamp. Gate items are blocked work that also holds contractual evidence (§ refs), so they rank first.',
   'blocked_days = days(now − blocked_since); status = blocked when blocked_since set and state ≠ done',
   'core.work_item (Jira changelog) → semantic.v_client_workload',
   '{"crit_days":7,"warn_days":1}'),
  ('platform_gap', 'How platform gaps are defined',
   'A platform gap is a capability the platform is missing that blocks client work — ours to fix, not the client''s. Gaps are ranked by the WORST thing each blocks (clause > gate > incident > feature request), then by reach — how many clients they block.',
   'rank by (worst_blocks_kind, reach desc); severity inherits from the worst thing it blocks',
   'core.platform_gap + platform_gap_customer.blocks_kind → semantic.v_platform_gap_ranked',
   '{"kind_order":["clause","gate","incident","feature_request"]}'),
  ('health_band', 'How the health band is defined',
   'A rule over contracted outcomes, smart-contract clauses, capacity and renewal — defensible to a client. AT RISK: two or more clause breaches; or a breach with under half of outcomes on track; or a renewal inside its notice window with no open opportunity. WATCH: any breach, at-risk clause, cannot-evaluate clause, or at-risk outcome; utilisation over 100% or under 75%; a four-week-plus over-utilisation streak; or a steep velocity drop alongside an at-risk outcome. Missing source data is NEVER treated as healthy — it surfaces as a data-quality flag.',
   'see semantic.v_customer_signal CASE; missing utilisation is not coerced to a passing value',
   'semantic.v_engagement_rollup (clauses incl. cannot_evaluate, outcomes incl. at_risk, util streak) + renewal',
   '{"at_risk_breaches":2,"watch_util_over":100,"watch_util_under":75,"util_streak_weeks":4,"velocity_crit_pct":-15}'),
  ('outcome_status', 'How outcome status is defined',
   'Each contracted outcome is banded against CLIENT-AGREED tolerances in the metric''s own units, not a percentage of target. MET: at or beyond target. BEHIND: short of target but at/above the agreed behind-floor. AT RISK: below the behind-floor. Where a client tolerance was not captured, a documented fallback applies (1% of target for behind, 3% for at-risk). This is why 99.1% against a 99.5% crash-free obligation reads AT RISK, not merely "behind".',
   'met | behind (≥ behind_floor) | at_risk (< behind_floor); is_critical when past at_risk_floor',
   'core.outcome.behind_floor / at_risk_floor vs latest core.measurement → semantic.v_outcome_status',
   '{"fallback_behind_pct":1,"fallback_at_risk_pct":3}'),
  ('exposure', 'How exposure is defined',
   'ONE number, computed once per customer. Contractual exposure is the money contractually crystallised right now — the sum of remedy amounts on clauses currently in breach or at risk. Uncapped remedies are flagged, never invented as a figure. Separately, ACV under watch is an account''s ACV shown as context when it is not on track — labelled as context, not a loss estimate. The portfolio figure sums per-customer rows, so a shared cross-customer risk is not double-counted.',
   'remedy_pennies = Σ live breach/at_risk clause remedies (excl. uncapped); acv_under_watch = ACV once, when band ≠ on_track',
   'semantic.v_exposure over semantic.v_clause_latest + v_customer_signal',
   NULL),
  ('outcome_index', 'How the outcome index is defined',
   'A 0–100 mean of per-outcome attainment for the engagement. It is a summary, not a contractual figure; a single critical miss is visible in the outcome list and in the health band regardless of the index. Attainment is capped at 100 so an over-delivered outcome cannot mask a shortfall beyond its own weight.',
   'index = avg(attainment_pct) across the engagement''s outcomes',
   'semantic.v_outcome_status.attainment_pct',
   '{"warn":75}'),
  ('bubble_score', 'How the bubbling-incident score is defined',
   'A heuristic that ranks live service tickets by how much they behave like a brewing severe incident: comment volume (capped, so a long healthy thread does not dominate), reopens (weighted most heavily), participant count, whether the same symptom fingerprint appears at other customers, and priority — minus a discount when the ball is in the client''s court (waiting on client). It is a triage aid shown with its reasons, not a severity rating.',
   'score = min(comments,20) + 6·reopens + 2·participants + 10·[cross-customer] + priority − 6·[waiting_client]',
   'semantic.v_bubbling_incidents over core.ticket',
   '{"comment_cap":20,"reopen_weight":6,"participant_weight":2,"cross_customer":10,"high_priority":8,"medium_priority":3,"waiting_client_discount":6}'),
  ('utilisation', 'How utilisation is banded',
   'Workday utilisation per engagement. Over 100% is over-committed (burnout/attrition risk); under 75% is bench (margin risk). A sustained streak of four or more weeks over 100% is the real burnout signal, not a single hot week. Missing utilisation is shown as a data-quality gap, never as healthy.',
   'crit when > 105; watch when > 100 or < 75; streak = consecutive latest weeks over 100',
   'core.measurement metric=utilisation_pct → v_util_streak / v_engagement_rollup',
   '{"crit":105,"over":100,"under":75,"streak_weeks":4}'),
  ('renewal_runway', 'How renewal runway is defined',
   'Days to the earliest renewal across an engagement''s instruments, read against the contractual notice period — the real decision point is renewal date minus notice days, not the renewal date itself. A renewal inside its notice window with no open opportunity is an automatic escalation.',
   'renewal_days = days(renewal_date − today); decision window = renewal_days − notice_days',
   'semantic.v_engagement_contract (earliest instrument) + core.renewal_motion',
   '{"crit_days":45,"warn_days":110,"kpi_window_days":90,"runway_list_days":180}'),
  ('capacity_coverage', 'How outcome coverage is defined',
   'Whether capacity actually stands behind each contracted outcome. An outcome that is not met and has zero committed FTE behind it (via delivery outcomes) is flagged UNALIGNED — the silent gap between what we promised and what we are staffing. Clause-defending delivery work counts as aligned even when it maps to no contracted outcome.',
   'unaligned = outcome_status in (behind, at_risk, unknown) AND committed_fte = 0',
   'core.outcome × core.delivery_outcome × core.assignment → semantic.v_outcome_coverage',
   NULL),
  ('client_voice', 'How client-voice signals are defined',
   'Leading indicators of the client''s experience, distinct from our delivery performance: CSAT and its trend, days since the client last engaged (silence is a churn precursor), how long tickets sit waiting on the client, and sponsor status. These are what would have surfaced Solent Marine a quarter before the contract mechanics forced the conversation.',
   'csat_delta = latest − previous; days_since_client_activity; waiting_client_days; sponsor_status',
   'core.measurement metric=csat, core.ticket activity, core.stakeholder → semantic.v_client_voice',
   '{"csat_drop_warn":-0.5,"silence_days_warn":21,"waiting_client_days_warn":10}'),
  ('gate_runway', 'How gate runway is defined',
   'Milestone gates are forward-dated. A gate is at risk BEFORE the date if its required evidence is not yet verified. Days-to-gate counts down; negative means the window has closed. An overdue gate with unverified evidence is the most severe case and is always counted. This turns the milestone control from post-mortem into pre-mortem.',
   'days_to_gate = days(gate_date − today); at_risk when days_to_gate ≤ 30 (incl. overdue) AND evidence not verified',
   'core.milestone × core.evidence → semantic.v_gate_runway',
   '{"warn_days":30,"crit_days":10}'),
  ('rag_snapshot', 'How the RAG baseline and staleness work',
   'The RAG board diffs the live signal against the most recent weekly snapshot at least ~6 days old, so a snapshot written mid-week never collapses the "since we last talked" baseline. If the newest usable baseline is older than the stale threshold, the console holds the deltas (greys them, no confident "this week") rather than presenting old diffs as current.',
   'baseline = latest snapshot ≤ today − baseline_min_age_days; suppress deltas when age > stale_days',
   'audit.signal_snapshot (writer runs weekly) → semantic.v_rag_movement',
   '{"baseline_min_age_days":6,"stale_days":14}');

-- Impact evidence: why we think each customer is impacted by CVE-2026-1180,
-- every row traceable to a source record -------------------------------------------
INSERT INTO audit.impact_evidence VALUES
  ('ie-nr-1', 'vulnerability', 'vul-1180', 'cust-nr', 'deployment', 'dep-ig-nr',      'Service inventory shows prod on v4.1.0, an affected version.', 'confirmed', TIMESTAMP '2026-07-28 09:10:00'),
  ('ie-nr-2', 'vulnerability', 'vul-1180', 'cust-nr', 'artifact',   'af-nr-2',        'Approved target architecture routes ALL feeds through Ingest Gateway v4 — no alternative path.', 'confirmed', TIMESTAMP '2026-07-28 09:10:00'),
  ('ie-nr-3', 'vulnerability', 'vul-1180', 'cust-nr', 'ticket',     'tk-4',           'Ingest latency p99 4× baseline reported before disclosure was public.', 'probable', TIMESTAMP '2026-07-28 09:10:00'),
  ('ie-nr-4', 'vulnerability', 'vul-1180', 'cust-nr', 'artifact',   'af-nr-4',        'Post-incident review traces the 25 Jul event to deserialisation retries — the CVE mechanism.', 'confirmed', TIMESTAMP '2026-07-28 09:12:00'),
  ('ie-hh-1', 'vulnerability', 'vul-1180', 'cust-hh', 'deployment', 'dep-ig-hh',      'Prod + 2 regions on v4.1.2 (affected), internet-facing.', 'confirmed', TIMESTAMP '2026-07-28 09:10:00'),
  ('ie-hh-2', 'vulnerability', 'vul-1180', 'cust-hh', 'telemetry',  'tel-hh-por-p99', 'Clinician portal p99 spiked 4× within 40 min of the Northwind event — same signature.', 'confirmed', TIMESTAMP '2026-07-28 09:11:00'),
  ('ie-hh-3', 'vulnerability', 'vul-1180', 'cust-hh', 'artifact',   'af-hh-2',        'Capacity plan shows ingest tier at 82% peak — no headroom to absorb re-processing after patching.', 'probable', TIMESTAMP '2026-07-28 09:12:00'),
  ('ie-kp-1', 'vulnerability', 'vul-1180', 'cust-kp', 'deployment', 'dep-ig-kp',      'Staging on v4.0.8 (affected); not internet-facing, so exposure is indirect.', 'probable', TIMESTAMP '2026-07-28 09:10:00'),
  ('ie-kp-2', 'vulnerability', 'vul-1180', 'cust-kp', 'ticket',     'tk-1',           'Three tickets share the malformed-payload fingerprint; client has not linked them to the CVE.', 'probable', TIMESTAMP '2026-07-28 09:11:00'),
  ('ie-kp-3', 'vulnerability', 'vul-1180', 'cust-kp', 'artifact',   'af-kp-1',        'Architecture doc: staging mirrors prod ingest path, so the patch forces a GxP validation re-run.', 'confirmed', TIMESTAMP '2026-07-28 09:12:00');

INSERT INTO core.renewal_motion VALUES
  ('eng-sm', FALSE, 'No opportunity open · CSAT 6.1'),
  ('eng-hh', TRUE,  'Re-compete · 2 clause breaches live'),
  ('eng-kp', TRUE,  'Expansion case drafted'),
  ('eng-nr', TRUE,  'Change order £0.4m in review'),
  ('eng-vu', TRUE,  'Auto-renews unless 60d notice');

-- Journal. cols: id, risk_ref, severity, tone, title, body, scope_label,
-- cluster_id, movement_from, movement_to, state, owner, due_note, due_at,
-- exposure_pennies, action_label, action_view, origin, created_at, author.
-- origin = control|manual|seed; authors no longer impersonate named live
-- services ('system:*'); exposure figures are per-item money at stake, not whole
-- ACVs (portfolio money now derives from v_exposure, not by summing these).
INSERT INTO audit.journal_entry VALUES
  ('jr-1180', 'RSK-1180', 'P1', 'crit', 'Shared ingest component vulnerable across 3 accounts', 'Automated correlation opened a cross-customer cluster after CVE-2026-1180 matched the service inventory for Northwind, Halcyon and Kestrel. Contract re-scoring shows Halcyon carries an uncapped availability credit and the shortest remediation window, so it leads the patch wave. Castellan is on v3.9.4 and unaffected; their runbook has been attached as the reference remediation.', 'Cross-customer · 3 clients', 'C-114', 'New', 'Open · P1', 'open', 'P. Raman', 'Wave 1 due 08 Aug', DATE '2026-08-08', NULL, 'OPEN CLUSTER', 'correlate', 'control', TIMESTAMP '2026-07-28 09:14:00', 'Meridian correlation (seeded)'),
  ('jr-1164', 'RSK-1164', 'P1', 'crit', 'Gate 3 evidence overdue — £340k milestone blocked', 'Release 4 UAT pack was not attached within the 5-day window in §7.2, so the gate auto-failed and the milestone payment is held. Root cause is 2.5 FTE diverted from wave 3 into CVE remediation. Revised gate date of 14 Aug agreed verbally with the client sponsor; change note pending signature.', 'Northwind Rail', NULL, 'Watch', 'Breach', 'open', 'D. Okafor', 'Re-gate 14 Aug', DATE '2026-08-14', 34000000, 'REVIEW GATE', 'client', 'control', TIMESTAMP '2026-07-26 16:40:00', 'Meridian gate monitor (seeded)'),
  ('jr-1152', 'RSK-1152', 'P2', 'warn', 'Utilisation above 100% for five consecutive weeks', 'Workday shows platform engineering at 112% with two leads flagged as attrition risk in the last engagement survey. Margin has moved from 18% plan to 11% actual. Two options modelled: absorb via change order £0.4m, or re-sequence wave 3 behind the CVE work. Recommendation goes to the QBR on 12 Aug.', 'Northwind Rail', NULL, 'New', 'Open · P2', 'open', 'P. Raman', 'Decision 12 Aug', DATE '2026-08-12', 40000000, 'RESOURCE PLAN', 'client', 'control', TIMESTAMP '2026-07-24 11:02:00', 'Meridian capacity control (seeded)'),
  ('jr-1138', 'RSK-1138', 'P1', 'crit', 'Call-off expires in 64 days with no renewal motion', 'No Salesforce opportunity exists against the DEFCON call-off expiring 30 Sep. CSAT has fallen from 7.8 to 6.1 and one of four contracted outcomes is on track. Escalated to the sector partner; recovery plan and re-compete decision required before 15 Aug or the account should be planned as a managed exit.', 'Solent Marine', NULL, 'Watch', 'Escalated', 'escalated', 'A. Lindqvist', 'Gate 15 Aug', DATE '2026-08-15', 190000000, 'START RENEWAL', 'journal', 'control', TIMESTAMP '2026-07-21 08:25:00', 'Meridian renewal control (seeded)'),
  ('jr-1121', 'RSK-1121', 'P2', 'warn', 'GxP validation re-run needed before staging patch', 'Any change to the ingest path triggers a 30-day change notice and a validation re-run under §8.1. Staging is not internet-facing so exposure is indirect; the patch is scheduled into the 02 Sep window rather than the emergency wave. Client quality lead has acknowledged in writing.', 'Kestrel Pharma', 'C-114', 'New', 'Open · P2', 'open', 'M. Chen', 'Window 02 Sep', DATE '2026-09-02', NULL, NULL, NULL, 'manual', TIMESTAMP '2026-07-18 14:55:00', 'M. Chen'),
  ('jr-1109', 'RSK-1109', 'CLOSED', 'good', 'Ticketing throughput benefit signed off at +18%', 'Benefit case in §3.4 was independently verified and signed by the client on 02 Jul at +18% against a +15% target. 1.8 FTE released back to wave 3. Closed with evidence attached; cited on page 3 of the Q3 QBR.', 'Northwind Rail', NULL, 'Open', 'Closed', 'closed', 'P. Raman', 'Verified 02 Jul', NULL, NULL, NULL, NULL, 'manual', TIMESTAMP '2026-07-15 10:10:00', 'P. Raman');

INSERT INTO audit.journal_entry_customer VALUES
  ('jr-1180', 'cust-nr'), ('jr-1180', 'cust-hh'), ('jr-1180', 'cust-kp'),
  ('jr-1164', 'cust-nr'),
  ('jr-1152', 'cust-nr'),
  ('jr-1138', 'cust-sm'),
  ('jr-1121', 'cust-kp'),
  ('jr-1109', 'cust-nr');

INSERT INTO audit.journal_entry_link VALUES
  ('jr-1180', 'CVE-2026-1180', 'crit'), ('jr-1180', '§6.3 ×2', 'warn'), ('jr-1180', 'Jira HAL-501', 'muted'), ('jr-1180', 'Cluster C-114', 'muted'),
  ('jr-1164', '§7.2 breach', 'crit'), ('jr-1164', 'Jira NWR-482', 'muted'), ('jr-1164', '£340k held', 'crit'), ('jr-1164', 'CO pending', 'warn'),
  ('jr-1152', 'Workday', 'muted'), ('jr-1152', 'margin 11%', 'crit'), ('jr-1152', 'CO-2026-11', 'good'),
  ('jr-1138', 'no opportunity', 'crit'), ('jr-1138', 'CSAT 6.1', 'crit'), ('jr-1138', '1/4 outcomes', 'crit'),
  ('jr-1121', '§8.1 notice', 'warn'), ('jr-1121', 'staging only', 'good'), ('jr-1121', '02 Sep window', 'muted'),
  ('jr-1109', '§3.4 met', 'good'), ('jr-1109', 'client-signed', 'good'), ('jr-1109', '+1.8 FTE', 'good');

-- Append-only movement history for the risks that have moved -----------------------
INSERT INTO audit.journal_movement VALUES
  ('jm-1164-1', 'jr-1164', 1, 'New',   'Watch',     'Gate evidence overdue flagged',                'Meridian gate monitor (seeded)', TIMESTAMP '2026-07-24 09:00:00'),
  ('jm-1164-2', 'jr-1164', 2, 'Watch', 'Breach',    '5-day §7.2 window closed with UAT pack missing','Meridian gate monitor (seeded)', TIMESTAMP '2026-07-26 16:40:00'),
  ('jm-1138-1', 'jr-1138', 1, 'New',   'Watch',     'Renewal inside notice window, no opportunity',  'Meridian renewal control (seeded)', TIMESTAMP '2026-07-18 09:00:00'),
  ('jm-1138-2', 'jr-1138', 2, 'Watch', 'Escalated', 'Escalated to sector partner; CSAT 7.8→6.1',     'A. Lindqvist', TIMESTAMP '2026-07-21 08:25:00'),
  ('jm-1109-1', 'jr-1109', 1, 'Open',  'Closed',    'Benefit signed by client at +18%',              'P. Raman', TIMESTAMP '2026-07-15 10:10:00');

-- A closed decision — demonstrates the raised→decided→verified loop ------------------
INSERT INTO audit.decision VALUES
  ('dec-1109', 'jr-1109', 'Accept verified benefit; release 1.8 FTE to wave 3',
   'Client signed the +18% benefit case; capacity returns to the gate-critical wave.',
   'P. Raman', TIMESTAMP '2026-07-15 10:20:00', DATE '2026-07-30', 'verified');

-- Milestone gates — FORWARD-dated, so the runway is a pre-mortem --------------------
INSERT INTO core.milestone VALUES
  ('ms-nr-1', 'eng-nr', 'cl-nr-72', 'Release 4 re-gate',        DATE '2026-08-14', 'uat_pack',            34000000, 'upcoming'),
  ('ms-nr-2', 'eng-nr', NULL,       'Wave 3 depot go-live',     DATE '2026-08-28', 'release_note',        20000000, 'upcoming'),
  ('ms-hh-1', 'eng-hh', 'cl-hh-72', 'Phase 2 acceptance',       DATE '2026-08-08', 'uat_pack',            34000000, 'upcoming'),
  ('ms-cb-1', 'eng-cb', NULL,       'Cutover wave 4',           DATE '2026-09-10', 'release_note',        NULL,     'upcoming'),
  ('ms-kp-1', 'eng-kp', NULL,       'Trial go-live batch 5',    DATE '2026-09-20', 'signed_benefit_case', NULL,     'upcoming');

-- Client-side stakeholders — sponsor status is a leading churn indicator -----------
INSERT INTO core.stakeholder VALUES
  ('st-nr-1', 'cust-nr', 'H. Blythe',   'Programme Director', TRUE,  'supportive', 'active',    TIMESTAMP '2026-07-22 00:00:00', 'salesforce', 'con-nr-1'),
  ('st-hh-1', 'cust-hh', 'Dr N. Osei',  'CIO',                TRUE,  'champion',   'active',    TIMESTAMP '2026-07-20 00:00:00', 'salesforce', 'con-hh-1'),
  ('st-cb-1', 'cust-cb', 'R. Tan',      'Head of Payments',   TRUE,  'supportive', 'active',    TIMESTAMP '2026-07-24 00:00:00', 'salesforce', 'con-cb-1'),
  ('st-sm-1', 'cust-sm', 'Cdr J. Vane', 'Programme Sponsor',  TRUE,  'detractor',  'departing', TIMESTAMP '2026-06-30 00:00:00', 'salesforce', 'con-sm-1'),
  ('st-kp-1', 'cust-kp', 'Dr L. Frei',  'Head of Data',       TRUE,  'neutral',    'new',       TIMESTAMP '2026-07-15 00:00:00', 'salesforce', 'con-kp-1'),
  ('st-vu-1', 'cust-vu', 'M. Idris',    'Operations Lead',    TRUE,  'supportive', 'active',    TIMESTAMP '2026-07-19 00:00:00', 'salesforce', 'con-vu-1');

-- CSAT as a measured time series (two points → trend), per engagement ---------------
INSERT INTO core.measurement VALUES
  ('m-nr-csat1', 'eng-nr', 'csat', 7.1, '7.1', TIMESTAMP '2026-03-01 00:00:00', TIMESTAMP '2026-04-01 00:00:00', 'salesforce', 'CSAT-Q1'),
  ('m-nr-csat2', 'eng-nr', 'csat', 7.4, '7.4', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2'),
  ('m-hh-csat1', 'eng-hh', 'csat', 7.6, '7.6', TIMESTAMP '2026-03-01 00:00:00', TIMESTAMP '2026-04-01 00:00:00', 'salesforce', 'CSAT-Q1'),
  ('m-hh-csat2', 'eng-hh', 'csat', 7.5, '7.5', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2'),
  ('m-cb-csat1', 'eng-cb', 'csat', 8.2, '8.2', TIMESTAMP '2026-03-01 00:00:00', TIMESTAMP '2026-04-01 00:00:00', 'salesforce', 'CSAT-Q1'),
  ('m-cb-csat2', 'eng-cb', 'csat', 8.3, '8.3', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2'),
  ('m-sm-csat1', 'eng-sm', 'csat', 7.8, '7.8', TIMESTAMP '2026-03-01 00:00:00', TIMESTAMP '2026-04-01 00:00:00', 'salesforce', 'CSAT-Q1'),
  ('m-sm-csat2', 'eng-sm', 'csat', 6.1, '6.1', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2'),
  ('m-kp-csat1', 'eng-kp', 'csat', 7.0, '7.0', TIMESTAMP '2026-03-01 00:00:00', TIMESTAMP '2026-04-01 00:00:00', 'salesforce', 'CSAT-Q1'),
  ('m-kp-csat2', 'eng-kp', 'csat', 6.8, '6.8', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2'),
  ('m-vu-csat1', 'eng-vu', 'csat', 7.3, '7.3', TIMESTAMP '2026-06-01 00:00:00', TIMESTAMP '2026-07-01 00:00:00', 'salesforce', 'CSAT-Q2');

-- Utilisation HISTORY for Northwind (makes the 5-week over-100% streak real) --------
INSERT INTO core.measurement VALUES
  ('m-nr-ut1', 'eng-nr', 'utilisation_pct', 104, '104%', TIMESTAMP '2026-07-14 00:00:00', TIMESTAMP '2026-07-21 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-nr-ut2', 'eng-nr', 'utilisation_pct', 102, '102%', TIMESTAMP '2026-07-07 00:00:00', TIMESTAMP '2026-07-14 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-nr-ut3', 'eng-nr', 'utilisation_pct', 101, '101%', TIMESTAMP '2026-06-30 00:00:00', TIMESTAMP '2026-07-07 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-nr-ut4', 'eng-nr', 'utilisation_pct', 101, '101%', TIMESTAMP '2026-06-23 00:00:00', TIMESTAMP '2026-06-30 00:00:00', 'workday', 'NWR-DELIV'),
  ('m-kp-ut1', 'eng-kp', 'utilisation_pct', 106, '106%', TIMESTAMP '2026-07-14 00:00:00', TIMESTAMP '2026-07-21 00:00:00', 'workday', 'KP-DELIV');

-- Staging provenance: representative raw records so source badges resolve to a real
-- staging row instead of dangling. Keyed to match measurement/artifact source_refs.
INSERT INTO staging.source_record VALUES
  ('sr-1', 'salesforce', 'Account',  '0015f000NR',   '{"Name":"Northwind Rail","Industry":"Transport"}', 'h1', TIMESTAMP '2026-07-28 09:08:00', 'batch-sf-1'),
  ('sr-2', 'salesforce', 'Contract', 'MSA-2023-041', '{"ACV":4200000,"RenewalDate":"2026-11-12"}',       'h2', TIMESTAMP '2026-07-28 09:08:00', 'batch-sf-1'),
  ('sr-3', 'workday',    'RaaS_util','NWR-DELIV',    '{"week":"2026-07-28","utilisation":103}',          'h3', TIMESTAMP '2026-07-28 07:14:00', 'batch-wd-1'),
  ('sr-4', 'jira',       'issue',    'NWR-401',      '{"key":"NWR-401","crash_free":99.1}',              'h4', TIMESTAMP '2026-07-28 09:00:00', 'batch-jira-1'),
  ('sr-5', 'jira',       'attachment','att-90211',   '{"issue":"NWR-482","filename":"release-note.pdf"}','h5', TIMESTAMP '2026-07-28 09:00:00', 'batch-jira-1'),
  ('sr-6', 'jsm',        'sla_cycle','HAL-SLA',      '{"metric":"availability","value":99.87}',          'h6', TIMESTAMP '2026-07-28 09:06:00', 'batch-jsm-1'),
  ('sr-7', 'confluence', 'page',     '55014',        '{"title":"Target architecture v3","version":3}',   'h7', TIMESTAMP '2026-07-28 08:20:00', 'batch-conf-1'),
  ('sr-8', 'gdrive',     'file',     '1xYzBenefitCase','{"name":"Benefit case signed","revision":"rev-14"}','h8', TIMESTAMP '2026-07-28 08:45:00', 'batch-gd-1');
