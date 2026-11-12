"use strict"

const fs = require("node:fs")
const http = require("node:http")
const net = require("node:net")
const path = require("node:path")

/**
 * Checks whether a candidate URL belongs to the configured application origin.
 *
 * @param {string} appUrl base application URL
 * @param {string} candidate URL to validate
 * @returns {boolean} true when both URLs share the same origin
 */
function isAppUrl(appUrl, candidate) {
  try {
    return new URL(candidate).origin === new URL(appUrl).origin
  } catch {
    return false
  }
}

/**
 * Waits for a synchronous or asynchronous condition to become truthy.
 *
 * @param {() => boolean|Promise<boolean>} check condition to evaluate
 * @param {{timeout?: number, interval?: number, message?: string}} [options]
 * @returns {Promise<void>}
 */
async function waitForCondition(check, { timeout = 60_000, interval = 1_000, message = "Час очікування вичерпано" } = {}) {
  const startedAt = Date.now()
  let lastError = null

  while (true) {
    try {
      if (await check()) return
    } catch (error) {
      lastError = error
    }

    if (Date.now() - startedAt >= timeout) {
      throw new Error(lastError ? `${message} (${lastError.message})` : message)
    }

    await new Promise((resolve) => setTimeout(resolve, interval))
  }
}

/**
 * Polls an HTTP endpoint until it returns the expected status.
 *
 * Only the expected status counts as ready: a 404 from another local service or
 * a 500 while Rails is still booting must not open the desktop window.
 *
 * @param {string} appUrl URL to poll
 * @param {{timeout?: number, interval?: number, expectedStatus?: number}} [options]
 * @returns {Promise<import("node:http").IncomingMessage>}
 */
function waitForApp(appUrl, { timeout = 120_000, interval = 1_000, expectedStatus = 200 } = {}) {
  const startedAt = Date.now()
  let lastStatus = null
  let lastError = null
  let finished = false
  let retryScheduled = false

  return new Promise((resolve, reject) => {
    const finish = (callback, value) => {
      if (finished) return
      finished = true
      callback(value)
    }

    const scheduleRetry = () => {
      if (finished || retryScheduled) return

      if (Date.now() - startedAt >= timeout) {
        const status = lastStatus
          ? `останній статус: ${lastStatus}`
          : `остання помилка: ${lastError?.message || "невідома"}`
        finish(reject, new Error(`Застосунок не відповів вчасно (${status}). Перевір логи: docker compose logs web`))
        return
      }

      retryScheduled = true
      setTimeout(() => {
        retryScheduled = false
        attempt()
      }, interval)
    }

    const attempt = () => {
      if (finished) return

      const request = http.get(appUrl, (response) => {
        lastStatus = response.statusCode
        response.resume()

        if (response.statusCode === expectedStatus) {
          finish(resolve, response)
          return
        }

        scheduleRetry()
      })

      request.setTimeout(2_000, () => request.destroy())
      request.on("error", (error) => {
        lastError = error
        scheduleRetry()
      })
    }

    attempt()
  })
}

/**
 * Tries to open a TCP connection to a local port.
 *
 * @param {number} port port to probe
 * @param {string} [host] host to probe
 * @param {number} [timeout] connection timeout in milliseconds
 * @returns {Promise<boolean>} true when something accepts connections
 */
function probeConnection(port, host = "127.0.0.1", timeout = 500) {
  return new Promise((resolve) => {
    const socket = net.connect({ port, host })
    let settled = false

    const finish = (value) => {
      if (settled) return
      settled = true
      socket.destroy()
      resolve(value)
    }

    socket.setTimeout(timeout)
    socket.once("connect", () => finish(true))
    socket.once("timeout", () => finish(false))
    socket.once("error", () => finish(false))
  })
}

/**
 * Tries to bind a listening socket to the given port.
 *
 * @param {number} port port to bind
 * @param {string} [host] bind address
 * @returns {Promise<boolean>} true when the port can be bound
 */
function canBind(port, host = "0.0.0.0") {
  return new Promise((resolve) => {
    const server = net.createServer()
    server.unref()
    server.once("error", () => resolve(false))
    server.listen({ port, host, exclusive: true }, () => {
      server.close(() => resolve(true))
    })
  })
}

/**
 * Determines whether a TCP port is free.
 *
 * A connection probe catches services bound to 127.0.0.1 or 0.0.0.0, while the
 * bind probe also catches ports reserved by Windows (WinNAT/Hyper-V).
 *
 * @param {number} port port to check
 * @param {{host?: string, bindHost?: string}} [options]
 * @returns {Promise<boolean>} true when the port is not in use
 */
async function isPortFree(port, { host = "127.0.0.1", bindHost = "0.0.0.0" } = {}) {
  if (await probeConnection(port, host)) return false
  return canBind(port, bindHost)
}

/**
 * Extracts the port number from an address like `0.0.0.0:3000` or `[::]:3000`.
 *
 * @param {string} address address to parse
 * @returns {number|null} port number or null
 */
function extractPort(address) {
  const match = /:(\d+)$/.exec(String(address || "").trim())
  return match ? Number(match[1]) : null
}

