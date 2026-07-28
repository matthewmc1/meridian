.PHONY: db api web dev build clean

# Rebuild the lake from schema + dev fixtures (destructive to local file).
db:
	rm -f meridian.duckdb
	duckdb meridian.duckdb ".read db/schema.sql" ".read db/seed.sql"

api:
	cd backend && go build -o backend . && cd .. && ./backend/backend

web:
	cd frontend && npm run dev

build:
	cd backend && go build -o backend .
	cd frontend && npm run build

clean:
	rm -f meridian.duckdb backend/backend
	rm -rf frontend/dist
