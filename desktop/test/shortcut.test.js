"use strict"

const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { afterEach, beforeEach, test } = require("node:test")

const {
  buildLaunchers,
  installShortcut,
  uninstallShortcut,
} = require("../scripts/shortcut")

const PROJECT_ROOT = "/tmp/My Projects/salary management"
const WINDOWS_PROJECT_ROOT = "C:\\My Projects\\salary management"
const ELECTRON_BINARIES = {
  darwin: `${PROJECT_ROOT}/desktop/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron`,
  win32: "C:\\My Projects\\salary management\\desktop\\node_modules\\electron\\dist\\electron.exe",
  linux: `${PROJECT_ROOT}/desktop/node_modules/electron/dist/electron`,
}

let homeDir

beforeEach(() => {
  homeDir = fs.mkdtempSync(path.join(os.tmpdir(), "salary-shortcut-"))
  fs.mkdirSync(path.join(homeDir, "Desktop"), { recursive: true })
})

afterEach(() => {
  fs.rmSync(homeDir, { recursive: true, force: true })
})

test("buildLaunchers creates a double-clickable .command on macOS", () => {
  const files = buildLaunchers({
    platform: "darwin",
    homeDir,
    projectRoot: PROJECT_ROOT,
    electronBinary: ELECTRON_BINARIES.darwin,
  })

  assert.equal(files.length, 1)
  assert.equal(files[0].path, path.join(homeDir, "Desktop", "Salary Management.command"))
  assert.equal(files[0].mode, 0o755)
  assert.match(files[0].content, /^#!\/bin\/zsh/)
  assert.match(files[0].content, /Applications\/Docker\.app\/Contents\/Resources\/bin/)
  assert.match(files[0].content, /cd "\/tmp\/My Projects\/salary management\/desktop"/)
  assert.match(files[0].content, /exec "\/tmp\/My Projects\/salary management\/desktop\/node_modules/)
})

test("buildLaunchers creates a .cmd shortcut on Windows", () => {
  const files = buildLaunchers({
    platform: "win32",
    homeDir,
    projectRoot: WINDOWS_PROJECT_ROOT,
    electronBinary: ELECTRON_BINARIES.win32,
  })

  assert.equal(files.length, 1)
  assert.equal(files[0].path, path.join(homeDir, "Desktop", "Salary Management.cmd"))
  assert.match(files[0].content, /@echo off/)
  assert.match(files[0].content, /Docker\\Docker\\resources\\bin/)
  assert.match(files[0].content, /cd \/d "C:\\My Projects\\salary management\\desktop"/)
  assert.match(files[0].content, /start "" "C:\\My Projects\\salary management\\desktop\\node_modules\\electron\\dist\\electron\.exe" \./)
})

test("buildLaunchers creates a .desktop entry on Linux", () => {
  const files = buildLaunchers({
    platform: "linux",
    homeDir,
    projectRoot: PROJECT_ROOT,
    electronBinary: ELECTRON_BINARIES.linux,
  })

  const applicationEntry = files.find((file) =>
    file.path.endsWith("share/applications/salary-management.desktop")
  )

  assert.ok(applicationEntry, "application menu entry should be created")
  assert.match(applicationEntry.content, /^\[Desktop Entry\]/)
  assert.match(applicationEntry.content, /Type=Application/)
  assert.match(applicationEntry.content, /Name=Salary Management/)
  assert.match(applicationEntry.content, /Terminal=false/)
  assert.match(applicationEntry.content, /Path=\/tmp\/My Projects\/salary management\/desktop/)
  assert.match(applicationEntry.content, /Exec=env PATH=.*"\/tmp\/My Projects\/salary management\/desktop\/node_modules\/electron\/dist\/electron" \./)
  assert.equal(applicationEntry.mode, 0o755)
  assert.ok(files.some((file) => file.path === path.join(homeDir, "Desktop", "Salary Management.desktop")))
})

test("installShortcut writes launchers and makes them executable", () => {
  const written = installShortcut({
    platform: "darwin",
    homeDir,
    projectRoot: PROJECT_ROOT,
    electronBinary: ELECTRON_BINARIES.darwin,
    log: () => {},
  })

  assert.equal(written.length, 1)
  const launcher = written[0]

  assert.equal(fs.existsSync(launcher), true)
  assert.equal(fs.statSync(launcher).mode & 0o111, 0o111)
  assert.match(fs.readFileSync(launcher, "utf8"), /electron/)
})

test("uninstallShortcut removes generated launchers", () => {
  installShortcut({
    platform: "darwin",
    homeDir,
    projectRoot: PROJECT_ROOT,
    electronBinary: ELECTRON_BINARIES.darwin,
    log: () => {},
  })

  const removed = uninstallShortcut({ platform: "darwin", homeDir, log: () => {} })

  assert.equal(removed.length, 1)
  assert.equal(fs.existsSync(removed[0]), false)
})

test("installShortcut downloads electron automatically when the binary is missing", () => {
  const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "salary-project-"))
  const electronDir = path.join(projectRoot, "desktop", "node_modules", "electron")
  fs.mkdirSync(electronDir, { recursive: true })
  fs.writeFileSync(path.join(electronDir, "install.js"), "")

  const binaryPath = path.join(electronDir, "dist", "electron")
  let installCalls = 0

  const written = installShortcut({
    platform: "linux",
    homeDir,
    projectRoot,
    log: () => {},
    installElectron: () => {
      installCalls += 1
      fs.mkdirSync(path.dirname(binaryPath), { recursive: true })
      fs.writeFileSync(binaryPath, "")
      return true
    },
  })

  assert.equal(installCalls, 1)
  assert.equal(written.length > 0, true)

  fs.rmSync(projectRoot, { recursive: true, force: true })
})

