"use strict"

const { app, BrowserWindow, dialog, Menu, shell } = require("electron")
const { spawn, spawnSync } = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")

const {
  classifyPortOwner,
  composeProjectFromConfig,
  defaultComposeProjectName,
  dockerDesktopCandidates,
  fileExists,
  isAppUrl,
  isPortFree,
  parseDockerPs,
  parseLsof,
  parseNetstat,
  parsePidFile,
  parseSs,
  parseTasklist,
  shouldRemovePidFile,
  waitForApp,
  waitForCondition,
} = require("./lib")

const PROJECT_ROOT = path.resolve(__dirname, "..")
const APP_URL = "http://127.0.0.1:3000"
const HEALTH_URL = `${APP_URL}/up`
const DATABASE_NAME = "salary_management_development"

const COMPOSE_ARGS = ["-f", "docker-compose.yml", "-f", "docker-compose.desktop.yml"]
const PORTS = [
  { port: 3000, label: "Rails" },
  { port: 5433, label: "PostgreSQL" },
]
const MAX_PORT_ATTEMPTS = 6
const PID_FILE = path.join(PROJECT_ROOT, "tmp", "pids", "server.pid")

let mainWindow = null
let splashWindow = null

/**
 * Runs the Docker CLI synchronously from the project root.
 *
 * @param {string[]} args docker arguments
 * @param {object} [options] spawnSync overrides
 * @returns {import("node:child_process").SpawnSyncReturns<string>}
 */
function docker(args, options = {}) {
  return spawnSync("docker", args, {
    cwd: PROJECT_ROOT,
    encoding: "utf8",
    timeout: 20_000,
    windowsHide: true,
    ...options,
  })
}

/**
 * Checks whether the Docker daemon is reachable.
 *
 * @returns {boolean}
 */
function isDockerRunning() {
  const result = docker(["info"], { timeout: 15_000 })
  return !result.error && result.status === 0
}

/**
 * Starts Docker Desktop when the daemon is not running yet.
 *
 * @returns {boolean} true when a start command was launched
 */
function startDockerDesktop() {
  for (const candidate of dockerDesktopCandidates(process.platform, process.env)) {
    if (process.platform === "win32" && !fileExists(candidate.command)) continue

    try {
      const child = spawn(candidate.command, candidate.args, {
        detached: true,
        stdio: "ignore",
        windowsHide: true,
      })
      child.on("error", () => {})
      child.unref()
      return true
    } catch {
      // Try the next known installation path.
    }
  }

  return false
}

/**
 * Verifies the Docker CLI and waits for the daemon, starting Docker Desktop if needed.
 *
 * @returns {Promise<void>}
 */
async function ensureDocker() {
  const version = docker(["--version"], { timeout: 10_000 })

  if (version.error && version.error.code === "ENOENT") {
    throw new Error(
      "Не знайдено Docker CLI. Встанови Docker Desktop і запусти застосунок знову."
    )
  }

  if (version.error || version.status !== 0) {
    const output = [version.stderr, version.stdout].filter(Boolean).join(" ").trim()
    throw new Error(`Docker CLI не відповідає${output ? `: ${output}` : "."}`)
  }

  if (isDockerRunning()) return

  setSplashMessage("Запускаю Docker Desktop…", "Це може зайняти до двох хвилин")

  if (!startDockerDesktop()) {
    throw new Error(
      "Docker Desktop не запущено. Відкрий його вручну, дочекайся повного старту і спробуй знову."
    )
  }

  await waitForCondition(isDockerRunning, {
    timeout: 120_000,
    interval: 2_000,
    message:
      "Docker Desktop не став доступним за 2 хвилини. Перевір, чи він запускається без помилок.",
  })
}

/**
 * Resolves the Compose project name used by the desktop shell.
 *
 * The raw config output may contain interpolated environment values, so only
 * the project name is kept.
 *
 * @returns {string}
 */