/**
 * Parses `netstat -ano -p tcp` output on Windows.
 *
 * @param {string} output raw netstat output
 * @returns {Array<{localAddress: string, remoteAddress: string, port: number, pid: number, state: string}>}
 */
function parseNetstat(output) {
  return String(output || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const parts = line.split(/\s+/)
      if (parts.length < 5) return null
      if (parts[0].toUpperCase() !== "TCP") return null

      const port = extractPort(parts[1])
      const pid = Number(parts[parts.length - 1])
      if (!port || !Number.isInteger(pid) || pid <= 0) return null

      return {
        localAddress: parts[1],
        remoteAddress: parts[2],
        port,
        pid,
        state: parts[parts.length - 2],
      }
    })
    .filter(Boolean)
}

/**
 * Parses `lsof -Fpc` output into process entries.
 *
 * @param {string} output raw lsof output
 * @returns {Array<{pid: number, name?: string}>}
 */
function parseLsof(output) {
  const entries = []
  let current = null

  for (const line of String(output || "").split(/\r?\n/)) {
    if (line.startsWith("p")) {
      if (current) entries.push(current)
      current = { pid: Number(line.slice(1)) }
    } else if (line.startsWith("c") && current) {
      current.name = line.slice(1)
    }
  }

  if (current) entries.push(current)
  return entries.filter((entry) => Number.isInteger(entry.pid) && entry.pid > 0)
}

/**
 * Parses the `users:(("name",pid=123,...))` fragment printed by `ss`.
 *
 * @param {string} output raw `ss` output
 * @returns {{pid: number, name: string}|null}
 */
function parseSs(output) {
  const match = /users:\(\("([^"]+)",pid=(\d+)/.exec(String(output || ""))
  if (!match) return null
  return { name: match[1], pid: Number(match[2]) }
}

/**
 * Parses the process name from `tasklist /FO CSV /NH` output.
 *
 * @param {string} output raw tasklist output
 * @returns {string|null} executable name
 */
function parseTasklist(output) {
  const line = String(output || "")
    .split(/\r?\n/)
    .map((item) => item.trim())
    .find((item) => item.startsWith('"'))

  if (!line) return null
  const match = /^"([^"]+)"/.exec(line)
  return match ? match[1] : null
}

/**
 * Parses Docker's comma-separated label string into an object.
 *
 * @param {string|object} value label string or object
 * @returns {Record<string, string>}
 */
function parseLabels(value) {
  if (value && typeof value === "object") return value

  const labels = {}
  for (const part of String(value || "").split(",")) {
    const index = part.indexOf("=")
    if (index === -1) continue
    labels[part.slice(0, index)] = part.slice(index + 1)
  }
  return labels
}

/**
 * Extracts published host ports from Docker's `Ports` string.
 *
 * @param {string} value e.g. `0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp`
 * @returns {number[]} published host ports
 */
function publishedPortsFromString(value) {
  const ports = new Set()
  const pattern = /(?:^|[\s,])(?:\[[^\]]+\]|[^:\s,]+):(\d+)->/g
  let match

  while ((match = pattern.exec(String(value || "")))) {
    ports.add(Number(match[1]))
  }

  return [...ports]
}

/**
 * Parses `docker ps --format "{{json .}}"` output.
 *
 * @param {string} output newline-delimited JSON
 * @returns {Array<{id: string, name: string, ports: string, publishedPorts: number[], labels: Record<string,string>, project: string, workingDir: string, service: string, state: string}>}
 */
function parseDockerPs(output) {
  return String(output || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line)
      } catch {
        return null
      }
    })
    .filter(Boolean)
    .map((item) => {
      const labels = parseLabels(item.Labels)

      return {
        id: item.ID || item.Id || "",
        name: item.Names || item.Name || "",
        ports: item.Ports || "",
        publishedPorts: publishedPortsFromString(item.Ports),
        labels,
        project: labels["com.docker.compose.project"] || "",
        workingDir: labels["com.docker.compose.project.working_dir"] || "",
        service: labels["com.docker.compose.service"] || "",
        state: item.State || "",
      }
    })
}

/**
 * Normalizes a filesystem path for cross-platform comparison.
 *
 * @param {string} value path to normalize
 * @param {NodeJS.Platform} [platform] target platform
 * @returns {string} normalized path
 */