test("installShortcut reports a clear error when the automatic download fails", () => {
  const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "salary-project-"))
  const electronDir = path.join(projectRoot, "desktop", "node_modules", "electron")
  fs.mkdirSync(electronDir, { recursive: true })
  fs.writeFileSync(path.join(electronDir, "install.js"), "")

  let installCalls = 0
  const binaryPath = path.join(electronDir, "dist", "electron")

  assert.throws(
    () =>
      installShortcut({
        platform: "linux",
        homeDir,
        projectRoot,
        log: () => {},
        installElectron: () => {
          installCalls += 1
          return false
        },
      }),
    (error) => {
      assert.match(error.message, /failed to download electron automatically/i)
      assert.match(error.message, new RegExp(binaryPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")))
      assert.match(error.message, /cd desktop/)
      assert.match(error.message, /node node_modules\/electron\/install\.js/)
      assert.match(error.message, /github\.com/)
      assert.match(error.message, /network\/firewall/)
      return true
    }
  )

  assert.equal(installCalls, 1)

  fs.rmSync(projectRoot, { recursive: true, force: true })
})

test("installShortcut tells the user to run npm install when the electron package itself is missing", () => {
  const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "salary-project-"))
  fs.mkdirSync(path.join(projectRoot, "desktop"), { recursive: true })

  let installCalls = 0

  assert.throws(
    () =>
      installShortcut({
        platform: "linux",
        homeDir,
        projectRoot,
        log: () => {},
        installElectron: () => {
          installCalls += 1
          return true
        },
      }),
    (error) => {
      assert.match(error.message, /Electron not found at path/)
      assert.match(error.message, /cd desktop && npm install/)
      return true
    }
  )

  assert.equal(installCalls, 0, "installElectron must never run without install.js")

  fs.rmSync(projectRoot, { recursive: true, force: true })
})

test("buildLaunchers rejects unsupported platforms", () => {
  assert.throws(
    () =>
      buildLaunchers({
        platform: "freebsd",
        homeDir,
        projectRoot: PROJECT_ROOT,
        electronBinary: ELECTRON_BINARIES.linux,
      }),
    /Unsupported platform/
  )
})
