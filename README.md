# Salary Management

A Rails application for managing employees, departments, positions, salaries, vacations, sick leave, taxes, and payroll reports. The UI is available in English, Ukrainian, and German (English is the default); developer documentation is in English.

**Contents:** [Features](#features) · [Tech stack](#tech-stack) · [Requirements](#requirements) · [Quick start](#quick-start-with-docker) · [Local development](#local-development) · [Environment variables](#environment-variables) · [Testing](#testing) · [Performance baseline](#performance-baseline) · [Localization](#localization) · [Tailwind](#tailwind-css) · [Desktop app](#desktop-app) · [Docs](#documentation) · [Security](#security) · [Contributing](#contributing)

## Features

- Employee records with tax settings, account books, and territory assignments.
- Departments, positions, and employee-position assignments.
- Salary, vacation, and sick-day records with automatic tax calculation.
- Monthly income aggregates in `employee_period_incomes`.
- Summary and detailed payroll reports.
- Historical CSV import for previously calculated payroll data.
- Per-user working month used as the default period for new records.
- Search, filtering, sorting, and pagination.
- Multilingual UI (English, Ukrainian, German) with a navbar language switcher and a configurable default language.

## Tech stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.4.12 |
| Framework | Rails 8.0 |
| Database | PostgreSQL 16 |
| Frontend | Hotwire (Turbo), Stimulus, Tailwind CSS |
| Authentication | Devise |
| Search and pagination | Ransack, Pagy |
| Money handling | money-rails |
| Desktop shell | Electron |

## Requirements

- Ruby 3.4.12 and Bundler
- PostgreSQL 16, local or via Docker
- Docker Desktop (recommended)
- Node.js 22.12+ only for the Electron desktop shell

## Quick start with Docker

```bash
docker compose up --build
```

- Application: <http://localhost:3000>
- PostgreSQL: `127.0.0.1:5433` (bound to localhost only)

The `web` container runs `db:prepare` automatically on first startup. Compose sets `DB_HOST=db` **and** `DB_PORT=5432` in `docker-compose.yml` (PostgreSQL listens on `5432` inside the compose network; `5433` is only the host mapping `127.0.0.1:5433:5432`), so no `.env` change is needed for Docker — the compose environment takes precedence over `.env` values. The base compose file keeps a plain `depends_on: db` (`service_started`). The Electron desktop shell additionally loads `docker-compose.desktop.yml`, which adds `pg_isready` and `/up` healthchecks and makes `web` wait for `condition: service_healthy`, so `db:prepare` cannot race a still-starting PostgreSQL on slower machines such as Windows.

```bash
docker compose down            # stop, keep data
docker compose down -v         # stop and delete the database volume
docker compose exec web bash   # shell inside the web container
```

## Local development

```bash
bundle install
bin/rails db:prepare
bin/dev
```

`bin/dev` starts Rails on port `3000` and the Tailwind watcher from `Procfile.dev`. If PostgreSQL runs in Docker, start only the database first and point the host process at its published port:

```bash
docker compose up -d db
DB_HOST=localhost DB_PORT=5433 bin/dev
```

## Environment variables

Database settings are read from environment variables. Do not commit real credentials.

| Variable | Default | Purpose |
|---|---|---|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5433` | PostgreSQL port |
| `DB_USERNAME` | `postgres` | Database user |
| `DB_PASSWORD` | `password` | Database password |
| `DB_NAME` | `salary_management_development` | Development database |
| `TEST_DB_NAME` | `my_app_test` | Test database; set explicitly |
| `RAILS_MAX_THREADS` | `5` | Connection pool size |
| `SALARY_MANAGEMENT_DATABASE_PASSWORD` | empty | Production database password |
| `RAILS_MASTER_KEY` | — | Production credentials key |

Store local values in `.env` (ignored by Git). Use `DB_PORT=5432` when Rails runs inside Docker and `DB_PORT=5433` when it runs on the host against the published database port.

## Database backup and restore

Backup scripts run through Docker Compose and do not require a local `psql`.

```bash
bin/backup-db
bin/restore-db backups/salary-management-dump.sql --yes
```

`bin/backup-db` writes the SQL dump plus a `<dump>.manifest` file with the exact
row count of every `public` table. `bin/restore-db` restores the dump and, when
the manifest is present, compares every table and row count before finishing.
This catches truncated dumps and restores aimed at the wrong database.

The scripts choose the Compose service from the environment:

| Environment | Service | Database |
|---|---|---|
| `DB_PORT=5433` (default) | `db` | `salary_management_development` |
| `DB_PORT=5434` or `DB_NAME=salary_management_agent` | `agent_db` | `salary_management_agent` |

Override the service explicitly with `DB_SERVICE=db` or `DB_SERVICE=agent_db`.
The scripts also honour `DB_USERNAME` (or `DB_USER`).

Restoring an agent database into a throw-away database for verification:

```bash
DB_PORT=5434 DB_NAME=salary_management_agent bin/backup-db /tmp/agent.sql
DB_SERVICE=agent_db DB_NAME=salary_management_agent_restore_check \
  bin/restore-db /tmp/agent.sql --yes
```

Migrations are **not** applied automatically after a restore, because data
migrations can merge or delete rows (for example, duplicate salaries). The dump
is restored exactly as-is. If the application code is newer than the dump, run
migrations explicitly:

```bash
bin/restore-db backups/salary-management-dump.sql --yes --migrate
```

> **Warning:** `restore-db` deletes and recreates the target database. Verify the database name and `DB_SERVICE` first.

## Testing

Tests must run against an isolated database. From the host, never point tests at the system PostgreSQL on port `5432`.

### System Tests (Capybara / Chrome)
Since containerized environments (like Docker) may lack a graphical browser, system tests should be handled strategically:
- **Do not delete them:** Keep them as a vital part of your regression suite.
- **Where to run them:** Execute them on your local host or in CI pipelines where Chrome and ChromeDriver are installed.
- **Quick local feedback loop:** For faster iterations during development, temporarily exclude system specs:
  ```bash
  bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"

**Developer environment** — Docker is recommended:

```bash
docker compose exec -e TEST_DB_NAME=salary_management_test web bundle exec rspec
```

From the host, using the developer test database on port `5433`:

```bash
RAILS_ENV=test DB_PORT=5433 TEST_DB_NAME=salary_management_test bundle exec rspec
```

**AI agent environment** — launch through the wrapper:

```bash
bin/agent
TEST_DB_NAME=salary_management_agent_test bundle exec rspec
```

Or run explicitly against the agent database on port `5434`:

```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 \
TEST_DB_NAME=salary_management_agent_test \
DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rspec
```

See [docs/agent-environment.md](docs/agent-environment.md) for isolation details and [docs/task-specs-guide.md](docs/task-specs-guide.md) for spec-writing patterns.

## Performance baseline

The scale seed and benchmark tasks are restricted to isolated agent databases. They abort unless the connected database name ends with `_agent`.

```bash
RAILS_ENV=development DB_HOST=localhost DB_PORT=5434 \
DB_NAME=salary_management_agent DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rake agent:seed_scale SCALE=20
```

`agent:seed_scale` creates `60 * SCALE` synthetic employees (default `20`, i.e. 1,200) with 12 months of salaries, vacations, sick days, and `employee_period_incomes`. Re-running it is idempotent by `id_code`.

```bash
RAILS_ENV=development DB_HOST=localhost DB_PORT=5434 \
DB_NAME=salary_management_agent DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rake agent:benchmark
```

`agent:benchmark` records wall-clock time and uncached SQL query counts for the detailed report, summary report, employee search, and detailed CSV export, then appends the result to `docs/performance-baseline.md`. Never point these tasks at ports `5433` or `5432`.

## Localization

The application ships with English (`en`), Ukrainian (`uk`), and German (`de`) locales. English is the initial default and the fallback for missing translations.

- Translation files live in `config/locales/en.yml`, `uk.yml`, and `de.yml`.
- Administrators can change the application default under **Settings → Default language** (`/settings/application_setting/edit`). It is stored in the `application_settings` table.
- Users switch languages from the navbar, which preserves the current path and query string and adds `?locale=uk` (or `de`).
- Controllers expose the selected locale through `ApplicationController#set_locale`; invalid values fall back to the configured default locale.
- Report column headers, CSV exports, validation errors, flash messages, and mailers are all translated.
- When adding a new locale, update `config.i18n.available_locales` in `config/application.rb` and add the matching YAML file and navbar label under `locales`.

## Tailwind CSS

```bash
bin/rails tailwindcss:build   # build once
bin/rails tailwindcss:watch   # rebuild on changes
```

Commit `app/assets/builds/tailwind.css` with view changes so styles work after cloning.

## Desktop app

```bash
cd desktop
npm install
npm run shortcut          # create a desktop shortcut
npm run shortcut:remove   # remove it
npm run check             # syntax-check the Electron shell
npm test                  # unit tests for the startup helpers
```

The script creates `.command` on macOS, `.cmd` on Windows, and `.desktop` on Linux.

The Electron shell performs a preflight before it opens a window:

1. Verifies that the Docker CLI exists and the daemon responds. If Docker Desktop is installed but not running, the shell starts it and waits up to two minutes.
2. Checks that host ports `3000` (Rails) and `5433` (PostgreSQL) are free.
3. Stops containers that belong to this project but were created under an older compose project name. This is a one-time cleanup after a folder rename or a `COMPOSE_PROJECT_NAME` change; on normal launches, containers from the current Compose project are left running.
4. Shows the owning process/PID or container name for any other port conflict and asks the user to free the port. **Unknown processes are never killed automatically** — they may belong to another application or to Windows itself.
5. Runs `docker compose -f docker-compose.yml -f docker-compose.desktop.yml up -d --wait`, so PostgreSQL reports healthy before Rails runs `db:prepare`. `docker compose up` reuses existing containers and does **not** rebuild the image unless the image is missing; there is no `--build` flag.
6. Opens the window only after `GET http://127.0.0.1:3000/up` returns `200`. The `/up` endpoint checks a real `SELECT 1`, so Rails and PostgreSQL must both be usable.

`docker-compose.desktop.yml` adds the readiness healthchecks used by `--wait`; the regular `docker compose up` workflow is unaffected. The first desktop launch after pulling this change may recreate the `db` and `web` containers to apply the healthchecks — the `salary_management_db_data` volume is preserved.

If a port stays occupied after the owner is gone, Windows may have reserved it (WinNAT/Hyper-V):

```bat
netsh interface ipv4 show excludedportrange protocol=tcp
```

Startup failures write `docker compose ps` and the last 80 lines of `web`/`db` logs to the Electron logs directory (the error dialog shows the exact file path).

## Domain notes

- **Tax aggregates:** income taxes are calculated once per employee, month, and income type and stored in `employee_period_incomes`. Rebuild them with `bin/rails incomes:recalculate` (idempotent).
- **Historical import:** `/historical_imports/new` imports previously calculated payroll rows and recalculates affected monthly aggregates. A CSV template is available on the page.
- **Positions:** selecting a position on a department page scopes employees, salaries, and totals to that position. Each employee can receive a separate salary per position.
- **Working month:** users select a current working month on the home page; it is the default period for new salaries, vacations, and sick days.

## Project structure

```text
app/controllers/  request handling
app/models/       domain models and validations
app/queries/      report and filtering queries
app/services/     business logic and tax calculations
app/views/        Hotwire and Tailwind templates
config/           configuration and routes
db/               migrations, schema, and seeds
desktop/          Electron shell
docs/             developer guides
spec/             RSpec suite
bin/              development and operations scripts
```

## Documentation

- [AI agent environment](docs/agent-environment.md)
- [Task specs creation guide](docs/task-specs-guide.md)

## Security

- Keep secrets in `.env` or Rails credentials; never commit them.
- Do not commit `config/master.key`, `.env`, or database dumps.
- Rake guards in `lib/tasks/protect_real_db.rake` block destructive commands against development databases.
- AI agents must not edit `config/database.yml`, `docker-compose.yml`, or `bin/agent`.
- Run host-side tests only on isolated ports: `5433` for developers, `5434` for agents.

## Contributing

1. Create a feature branch.
2. Write or update specs before implementation.
3. Run focused specs, the full suite, and RuboCop on changed Ruby files.
4. Update documentation when behavior, configuration, or workflows change.
5. Open a pull request with a clear summary and test results.
