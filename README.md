# Salary Management

[English Version](#part-1-english-version) | [Українська версія](#частина-2-українська-версія)

---

## Part 1: English Version

### 1. Overview & Tech Stack
- **Backend/Frontend:** Ruby on Rails, PostgreSQL, Tailwind CSS (`tailwindcss-rails`).
- **Desktop Shell:** Electron (cross-platform desktop wrapper).
- **Isolation & Safety:** Dedicated environment guards to prevent accidental data loss in production/development databases.

---

### 2. Styling (Tailwind CSS)
Tailwind CSS is compiled via the `tailwindcss-rails` gem, meaning `node`/`npm` installation is optional for basic Rails development. After modifying views, compile styles using:
```bash
bin/rails tailwindcss:build
```
In development mode, watch for changes automatically:
```bash
bin/rails tailwindcss:watch
```
*Commit compiled assets (`app/assets/builds/tailwind.css`) along with view changes so styles are available after `git clone`.*

---

### 3. Running via Docker
Requires Docker Desktop. Start the application with a single command:
```bash
docker compose up --build
```
- **App URL:** http://localhost:3000
- **PostgreSQL:** `127.0.0.1:5433:5432` (bound locally to prevent external exposure).

On first startup, the `web` container automatically runs `db:prepare` via `bin/docker-entrypoint`.

- Stop without losing data: `docker compose down`
- Completely reset database (removes data volume): `docker compose down -v`

---

### 4. Database Backup & Restore Safety
Backup scripts run via Docker Compose without requiring a local `psql` installation.

- **Create a backup:**
  ```bash
  bin/backup-db
  ```
- **Restore a database:**
  ```bash
  bin/restore-db backups/salary-management-dump.sql --yes
  ```
*Warning: `restore-db` deletes and recreates the target database. Always verify target database names to prevent data loss.*

---

### 5. Desktop Shell & Shortcuts
The application can run as a standalone desktop app via Electron.

#### Create Desktop Shortcut:
```bash
cd desktop
npm install
npm run shortcut
```
This automatically detects your OS and creates a launcher (`.command` on macOS, `.cmd` on Windows, `.desktop` on Linux).

---

### 6. Security & Environment Best Practices
1. **Credentials Management:** Never hardcode passwords or secrets. Use a local `.env` file in the project root (ignored by git).
2. **Database Protection:** Built-in Rake guards (`lib/tasks/protect_real_db.rake`) prevent destructive accidental execution on active development databases.
3. **Agent Permission Boundaries:** AI agents are restricted from modifying infrastructure configuration files (`config/database.yml`, `docker-compose.yml`, `bin/agent`) to ensure safe operations.

---
Testing Guide / Інструкція з запуску тестів

### Part 1: English Version

#### 1. Concept: Why Separate Test Databases?
Even though the project test suite (RSpec code) is identical for both human developers and AI agents, **the underlying test databases MUST be isolated**.

* **Developer Environment (Port 5433):** Runs on `salary_management_test`. RSpec automatically truncates/prepares this database during test runs without touching your development data.
* **AI Agent Environment (Port 5434):** Runs on `salary_management_agent_test`. When the AI agent tests code modifications or experimental migrations, it must be constrained to port `5434` to prevent altering the developer's test state or schema.

---

#### 2. Developer Test Execution (Real / Main Setup)

##### A. Inside Docker Container (Recommended)
This is the cleanest method as it uses the containerized environment matching production:
```bash
docker compose exec web bundle exec rspec
```

##### B. Locally on Host Machine (Without Docker)
Ensure the Docker Postgres container on port `5433` (or local Postgres) is running:
```bash
RAILS_ENV=test DB_PORT=5433 bundle exec rspec
```

---

#### 3. AI Agent Test Execution (Isolated Sandbox)

##### A. Inside the Agent Wrapper (`bin/agent`) — Recommended
When operating inside the `./bin/agent` wrapper session, the environment is sanitized via `env -i`, and connection variables point strictly to port `5434`. You or the agent can simply run:
```bash
bundle exec rspec
```

##### B. Explicitly from Host Machine against Agent Database
If you need to execute tests against the agent's sandbox database directly from your host terminal:
```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent_test DB_USERNAME=sm_agent DB_PASSWORD=agent_password bundle exec rspec
```

---

#### 4. Safety Checklist
- [x] Never run `bundle exec rspec` with `DB_PORT=5432` if you have system Postgres running locally.
- [x] Ensure `.env` is ignored by git so test execution parameters do not leak sensitive host keys.

---

## Частина 2: Українська версія

### 1. Огляд та технологічний стек
- **Бекенд/Фронтенд:** Ruby on Rails, PostgreSQL, Tailwind CSS (`tailwindcss-rails`).
- **Десктопна оболонка:** Electron (кросплатформна обгортка для запуску у вікні).
- **Ізоляція та безпека:** Вбудовані механізми захисту від випадкового знищення даних в основній базі.

---

### 2. Стилі (Tailwind CSS)
Tailwind CSS збирається гемом `tailwindcss-rails`, тому встановлювати `node`/`npm` для цього не обов'язково. Після зміни класів у в'юхах згенеруйте стилі:
```bash
bin/rails tailwindcss:build
```
У режимі розробки відстежуйте зміни автоматично:
```bash
bin/rails tailwindcss:watch
```
*Коммітьте змінений `app/assets/builds/tailwind.css` разом із в'юхами, щоб стилі працювали одразу після клонування репозиторію.*

---

### 3. Запуск у Docker
Потрібен запущений Docker Desktop. Усе піднімається однією командою:
```bash
docker compose up --build
```
- **Застосунок:** http://localhost:3000
- **PostgreSQL:** `127.0.0.1:5433:5432` (прив'язано локально для захисту від доступу із зовнішньої мережі).

При першому старті контейнер `web` автоматично виконує `db:prepare`.

- Зупинити без втрати даних: `docker compose down`
- Повністю скинути базу (видалить том): `docker compose down -v`

---

### 4. Безпека бекапів та відновлення БД
Скрипти працюють через Docker Compose.

- **Створити дамп:**
  ```bash
  bin/backup-db
  ```
- **Відновити базу:**
  ```bash
  bin/restore-db backups/salary-management-dump.sql --yes
  ```
*Увага: скрипт відновлення повністю очищає та перестворює цільову базу даних. Завжди перевіряйте назву бази перед запуском.*

---

### 5. Десктопна оболонка та ярлики
Застосунок можна запускати подвійним кліком через десктопний ярлик.

#### Створити ярлик на Робочому столі:
```bash
cd desktop
npm install
npm run shortcut
```
Команда автоматично визначає ОС і створює запускач (`.command` на macOS, `.cmd` на Windows, `.desktop` на Linux).

---

### 6. Безпека та правила ізоляції середовища
1. **Конфіденційні дані:** Ніколи не вписуйте паролі в код. Використовуйте локальний файл `.env` у корені проєкту (він захищений `.gitignore`).
2. **Захист від деструктивних команд:** Спеціальні Rake-захисти (`lib/tasks/protect_real_db.rake`) блокують випадкове очищення чи скидання робочої бази даних при помилковому запуску команд з хоста.
3. **Обмеження прав AI-агентів:** Правила безпеки забороняють агентам редагувати інфраструктурні конфігурації (`config/database.yml`, `docker-compose.yml`, `bin/agent`), що гарантує незмінність захисних контурів.




### Частина 2: Українська версія

#### 1. Концепція: Чому тестові бази даних мають бути розділені?
Хоча сам набір тестів (код RSpec) є єдиним для всього проєкту, **бази даних для запуску тестів розробником та AI-агентом ПОВИННІ бути ізольованими**.

* **Середовище розробника (Порт 5433):** Працює з базою `salary_management_test`. Під час запуску RSpec Rails автоматично очищує та підготовлює цю базу, не чіпаючи ваші робочі дані розробки.
* **Середовище AI-агента (Порт 5434):** Працює з базою `salary_management_agent_test`. Якщо AI-агент перевіряє свої експерименти з кодом або нові міграції, він повинен бути обмежений портом `5434`, щоб не пошкодити схему чи стан тестів розробника.

---

#### 2. Запуск тестів розробником (Основна база)

##### А. Усередині контейнера Docker (Рекомендовано)
Найбільш ізольований та надійний спосіб розробки:
```bash
docker compose exec web bundle exec rspec
```

##### Б. Локально на хості (Без Docker)
Переконайся, що контейнер PostgreSQL на порту `5433` (або локальний Postgres) запущений:
```bash
RAILS_ENV=test DB_PORT=5433 bundle exec rspec
```

---

#### 3. Запуск тестів AI-агентом (Ізольована пісочниця)

##### А. Усередині сесії обгортки (`bin/agent`) — Рекомендовано
Усередині сеансу, запущеного через `./bin/agent`, середовище автоматично очищено через `env -i`, а змінні підключення вказують на порт `5434`. Ви або агент просто виконуєте:
```bash
bundle exec rspec
```

##### Б. Явно з термінала хоста для бази агента
Якщо потрібно виконати тести для бази агента напряму з вашого термінала:
```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent_test DB_USERNAME=sm_agent DB_PASSWORD=agent_password bundle exec rspec
```

---

#### 4. Чек-лист безпеки
- [x] Ніколи не запускайте `bundle exec rspec` з `DB_PORT=5432`, якщо у вас локально працює системний Postgres.
- [x] Переконайтеся, що файл `.env` заігнорований у git, щоб тестові параметри не компрометували секрети.