function resolveComposeProject() {
  const fallback = process.env.COMPOSE_PROJECT_NAME || defaultComposeProjectName(PROJECT_ROOT)
  const result = docker(["compose", ...COMPOSE_ARGS, "config", "--format", "json"], { timeout: 20_000 })

  if (result.status !== 0) return fallback
  return composeProjectFromConfig(result.stdout, fallback)
}

/**
 * Lists running Docker containers with their compose labels.
 *
 * @returns {Array<object>}
 */
function listDockerContainers() {
  const result = docker(["ps", "--format", "{{json .}}"], { timeout: 15_000 })
  if (result.status !== 0) return []
  return parseDockerPs(result.stdout)
}

/**
 * Finds the host process listening on a port.
 *
 * @param {number} port port number
 * @returns {{pid: number, name: string}|null}
 */
function findHostProcess(port) {
  return process.platform === "win32" ? findWindowsProcess(port) : findPosixProcess(port)
}

/**
 * Finds a Windows process that owns a listening TCP port.
 *
 * @param {number} port port number
 * @returns {{pid: number, name: string}|null}
 */
function findWindowsProcess(port) {
  const netstat = spawnSync("netstat", ["-ano", "-p", "tcp"], {
    encoding: "utf8",
    timeout: 15_000,
    windowsHide: true,
  })
  if (netstat.status !== 0) return null

  const entries = parseNetstat(netstat.stdout).filter((item) => item.port === port)
  // Prefer the listening socket over established connections that happen to
  // reuse the same local port number.
  const entry =
    entries.find((item) => /^(0\.0\.0\.0|\[::\]):0$/.test(item.remoteAddress)) || entries[0]
  if (!entry) return null

  const tasklist = spawnSync("tasklist", ["/FI", `PID eq ${entry.pid}`, "/FO", "CSV", "/NH"], {
    encoding: "utf8",
    timeout: 10_000,
    windowsHide: true,
  })

  return { pid: entry.pid, name: parseTasklist(tasklist.stdout) || "unknown" }
}

/**
 * Finds a macOS/Linux process that owns a listening TCP port.
 *
 * @param {number} port port number
 * @returns {{pid: number, name: string}|null}
 */
function findPosixProcess(port) {
  const lsof = spawnSync("lsof", ["-nP", `-iTCP:${port}`, "-sTCP:LISTEN", "-Fpc"], {
    encoding: "utf8",
    timeout: 10_000,
  })

  if (lsof.status === 0) {
    const owners = parseLsof(lsof.stdout)
    if (owners.length > 0) {
      return { pid: owners[0].pid, name: owners[0].name || "unknown" }
    }
  }

  const ss = spawnSync("ss", ["-lptnH", `sport = :${port}`], {
    encoding: "utf8",
    timeout: 10_000,
  })

  if (ss.status === 0) {
    const owner = parseSs(ss.stdout)
    if (owner) return owner
  }

  return null
}

/**
 * Returns the executable name for a process, when the platform allows it.
 *
 * @param {number} pid process id
 * @returns {string|null}
 */
function posixProcessName(pid) {
  const result = spawnSync("ps", ["-p", String(pid), "-o", "comm="], {
    encoding: "utf8",
    timeout: 5_000,
  })

  if (result.status !== 0) return null
  return result.stdout.trim() || null
}

/**
 * Checks whether a process is alive and returns its executable name.
 *
 * @param {number} pid process id
 * @returns {{alive: boolean|null, name: string|null}}
 */
function processInfo(pid) {
  if (process.platform === "win32") {
    const result = spawnSync("tasklist", ["/FI", `PID eq ${pid}`, "/FO", "CSV", "/NH"], {
      encoding: "utf8",
      timeout: 10_000,
      windowsHide: true,
    })
    if (result.status !== 0) return { alive: null, name: null }

    const name = parseTasklist(result.stdout)
    return { alive: Boolean(name), name }
  }

  try {
    process.kill(pid, 0)
  } catch (error) {
    if (error.code === "ESRCH") return { alive: false, name: null }
    if (error.code === "EPERM") return { alive: true, name: posixProcessName(pid) }
    return { alive: null, name: null }
  }

  return { alive: true, name: posixProcessName(pid) }
}

