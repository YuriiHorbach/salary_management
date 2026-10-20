# AI Agent Isolated Environment Setup & Usage Guide

This document contains a full overview of the architecture, setup process, daily workflow, and safety rules for working with an AI agent (e.g., `OpenCode`) in a safe, isolated test environment.

---

## Part 1: English Version

### 1. How Isolation Works (Architecture)

To allow the AI agent to run safely, a three-tier protection strategy prevents accidental modifications or data loss in the main development database (`development`):

```
+------------------------------------------------------------------------------+
|                                   HOST                                       |
|                                                                              |
|  Main Environment (Port 5433/5432)         | Agent Environment (Port 5434)   |
|  ----------------------------------------- | ------------------------------  |
|  - DB: salary_management_development       | - DB: salary_management_agent   |
|  - Real Employee Data (CSV)                | - Fake Seed Data (Faker)        |
|  - Users: Dev / DBeaver                    | - Isolated script: bin/agent    |
+------------------------------------------------------------------------------+
```

#### Key Components:

1. **Dynamic `config/database.yml`**:
   * All database parameters (Host, Port, DB Name, Credentials) are loaded via `ENV.fetch`, allowing dynamic configuration without changing source code.

2. **Dedicated Docker Container (`agent_db`)**:
   * Runs on a dedicated port `5434` with its own `salary_management_agent` database and `sm_agent` database user.

3. **`db/seeds.rb` Safety Guard**:
   * Contains an explicit DB name check. Wiping tables or loading seed data is restricted strictly to `salary_management_agent`.

4. **Launcher Script `bin/agent`**:
   * Uses `env -i` to wipe all existing environment variables (passwords, tokens) and explicitly sets variables only for the agent database.

---

### 2. Zero-to-Hero Setup Guide

#### Step 1: Start the isolated Docker container
```bash
docker compose --profile agent up -d --wait agent_db
```

#### Step 2: Create the agent database
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:create
```

#### Step 3: Load schema and populate fake seeds
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:schema:load db:seed
```

---

### 3. Daily Workflow: Working with the Agent

To start working with the AI agent in the isolated environment:

#### Launch Command:
```bash
./bin/agent
```

#### What happens automatically:
- Verifies and starts `agent_db` on port `5434`.
- Cleans system environment variables for security (`env -i`).
- Passes connection credentials for `salary_management_agent`.
- Starts the agent process (e.g., `opencode`).

---

### 4. Dos and Don'ts (Safety Rules)

#### ✅ What YOU CAN DO:
- Ask the agent to write migrations, change models, controllers, services, or RSpec tests.
- Wipe and re-seed the agent database on port `5434` at any time.
- Execute RSpec tests within the agent environment.

#### ❌ What YOU MUST NOT DO:
1. **Do not run `bin/rails db:seed` or `db:schema:load` without specifying `DB_PORT=5434`**:
   * *Why:* Rails will default to `salary_management_development` (port 5433/5432) and wipe real employee data.
2. **Do not hardcode port numbers in `config/database.yml`**:
   * *Why:* Always keep `ENV.fetch` to ensure dynamic environment switching works properly.
3. **Do not launch `opencode` directly from your regular terminal**:
   * *Why:* Without `./bin/agent`, the agent gets access to your local development database and system credentials.
4. **Do not remove the safety guard in `db/seeds.rb`**:
   * *Why:* The line `unless ActiveRecord::Base.connection_db_config.database == 'salary_management_agent'` prevents accidental wipes of real data.

---

### 5. Quick Recovery from Corruption

If the AI agent corrupts its database during experiments:
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:schema:load db:seed
```

---
---

## Частина 2: Українська версія

### 1. Як влаштована ізоляція (Архітектура)

Для безпечної роботи AI-агента створено трирівневий захист, який запобігає випадковій модифікації або видаленню даних з основної бази розробки (`development`):

```
+------------------------------------------------------------------------------+
|                                   HOST                                       |
|                                                                              |
|  Основне середовище (Port 5433/5432)        | Середовище Агента (Port 5434)   |
|  ------------------------------------------ | ------------------------------ |
|  - DB: salary_management_development        | - DB: salary_management_agent  |
|  - Реальні дані співробітників (CSV)        | - Фейкові дані (Faker)         |
|  - Користувачі: Dev / DBeaver               | - Ізольований скрипт: bin/agent|
+------------------------------------------------------------------------------+
```

#### Ключові компоненти:

1. **Динамічний `config/database.yml`**:
   * Усі параметри підключення (Host, Port, DB Name, Credentials) зчитуються через `ENV.fetch`, що дозволяє гнучко переключати конфігурацію без зміни коду.

2. **Окремий Docker-контейнер (`agent_db`)**:
   * Запущений на окремому порту `5434` із власною базою `salary_management_agent` та користувачем `sm_agent`.

3. **Запобіжник у `db/seeds.rb`**:
   * У файл сидів вбудовано перевірку назви бази. Наповнення та деструктивні очищення дозволені виключно для `salary_management_agent`.

4. **Скрипт запуску `bin/agent`**:
   * Використовує команду `env -i`, яка повністю очищає змінні середовища термінала від чутливих даних і передає лише реквізити бази агента.

---

### 2. Покрокова інструкція запуску середовища з нуля

#### Крок 1: Запуск ізольованого Docker-контейнера
```bash
docker compose --profile agent up -d --wait agent_db
```

#### Крок 2: Створення бази даних агента
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:create
```

#### Крок 3: Наповнення схеми та генерація фейкових даних
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:schema:load db:seed
```

---

### 3. Щоденні дії: Як працювати з агентом

Щоб розпочати роботу з AI-агентом в ізольованому середовищі:

#### Команда запуску:
```bash
./bin/agent
```

#### Що робить цей скрипт автоматично:
- Перевіряє та піднімає контейнер `agent_db` на порту `5434`.
- Ізолює процес від системних змінних оточення (`env -i`).
- Передає реквізити бази `salary_management_agent`.
- Стартує процес агента (наприклад, `opencode`).

---

### 4. Застереження та правила безпеки

#### ✅ Що МОЖНА робити:
- Вільно віддавати агенту завдання на створення міграцій, зміну моделей, контролерів, сервісів або тестів.
- Перезапускати та очищати базу агента через запуск `db:seed` на порту `5434` у будь-який момент.
- Запускати RSpec-тести у середовищі агента.

#### ❌ Що КАТЕГОРИЧНО ЗАБОРОНЕНО робити:
1. **Не запускайте `bin/rails db:seed` або `db:schema:load` без вказування `DB_PORT=5434`**:
   * *Чому:* За замовчуванням Rails підключиться до основної бази (`salary_management_development`) і ви можете випадково видалити реальні імпортовані дані.
2. **Не редагуйте `config/database.yml` захардкодженими портами**:
   * *Чому:* Завжди використовуйте `ENV.fetch`, щоб зберігати можливість динамічного переключення між конфігураціями.
3. **Не запускайте `opencode` напряму з термінала**:
   * *Чому:* Без використання `./bin/agent` AI-агент отримає доступ до вашої робочої бази та всіх системних змінних оточення.
4. **Не видаляйте запобіжник у `db/seeds.rb`**:
   * *Чому:* Рядок `unless ActiveRecord::Base.connection_db_config.database == 'salary_management_agent'` гарантує захист від випадкового видалення робочих даних.

---

### 5. Відновлення бази агента у разі збою

Якщо AI-агент пошкодив дані в агентській базі під час експериментів:
```bash
env DB_HOST=localhost DB_PORT=5434 DB_NAME=salary_management_agent \
    DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
    bin/rails db:schema:load db:seed
```