function normalizePath(value, platform = process.platform) {
  if (!value) return ""

  let result = String(value).trim().replace(/\\/g, "/").replace(/\/+$/, "")
  if (platform === "win32") {
    result = result.replace(/^\/c\//i, "c:/").toLowerCase()
  }
  return result
}

/**
 * Parses the contents of `tmp/pids/server.pid`.
 *
 * @param {string} content PID file contents
 * @returns {number|null} PID or null when the file is empty/corrupt
 */
function parsePidFile(content) {
  const match = /^\s*(\d+)\s*$/.exec(String(content || ""))
  if (!match) return null

  const pid = Number(match[1])
  return Number.isInteger(pid) && pid > 0 ? pid : null
}

/**
 * Decides whether a Rails PID file is stale and can be removed safely.
 *
 * A file is stale when it has no valid PID, when the recorded process is gone,
 * or when the PID was reused by a non-Rails process. A live Ruby/Puma process
 * is never treated as stale, and unknown process states are left alone.
 *
 * @param {{pid: number|null, processAlive: boolean|null, processName: string|null}} state
 * @returns {boolean} true when the PID file can be removed
 */
function shouldRemovePidFile({ pid, processAlive, processName }) {
  if (!pid) return true
  if (processAlive === false) return true
  if (processAlive === true) {
    if (!processName) return false
    return !/ruby|puma|rails/i.test(processName)
  }
  return false
}

/**
 * Reads the project name from `docker compose config --format json` output.
 *
 * The full config may contain interpolated environment values, so callers must
 * only keep the returned name and never log the raw output.
 *
 * @param {string} output JSON produced by `docker compose config --format json`
 * @param {string} fallback value used when the output is missing or invalid
 * @returns {string} compose project name
 */
function composeProjectFromConfig(output, fallback) {
  try {
    const config = JSON.parse(String(output || ""))
    if (config && typeof config.name === "string" && config.name.trim()) {
      return config.name.trim()
    }
  } catch {
    // Fall through to the caller-provided fallback.
  }

  return fallback
}

/**
 * Derives the default Docker Compose project name from a project directory.
 *
 * @param {string} projectRoot project directory
 * @param {NodeJS.Platform} [platform] target platform
 * @returns {string} compose project name
 */
function defaultComposeProjectName(projectRoot, platform = process.platform) {
  const base = platform === "win32"
    ? path.win32.basename(String(projectRoot || ""))
    : path.basename(String(projectRoot || ""))
  const sanitized = base.toLowerCase().replace(/[^a-z0-9_-]/g, "")
  return sanitized || "default"
}

/**
 * Classifies the owner of an occupied port.
 *
 * @param {{port: number, label: string, dockerContainers?: object[], processOwner?: {pid: number, name: string}|null, projectRoot?: string, currentProject?: string, platform?: NodeJS.Platform}} input
 * @returns {{port: number, label: string, type: "free"|"own-container"|"stale-container"|"foreign-container"|"process"|"unknown", container?: object, process?: object}}
 */
function classifyPortOwner({
  port,
  label,
  dockerContainers = [],
  processOwner = null,
  projectRoot = "",
  currentProject = "",
  platform = process.platform,
}) {
  if (processOwner) {
    return { port, label, type: "process", process: processOwner }
  }

  if (dockerContainers.length > 0) {
    const root = normalizePath(projectRoot, platform)
    const sameDirectory = root
      ? dockerContainers.filter((container) => normalizePath(container.workingDir, platform) === root)
      : []
    const sameProject = currentProject
      ? dockerContainers.find((container) => container.project === currentProject)
      : null
    const container = sameProject || sameDirectory[0] || dockerContainers[0]

    let type = "foreign-container"
    if (sameProject) {
      type = "own-container"
    } else if (sameDirectory.length > 0) {
      type = "stale-container"
    }

    return { port, label, type, container }
  }

  return { port, label, type: "unknown" }
}

/**
 * Returns the commands that can start Docker Desktop on the current platform.
 *
 * @param {NodeJS.Platform} [platform] target platform
 * @param {Record<string, string|undefined>} [env] environment variables
 * @returns {Array<{command: string, args: string[]}>}
 */
function dockerDesktopCandidates(platform = process.platform, env = process.env) {
  if (platform === "darwin") {
    return [{ command: "open", args: ["-a", "Docker"] }]
  }

  if (platform === "win32") {
    const programFiles = env.ProgramFiles || env.PROGRAMFILES || "C:\\Program Files"
    const localAppData = env.LOCALAPPDATA || ""
    const candidates = [
      { command: path.win32.join(programFiles, "Docker", "Docker", "Docker Desktop.exe"), args: [] },
    ]

    if (localAppData) {
      candidates.push({
        command: path.win32.join(localAppData, "Programs", "Docker", "Docker", "Docker Desktop.exe"),
        args: [],
      })
    }

    return candidates
  }

  if (platform === "linux") {
    return [{ command: "systemctl", args: ["--user", "start", "docker"] }]
  }

  return []
}

/**
 * Checks whether a file exists without throwing.
 *
 * @param {string} filePath path to check
 * @returns {boolean}
 */
function fileExists(filePath) {
  try {
    return fs.existsSync(filePath)
  } catch {
    return false
  }
}

module.exports = {
  canBind,
  classifyPortOwner,
  composeProjectFromConfig,
  defaultComposeProjectName,
  dockerDesktopCandidates,
  extractPort,
  fileExists,
  isAppUrl,
  isPortFree,
  normalizePath,
  parseDockerPs,
  parseLabels,
  parseLsof,
  parseNetstat,
  parsePidFile,
  parseSs,
  parseTasklist,
  probeConnection,
  publishedPortsFromString,
  shouldRemovePidFile,
  waitForApp,
  waitForCondition,
}
