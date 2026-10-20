"use strict"

const assert = require("node:assert/strict")
const http = require("node:http")
const { after, before, test } = require("node:test")

const { isAppUrl, waitForApp } = require("../lib")

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

test("isAppUrl accepts URLs on the same origin", () => {
  assert.equal(isAppUrl(baseUrl, `${baseUrl}/users/sign_in`), true)
})

test("isAppUrl rejects other origins and invalid URLs", () => {
  assert.equal(isAppUrl(baseUrl, "https://example.com"), false)
  assert.equal(isAppUrl(baseUrl, "http://127.0.0.1:1"), false)
  assert.equal(isAppUrl(baseUrl, "not a url"), false)
})

test("waitForApp resolves once the server responds", async () => {
  await waitForApp(baseUrl, { timeout: 2_000, interval: 50 })
})

test("waitForApp rejects when nothing is listening", async () => {
  await assert.rejects(
    waitForApp("http://127.0.0.1:1", { timeout: 300, interval: 50 }),
    /не відповів/
  )
})