/**
 * Removes the host PID file when it is stale.
 *
 * The Rails container writes its PID to `/tmp/puma-server.pid`, so a leftover
 * host `tmp/pids/server.pid` cannot block startup. This cleanup is best-effort:
 * a file locked by an editor or WSL is ignored.
 *
 * Live Ruby/Puma processes are never killed or hidden automatically.
 *
 * @returns {void}
 */
function cleanupStalePidFile() {
  let content
  try {
    content = fs.readFileSync(PID_FILE, "utf8")
  } catch {
    return
  }

  const pid = parsePidFile(content)
  const state = pid ? processInfo(pid) : { alive: null, name: null }

  if (
    !shouldRemovePidFile({
      pid,
      processAlive: state.alive,
      processName: state.name,
    })
  ) {
    return
  }

  try {
    fs.rmSync(PID_FILE, { force: true })
    setSplashMessage(
      "Прибираю застарілий server.pid…",
      state.alive === false ? `процес ${pid} вже не працює` : "PID більше не належить Rails"
    )
  } catch {
    // The container uses its own PIDFILE, so a locked file must not block startup.
  }
}

/**
 * Determines who owns an occupied port.
 *
 * @param {number} port port number
 * @param {string} label human-readable service label
 * @param {Array<object>} containers running Docker containers
 * @param {string} currentProject current compose project name
 * @returns {Promise<object>}
 */
async function inspectPort(port, label, containers, currentProject) {
  if (await isPortFree(port)) return { port, label, type: "free" }

  const published = containers.filter((container) => container.publishedPorts.includes(port))
  const processOwner = published.length > 0 ? null : findHostProcess(port)

  return classifyPortOwner({
    port,
    label,
    dockerContainers: published,
    processOwner,
    projectRoot: PROJECT_ROOT,
    currentProject,
  })
}

/**
 * Describes a blocked port for the user-facing dialog.
 *
 * @param {object} item classified port owner
 * @returns {string}
 */
function describeBlocker(item) {
  if (item.type === "process") {
    return `Порт ${item.port} (${item.label}) зайнятий процесом «${item.process.name}» (PID ${item.process.pid}).`
  }

  if (item.type === "own-container") {
    return `Порт ${item.port} (${item.label}) зайнятий контейнером «${item.container.name}».`
  }

  if (item.type === "stale-container" || item.type === "foreign-container") {
    return `Порт ${item.port} (${item.label}) зайнятий Docker-контейнером «${item.container.name}» (проєкт «${item.container.project || "—"}», ID ${item.container.id}).`
  }

  return `Порт ${item.port} (${item.label}) зайнятий невідомим процесом. Можливо, Windows зарезервував цей порт. Перевір: netsh interface ipv4 show excludedportrange protocol=tcp.`
}

/**
 * Shows a dialog for ports owned by external processes and asks whether to retry.
 *
 * Unknown processes are never killed automatically: they may belong to another
 * application or to Windows itself.
 *
 * @param {Array<object>} blockers occupied ports
 * @returns {Promise<boolean>} true when the user wants to retry
 */
async function showPortConflict(blockers) {
  const detail = blockers.map(describeBlocker).join("\n")
  const { response } = await dialog.showMessageBox({
    type: "warning",
    title: "Порти зайняті",
    message: "Деякі порти вже використовуються",
    detail: `${detail}\n\nЗвільни ці порти вручну (закрий процес або зупини контейнер) і натисни «Перевірити ще раз».`,
    buttons: ["Перевірити ще раз", "Скасувати"],
    defaultId: 0,
    cancelId: 1,
    noLink: true,
  })

  return response === 0
}

/**
 * Frees ports held by our own stale containers and asks the user about foreign owners.
 *
 * Containers whose labels match the current Compose project are left running:
 * `docker compose up` reuses them and does not rebuild the image.
 *
 * @param {string} currentProject current Compose project name
 * @returns {Promise<void>}
 */
