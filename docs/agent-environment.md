# AI Agent Isolated Environment Guide / Інструкція з ізольованого середовища AI-агента

---

## Part 1: English Version

### 1. Purpose & Motivation
AI agents (like `OpenCode`) execute terminal commands on your host system with your user permissions. Unrestricted agent execution of database migrations, schema reloads, or seeds can accidentally destroy or corrupt real employee data.

To mitigate this, the agent operates inside a completely isolated database environment initialized with fake seed data (`Faker`), leaving the real development database safe and untouched.

---

### 2. Architecture & Isolation Topology

| Port | Container / Instance | Database Name | Purpose | Agent Access |
|------|----------------------|---------------|---------|--------------|
| `5433` | `db` (Docker) | `salary_management_development` | REAL Employee Data | **BLOCKED** (by convention & env) |
| `5434` | `agent_db` (Docker) | `salary_management_agent` | Fake Seed Data | **ALLOWED** (Working sandbox) |
| `5432` | Local Postgres (Host) | Various | System / Other Projects | **UNUSED** |

*Note: All container ports are explicitly bound to `127.0.0.1` to block external network access.*

#### Multi-Layer Defense System:
1. **Dynamic Environment Configuration:** `config/database.yml` reads parameters purely via `ENV.fetch` with safe local defaults (`host: localhost`, `port: 5433`).
2. **Isolated Database Instance:** `agent_db` runs on port `5434` with isolated storage volume `salary_management_agent_db_data` and dedicated credentials.
3. **Execution Guards:** `db/seeds.rb` contains an explicit database name assertion (`salary_management_agent`). Destructive Rake tasks (`db:drop`, `db:schema:load`) are blocked for non-agent databases via `lib/tasks/protect_real_db.rake`.
4. **Environment Sanitization (`bin/agent`):** Uses `env -i` to strip host environment variables (AWS keys, SSH configs, personal secrets) before launching the agent process.

---

### 3. Safety Boundaries & Threat Model

- **Credentials Management:** Passwords and environment variables are loaded via `.env` (ignored by git).
- **OpenCode Permissions (`.opencode/`):** Strict permission rules (`edit: deny`) prevent the agent from modifying infrastructure files (`config/database.yml`, `docker-compose.yml`, `bin/agent`, Rake guards).
- **System Privileges:** The agent process runs under your macOS/Linux user session and holds matching file system permissions.

---

### 4. Setup & Daily Workflow

#### Initial Setup:
```bash
# 1. Grant execution rights
chmod +x bin/agent bin/agent-db

# 2. Boot container, load schema, and seed fake data
bin/agent-db setup

# 3. Verify target database connection
bin/agent-db check
```

#### Daily Usage:
Always launch the agent using the wrapper script:
```bash
bin/agent
```

---

### 5. Management Commands (`bin/agent-db`)

| Command | Action Description |
|---------|--------------------|
| `bin/agent-db start` | Starts `agent_db` container on port `5434`. |
| `bin/agent-db setup` | Runs `start` + `db:create`, `db:schema:load`, `db:seed`. |
| `bin/agent-db reset` | Re-applies schema and regenerates fake seed data. |
| `bin/agent-db check` | Displays current active DB name and record counts. |
| `bin/agent-db console` | Opens Rails console inside the agent environment. |
| `bin/agent-db stop` | Stops container without purging stored volume data. |
| `bin/agent-db nuke` | Completely removes container and purges data volume. |

---
---

## Частина 2: Українська версія

### 1. Призначення та мотивація
AI-агент (наприклад, `OpenCode`) виконує консольні команди в операційній системі з правами вашого користувача. Пряме виконання агентом міграцій чи скидання схем може випадково знищити реальні дані співробітників у робочій базі.

Щоб усунути цей ризик, агент працює у повністю ізольованому середовищі з фейковими даними (`Faker`), залишаючи робочу базу розробки недоторканою.

---

### 2. Архітектура та топологія ізоляції

| Порт | Контейнер / Процес | Назва бази даних | Призначення | Доступ агента |
|------|--------------------|------------------|-------------|---------------|
| `5433` | `db` (Docker) | `salary_management_development` | РЕАЛЬНІ дані | **ЗАБОРОНЕНО** |
| `5434` | `agent_db` (Docker) | `salary_management_agent` | Фейкові дані | **ДОЗВОЛЕНО** (Пісочниця) |
| `5432` | Локальний Postgres | Різні | Інші проєкти | **НЕ ВИКОРИСТОВУЄТЬСЯ** |

*Примітка: Усі порти прив'язані до `127.0.0.1`, що унеможливлює доступ із зовнішньої мережі.*

#### Чотири рівні захисту:
1. **Динамічний ENV-конфіг:** `config/database.yml` зчитує всі параметри підключення через `ENV.fetch` із безпечними замовчуваними значеннями (`host: localhost`, `port: 5433`).
2. **Окремий контейнер:** `agent_db` працює на порту `5434` із власним томом даних та ізольованими обліковими даними.
3. **Захисні запобіжники (Rake Guards):** `db/seeds.rb` дозволяє запуск лише на базі `salary_management_agent`. Rake-таск `protect_real_db.rake` блокує деструктивні команди для робочих баз розробки.
4. **Очищення середовища (`bin/agent`):** Скрипт запускається через `env -i`, видаляючи системні змінні оточення (паролі, ключі, токени) перед стартом агента.

---

### 3. Межі захисту та аналіз ризиків

- **Конфіденційні дані:** Усі паролі та локальні налаштування зберігаються у файлі `.env` (заігнорований у git).
- **Обмеження `.opencode/`:** Жорсткі правила прав (`edit: deny`) блокують можливість агента редагувати інфраструктурні файли (`config/database.yml`, `docker-compose.yml`, `bin/agent`, Rake-захист).
- **Системні права:** Агент працює від імені вашого користувача в macOS/Linux і має аналогічні права на читання та запис файлів.

---

### 4. Перший запуск та щоденна робота

#### Налаштування середовища:
```bash
# 1. Надаємо права на виконання
chmod +x bin/agent bin/agent-db

# 2. Створюємо контейнер, базу, схему та генеруємо фейкові дані
bin/agent-db setup

# 3. Перевіряємо активну базу даних
bin/agent-db check
```

#### Щоденний запуск:
Запускайте AI-агента виключно через скрипт-обгортку:
```bash
bin/agent
```

---

### 5. Команди управління (`bin/agent-db`)

| Command | Опис дії |
|---------|----------|
| `bin/agent-db start` | Запускає контейнер `agent_db` на порту `5434`. |
| `bin/agent-db setup` | Створює контейнер, базу даних, завантажує схему та сіди. |
| `bin/agent-db reset` | Перестворює схему та генерує новий набір фейкових даних. |
| `bin/agent-db check` | Виводить назву активної бази та кількість записів у ній. |
| `bin/agent-db console` | Відкриває Rails-консоль у середовищі агента. |
| `bin/agent-db stop` | Зупиняє контейнер без видалення накопичених даних. |
| `bin/agent-db nuke` | Повністю видаляє контейнер та том із даними агента. |
