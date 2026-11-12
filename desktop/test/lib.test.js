"use strict"

const assert = require("node:assert/strict")
const http = require("node:http")
const net = require("node:net")
const { after, before, test } = require("node:test")

const {
  classifyPortOwner,
  composeProjectFromConfig,
  defaultComposeProjectName,
  dockerDesktopCandidates,
  extractPort,
  isAppUrl,
  isPortFree,
  normalizePath,
  parseDockerPs,
  parseLsof,
  parseNetstat,
  parseSs,
  parseTasklist,
  publishedPortsFromString,
  waitForApp,
  waitForCondition,
} = require("../lib")

let server
let baseUrl

before(async () => {
  server = http.createServer((request, response) => response.end("ok"))
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve))
  baseUrl = `http://127.0.0.1:${server.address().port}`
})

after(async () => {
  await new Promise((resolve) => server.close(resolve))
})

async function listenOnRandomPort(handler = (_request, response) => response.end("ok")) {
  const testServer = http.createServer(handler)
  await new Promise((resolve) => testServer.listen(0, "127.0.0.1", resolve))
  return { server: testServer, port: testServer.address().port }
}

async function closeServer(testServer) {
  await new Promise((resolve) => testServer.close(resolve))
}

test("isAppUrl accepts URLs on the same origin", () => {
  assert.equal(isAppUrl(baseUrl, `${baseUrl}/users/sign_in`), true)
})

test("isAppUrl rejects other origins and invalid URLs", () => {
  assert.equal(isAppUrl(baseUrl, "https://example.com"), false)
  assert.equal(isAppUrl(baseUrl, "http://127.0.0.1:1"), false)
  assert.equal(isAppUrl(baseUrl, "not a url"), false)
})

test("waitForApp resolves once the server responds with the expected status", async () => {
  await waitForApp(baseUrl, { timeout: 2_000, interval: 50 })
})

test("waitForApp rejects when nothing is listening", async () => {
  await assert.rejects(
    waitForApp("http://127.0.0.1:1", { timeout: 300, interval: 50 }),
    /не відповів/
  )
})

test("waitForApp rejects non-200 responses instead of treating them as ready", async () => {
  const { server: notFoundServer, port } = await listenOnRandomPort((_request, response) => {
    response.statusCode = 404
    response.end("not found")
  })

  try {
    await assert.rejects(
      waitForApp(`http://127.0.0.1:${port}/up`, { timeout: 400, interval: 50 }),
      /останній статус: 404/
    )
  } finally {
    await closeServer(notFoundServer)
  }
})

test("waitForCondition resolves when the condition becomes truthy", async () => {
  let calls = 0
  await waitForCondition(() => (calls += 1) >= 3, { timeout: 1_000, interval: 20 })
  assert.equal(calls, 3)
})

test("waitForCondition rejects after the timeout", async () => {
  await assert.rejects(
    waitForCondition(() => false, { timeout: 100, interval: 20, message: "not ready" }),
    /not ready/
  )
})

test("isPortFree reports closed and listening ports correctly", async () => {
  const { server: testServer, port } = await listenOnRandomPort()

  try {
    assert.equal(await isPortFree(port), false)
  } finally {
    await closeServer(testServer)
  }

  const probe = net.createServer()
  await new Promise((resolve) => probe.listen(0, "127.0.0.1", resolve))
  const freePort = probe.address().port
  await new Promise((resolve) => probe.close(resolve))

  assert.equal(await isPortFree(freePort), true)
})

test("extractPort handles IPv4 and IPv6 addresses", () => {
  assert.equal(extractPort("0.0.0.0:3000"), 3000)
  assert.equal(extractPort("[::]:5433"), 5433)
  assert.equal(extractPort("no-port"), null)
})

test("parseNetstat extracts TCP ports and owning PIDs", () => {
  const output = [
    "  TCP    0.0.0.0:3000           0.0.0.0:0              LISTENING       1234",
    "  TCP    [::]:5433              [::]:0                 LISTENING       5678",
    "  TCP    127.0.0.1:3000         127.0.0.1:55555        ESTABLISHED     1234",
    "  UDP    0.0.0.0:3000           *:*                                    9999",
  ].join("\r\n")

  const entries = parseNetstat(output)

  assert.equal(entries.length, 3)
  assert.deepEqual(entries[0], {
    localAddress: "0.0.0.0:3000",
    remoteAddress: "0.0.0.0:0",
    port: 3000,
    pid: 1234,
    state: "LISTENING",
  })
  assert.equal(entries[1].port, 5433)
  assert.equal(entries[1].pid, 5678)
})

test("parseLsof extracts process identifiers", () => {
  const output = ["p1234", "cnode", "p5678", "crails"].join("\n")
  assert.deepEqual(parseLsof(output), [
    { pid: 1234, name: "node" },
    { pid: 5678, name: "rails" },
  ])
})