async function preparePorts(currentProject) {
  for (let attempt = 0; attempt < MAX_PORT_ATTEMPTS; attempt += 1) {
    const containers = listDockerContainers()
    const results = []

    for (const item of PORTS) {
      results.push(await inspectPort(item.port, item.label, containers, currentProject))
    }

    const blocking = results.filter((result) => result.type !== "free")
    if (blocking.length === 0) return

    const stale = blocking.filter((result) => result.type === "stale-container")
    if (stale.length > 0) {
      setSplashMessage("Зупиняю старі контейнери…", stale.map((item) => item.container.name).join(", "))

      for (const item of stale) {
        const stopped = docker(["stop", item.container.id], { timeout: 30_000 })
        if (stopped.status !== 0) {
          const output = [stopped.stderr, stopped.stdout].filter(Boolean).join(" ").trim()
          throw new Error(
            `Не вдалося зупинити старий контейнер «${item.container.name}»${output ? `: ${output}` : "."}`
          )
        }
      }

      continue
    }

    const external = blocking.filter((result) => result.type !== "own-container")
    if (external.length === 0) return

    const retry = await showPortConflict(external)
    if (!retry) {
      throw new Error(`Запуск скасовано. ${external.map(describeBlocker).join(" ")}`)
    }
  }

  throw new Error(
    "Порти 3000 або 5433 залишаються зайнятими після кількох спроб. Звільни їх вручну і запусти застосунок знову."
  )
}

/**
 * Runs `docker compose up` and optionally waits for container health.
 *
 * @param {{wait?: boolean}} [options]
 * @returns {Promise<void>}
 */
function composeUp({ wait = true } = {}) {
  return new Promise((resolve, reject) => {
    const args = ["compose", ...COMPOSE_ARGS, "up", "-d", "--remove-orphans"]

    if (wait) {
      args.push("--wait", "--wait-timeout", "300")
    }

    const child = spawn("docker", args, {
      cwd: PROJECT_ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
    })

    let output = ""
    const append = (chunk) => {
      output += chunk
      if (output.length > 50_000) output = output.slice(-50_000)
    }

    child.stdout.on("data", append)
    child.stderr.on("data", append)
    child.on("error", reject)
    child.on("close", (code) => {
      if (code === 0) {
        resolve()
        return
      }

      if (wait && /unknown flag: --wait(?:-timeout)?/i.test(output)) {
        composeUp({ wait: false }).then(resolve).catch(reject)
        return
      }

      const error = new Error(
        "Docker Compose не зміг запустити контейнери. Перевір, чи вільні порти 3000 і 5433, та логи."
      )
      error.details = output.trim()
      reject(error)
    })
  })
}

/**
 * Stops compose services without blocking application quit.
 *
 * @returns {void}
 */
function composeStop() {
  try {
    const child = spawn("docker", ["compose", ...COMPOSE_ARGS, "stop"], {
      cwd: PROJECT_ROOT,
      detached: true,
      stdio: "ignore",
      windowsHide: true,
    })
    child.on("error", () => {})
    child.unref()
  } catch {
    // The app must quit even when Docker is unavailable.
  }
}

/**
 * Creates the frameless splash window shown while Docker and Rails start.
 *
 * @returns {void}
 */
