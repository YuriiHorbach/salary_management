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