test("parseSs extracts a process from ss output", () => {
  const output =
    'LISTEN 0 511 0.0.0.0:3000 0.0.0.0:* users:(("node",pid=1234,fd=20))'

  assert.deepEqual(parseSs(output), { name: "node", pid: 1234 })
  assert.equal(parseSs("LISTEN 0 511 0.0.0.0:3000 0.0.0.0:*"), null)
})

test("parseTasklist extracts the executable name and ignores INFO lines", () => {
  assert.equal(
    parseTasklist('"node.exe","1234","Console","1","123,456 K"'),
    "node.exe"
  )
  assert.equal(parseTasklist("INFO: No tasks are running which match the specified criteria."), null)
})

test("publishedPortsFromString extracts host ports", () => {
  assert.deepEqual(
    publishedPortsFromString("0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp"),
    [3000]
  )
  assert.deepEqual(publishedPortsFromString("127.0.0.1:5433->5432/tcp"), [5433])
  assert.deepEqual(publishedPortsFromString(""), [])
})

test("parseDockerPs reads labels and published ports", () => {
  const output = JSON.stringify({
    ID: "abc123",
    Names: "salary_management-web-1",
    Ports: "0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp",
    Labels:
      "com.docker.compose.project=salary_management,com.docker.compose.project.working_dir=/tmp/project,com.docker.compose.service=web",
    State: "running",
  })

  const [container] = parseDockerPs(output)

  assert.equal(container.id, "abc123")
  assert.equal(container.name, "salary_management-web-1")
  assert.deepEqual(container.publishedPorts, [3000])
  assert.equal(container.project, "salary_management")
  assert.equal(container.workingDir, "/tmp/project")
  assert.equal(container.service, "web")
})

test("normalizePath compares Windows paths case-insensitively", () => {
  assert.equal(
    normalizePath("C:\\Users\\Foo\\", "win32"),
    normalizePath("/c/Users/Foo", "win32")
  )
  assert.equal(normalizePath("/Users/Foo/", "darwin"), "/Users/Foo")
})

test("defaultComposeProjectName sanitizes the project directory", () => {
  assert.equal(defaultComposeProjectName("/tmp/salary_management", "darwin"), "salary_management")
  assert.equal(
    defaultComposeProjectName("C:\\My Projects\\Salary Management", "win32"),
    "salarymanagement"
  )
})

test("composeProjectFromConfig reads the project name and falls back safely", () => {
  assert.equal(composeProjectFromConfig('{"name":"salary_management"}', "fallback"), "salary_management")
  assert.equal(composeProjectFromConfig("not json", "fallback"), "fallback")
  assert.equal(composeProjectFromConfig('{"services":{}}', "fallback"), "fallback")
  assert.equal(composeProjectFromConfig('{"name":"  "}', "fallback"), "fallback")
})

test("classifyPortOwner recognises own, stale, foreign, process and unknown owners", () => {
  const projectRoot = "/tmp/project"

  assert.deepEqual(
    classifyPortOwner({
      port: 3000,
      label: "Rails",
      projectRoot,
      currentProject: "project",
      dockerContainers: [
        {
          id: "1",
          name: "web",
          project: "project",
          workingDir: projectRoot,
        },
      ],
    }),
    {
      port: 3000,
      label: "Rails",
      type: "own-container",
      container: {
        id: "1",
        name: "web",
        project: "project",
        workingDir: projectRoot,
      },
    }
  )

  const stale = classifyPortOwner({
    port: 3000,
    label: "Rails",
    projectRoot,
    currentProject: "renamed_project",
    dockerContainers: [
      { id: "2", name: "old-web", project: "old_project", workingDir: projectRoot },
    ],
  })
  assert.equal(stale.type, "stale-container")

  const foreign = classifyPortOwner({
    port: 3000,
    label: "Rails",
    projectRoot,
    currentProject: "project",
    dockerContainers: [
      { id: "3", name: "other", project: "other_project", workingDir: "/tmp/other" },
    ],
  })
  assert.equal(foreign.type, "foreign-container")

  const process = classifyPortOwner({
    port: 3000,
    label: "Rails",
    processOwner: { pid: 999, name: "node" },
  })
  assert.equal(process.type, "process")

  assert.equal(classifyPortOwner({ port: 3000, label: "Rails" }).type, "unknown")
})

test("dockerDesktopCandidates returns platform-specific launch commands", () => {
  assert.deepEqual(dockerDesktopCandidates("darwin", {}), [
    { command: "open", args: ["-a", "Docker"] },
  ])

  const windows = dockerDesktopCandidates("win32", {
    ProgramFiles: "C:\\Program Files",
    LOCALAPPDATA: "C:\\Users\\me\\AppData\\Local",
  })

  assert.equal(windows.length, 2)
  assert.match(windows[0].command, /Docker Desktop\.exe$/)
  assert.match(windows[1].command, /Docker Desktop\.exe$/)
  assert.deepEqual(dockerDesktopCandidates("linux", {}), [
    { command: "systemctl", args: ["--user", "start", "docker"] },
  ])
  assert.deepEqual(dockerDesktopCandidates("freebsd", {}), [])
})