function createSplashWindow() {
  splashWindow = new BrowserWindow({
    width: 420,
    height: 260,
    frame: false,
    resizable: false,
    center: true,
    webPreferences: { sandbox: true },
  })

  const html = `<!doctype html>
<html lang="uk">
  <head>
    <meta charset="utf-8">
    <style>
      body {
        margin: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100vh;
        background: #0f172a;
        color: #e2e8f0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      .box { text-align: center; padding: 0 24px; }
      .spinner {
        width: 42px;
        height: 42px;
        margin: 0 auto 18px;
        border: 4px solid #334155;
        border-top-color: #38bdf8;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      }
      p { margin: 0; font-size: 15px; }
      small { display: block; margin-top: 8px; color: #94a3b8; font-size: 12px; }
      @keyframes spin { to { transform: rotate(360deg); } }
    </style>
  </head>
  <body>
    <div class="box">
      <div class="spinner"></div>
      <p id="message">Підготовка до запуску…</p>
      <small id="detail">Перевіряю Docker і порти</small>
    </div>
  </body>
</html>`

  splashWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`)
}

/**
 * Updates the splash status text.
 *
 * @param {string} message main status line
 * @param {string} [detail] secondary status line
 * @returns {void}
 */
function setSplashMessage(message, detail = "") {
  if (!splashWindow || splashWindow.isDestroyed()) return

  const script = `(() => {
    const messageNode = document.getElementById("message")
    const detailNode = document.getElementById("detail")
    if (messageNode) messageNode.textContent = ${JSON.stringify(message)}
    if (detailNode) detailNode.textContent = ${JSON.stringify(detail)}
  })()`

  splashWindow.webContents.executeJavaScript(script).catch(() => {})
}

/**
 * Destroys the splash window if it still exists.
 *
 * @returns {void}
 */
function destroySplash() {
  if (splashWindow && !splashWindow.isDestroyed()) splashWindow.destroy()
  splashWindow = null
}

/**
 * Runs a Docker command and returns its output for the diagnostics log.
 *
 * @param {string[]} args docker arguments
 * @param {number} timeout timeout in milliseconds
 * @returns {string}
 */
function runDockerText(args, timeout) {
  const result = docker(args, { timeout })
  if (result.error) return `error: ${result.error.message}`

  const output = [result.stdout, result.stderr].filter(Boolean).join("\n").trim()
  return output || "(порожньо)"
}

/**
 * Writes startup diagnostics to the Electron logs directory.
 *
 * @param {Error} error startup error
 * @returns {string} path to the log file or a human-readable fallback message
 */
function writeDiagnostics(error) {
  try {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
    const directory = app.getPath("logs")
    const file = path.join(directory, `startup-${stamp}.log`)

    fs.mkdirSync(directory, { recursive: true })

    const sections = [
      `[${new Date().toISOString()}] ${error.name || "Error"}: ${error.message}`,
      error.stack || "",
      error.details ? `\n--- command output ---\n${error.details}` : "",
      "",
      "=== docker compose ps ===",
      runDockerText(["compose", ...COMPOSE_ARGS, "ps"], 15_000),
      "",
      "=== docker compose logs --tail=80 web db ===",
      runDockerText(
        ["compose", ...COMPOSE_ARGS, "logs", "--no-color", "--tail", "80", "web", "db"],
        30_000
      ),
      "",
    ]

    fs.writeFileSync(file, sections.join("\n"), "utf8")
    return file
  } catch (writeError) {
    return `не вдалося записати лог: ${writeError.message}`
  }
}

/**
 * Shows a startup error and points the user to the diagnostics log.
 *
 * @param {Error} error startup error
 * @returns {void}
 */
function showStartupError(error) {
  const logPath = writeDiagnostics(error)
  const choice = dialog.showMessageBoxSync({
    type: "error",
    title: "Не вдалося запустити застосунок",
    message: error.message || "Невідома помилка",
    detail: `Діагностику збережено:\n${logPath}`,
    buttons: ["Закрити", "Показати лог"],
    defaultId: 0,
    cancelId: 0,
    noLink: true,
  })

  if (choice === 1) shell.showItemInFolder(logPath)
}

/**
 * Opens an external URL in the system browser.
 *
 * @param {string} url external URL
 * @returns {void}
 */
function openExternal(url) {
  shell.openExternal(url)
}

/**
 * Creates the main application window after Rails is ready.
 *
 * @returns {void}
 */
function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1024,
    minHeight: 700,
    show: false,
    title: "Salary Management",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      partition: "persist:salary-management",
    },
  })

  mainWindow.once("ready-to-show", () => {
    destroySplash()
    mainWindow.show()
  })

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isAppUrl(APP_URL, url)) {
      return { action: "allow" }
    }

    openExternal(url)
    return { action: "deny" }
  })

  mainWindow.webContents.on("will-navigate", (event, url) => {
    if (!isAppUrl(APP_URL, url)) {
      event.preventDefault()
      openExternal(url)
    }
  })

  mainWindow.webContents.on("did-fail-load", (_event, _code, description) => {
    dialog.showErrorBox("Не вдалося завантажити застосунок", description)
  })

  mainWindow.on("closed", () => {
    mainWindow = null
  })

  mainWindow.loadURL(APP_URL)
}

/**
 * Backs up the development database through Docker Compose.
 *
 * @returns {void}
 */
function backupDatabase() {
  const backupDir = path.join(app.getPath("documents"), "SalaryManagement", "backups")
  fs.mkdirSync(backupDir, { recursive: true })

  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
  const file = path.join(backupDir, `salary-management-${stamp}.sql`)

  const child = spawn(
    "docker",
    ["compose", ...COMPOSE_ARGS, "exec", "-T", "db", "pg_dump", "-U", "postgres", "-d", DATABASE_NAME],
    { cwd: PROJECT_ROOT }
  )

  const chunks = []
  child.stdout.on("data", (chunk) => chunks.push(chunk))
  child.on("error", (error) => {
    dialog.showErrorBox("Бекап не вдався", error.message)
  })
  child.on("close", (code) => {
    if (code !== 0) {
      dialog.showErrorBox(
        "Бекап не вдався",
        "pg_dump завершився з помилкою. Перевір, чи запущені контейнери."
      )
      return
    }

    fs.writeFileSync(file, Buffer.concat(chunks))
    dialog.showMessageBox({
      type: "info",
      title: "Бекап готовий",
      message: `Базу збережено у файл:\n${file}`,
      buttons: ["OK"],
    })
  })
}

/**
 * Builds the application menu.
 *
 * @returns {void}
 */
function buildMenu() {
  const template = [
    ...(process.platform === "darwin" ? [{ role: "appMenu" }] : []),
    {
      label: "Файл",
      submenu: [
        { label: "Бекап бази…", click: backupDatabase },
        { type: "separator" },
        process.platform === "darwin" ? { role: "close" } : { role: "quit" },
      ],
    },
    { role: "editMenu" },
    { role: "viewMenu" },
  ]

  Menu.setApplicationMenu(Menu.buildFromTemplate(template))
}

/**
 * Runs the full startup sequence: Docker, ports, containers, Rails health.
 *
 * @returns {Promise<void>}
 */
async function boot() {
  createSplashWindow()

  try {
    setSplashMessage("Перевіряю Docker…", "Якщо Docker Desktop не запущений, я спробую його відкрити")
    await ensureDocker()

    setSplashMessage("Перевіряю Rails PID…", "Шукаю застарілий tmp/pids/server.pid")
    cleanupStalePidFile()

    setSplashMessage("Перевіряю порти…", "Rails: 3000, PostgreSQL: 5433")
    await preparePorts(resolveComposeProject())

    setSplashMessage("Запускаю контейнери…", "Перший запуск може тривати кілька хвилин")
    await composeUp()

    setSplashMessage("Чекаю на Rails…", "Перевіряю готовність застосунку та бази даних")
    await waitForApp(HEALTH_URL, { timeout: 180_000 })

    createMainWindow()
  } catch (error) {
    destroySplash()
    showStartupError(error)
    app.quit()
  }
}

if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  app.on("second-instance", () => {
    if (!mainWindow) return

    if (mainWindow.isMinimized()) mainWindow.restore()
    mainWindow.focus()
  })

  app.whenReady().then(() => {
    buildMenu()
    boot()
  })

  app.on("window-all-closed", () => app.quit())
  app.on("before-quit", composeStop)
}
