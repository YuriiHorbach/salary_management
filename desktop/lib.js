"use strict"

const http = require("node:http")

function isAppUrl(appUrl, candidate) {
  try {
    return new URL(candidate).origin === new URL(appUrl).origin
  } catch {
    return false
  }
}

function waitForApp(appUrl, { timeout = 120_000, interval = 1_000 } = {}) {
  const startedAt = Date.now()

  return new Promise((resolve, reject) => {
    const attempt = () => {
      const request = http.get(appUrl, (response) => {
        response.resume()
        resolve()
      })

      request.setTimeout(2_000, () => request.destroy())
      request.on("error", () => {
        if (Date.now() - startedAt >= timeout) {
          reject(new Error("Застосунок не відповів вчасно. Перевір логи: docker compose logs web"))
        } else {
          setTimeout(attempt, interval)
        }
      })
    }

    attempt()
  })
}

module.exports = { isAppUrl, waitForApp }
