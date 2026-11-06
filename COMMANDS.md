# Commands

linkding is a bookmark manager: a Django app (Python) with a small esbuild frontend, on SQLite (no database server to start).
Needs Python 3.12–3.14 (3.15 has no `psycopg-binary` build yet) and Node. `requirements.txt` + `requirements-dev.txt` are the same versions as `uv.lock`, so `uv` is optional.

## Setup

```
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt     # with uv instead: uv sync
mkdir -p data/assets data/favicons data/previews
python manage.py migrate
npm install
npm run build                                               # frontend bundle and themes
python manage.py createsuperuser --username admin --email a@example.com
```

## Run

```
python manage.py runserver 127.0.0.1:8000                   # http://127.0.0.1:8000
npm run dev                                                 # optional, in another terminal: rebuilds the frontend on change
```
The dev settings (`bookmarks.settings.dev`) are used by default. A fresh start: stop the server, `rm -rf data`, then run the setup's
`mkdir`, `migrate` and `createsuperuser` lines again.

## Checks

```
ruff check bookmarks                                        # lint
ruff format --check bookmarks                               # Python format
djlint bookmarks/templates --check --quiet                  # template format
npx prettier --check bookmarks/frontend bookmarks/styles    # JS / CSS format
pytest -n auto                                              # unit tests
```

## End-to-end tests (Playwright, Chromium)

```
export PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers            # if the Chromium is pre-installed there; otherwise: playwright install chromium
npm run build && python manage.py collectstatic --no-input
pytest bookmarks/tests_e2e -n auto -o "python_files=e2e_test_*.py"
```
Playwright is pinned to 1.58.0 (Chromium 1208). The tests start their own server.
