"use strict"

const { app, BrowserWindow, dialog, Menu, shell } = require("electron")
const { spawn, spawnSync } = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")

const { isAppUrl, waitForApp } = require("./lib")

const PROJECT_ROOT = path.resolve(__dirname, "..")
const APP_URL = "http://localhost:3000"
const DATABASE_NAME = "salary_management_development"

let mainWindow = null
let splashWindow = null

function docker(args, options = {}) {
  return spawnSync("docker", args, {
    cwd: PROJECT_ROOT,
    encoding: "utf8",
    timeout: 20_000,
    ...options,
  })
}

function isDockerRunning() {
  return docker(["info"]).status === 0
}

function composeUp() {
  return new Promise((resolve, reject) => {
    const child = spawn("docker", ["compose", "up", "-d"], {
      cwd: PROJECT_ROOT,
      stdio: ["ignore", "pipe", "pipe"],
    })

    let output = ""
    child.stdout.on("data", (chunk) => (output += chunk))
    child.stderr.on("data", (chunk) => (output += chunk))
    child.on("error", reject)
    child.on("close", (code) => {
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(output.trim() || `docker compose up завершився з кодом ${code}`))
      }
    })
  })
}

function composeStop() {
  docker(["compose", "stop"], { timeout: 60_000 })
}

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
      .box { text-align: center; }
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
      <p>Запускаю Salary Management…</p>
      <small>Піднімаю Docker-контейнери</small>
    </div>
  </body>
</html>`

  splashWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`)
}

function openExternal(url) {
  shell.openExternal(url)
}

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
    if (splashWindow) {
      splashWindow.destroy()
      splashWindow = null
    }

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

  mainWindow.on("closed", () => {
    mainWindow = null
  })

  mainWindow.loadURL(APP_URL)
}

function backupDatabase() {
  const backupDir = path.join(app.getPath("documents"), "SalaryManagement", "backups")
  fs.mkdirSync(backupDir, { recursive: true })

  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
  const file = path.join(backupDir, `salary-management-${stamp}.sql`)

  const child = spawn(
    "docker",
    ["compose", "exec", "-T", "db", "pg_dump", "-U", "postgres", "-d", DATABASE_NAME],
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

async function boot() {
  if (!isDockerRunning()) {
    dialog.showErrorBox(
      "Docker не запущено",
      "Запусти Docker Desktop (macOS/Windows) або Docker Engine (Linux) і відкрий застосунок знову."
    )
    app.quit()
    return
  }

  createSplashWindow()

  try {
    await composeUp()
    await waitForApp(APP_URL)
    createMainWindow()
  } catch (error) {
    if (splashWindow) {
      splashWindow.destroy()
      splashWindow = null
    }

    dialog.showErrorBox("Не вдалося запустити застосунок", error.message)
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
