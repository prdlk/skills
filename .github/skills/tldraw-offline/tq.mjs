#!/usr/bin/env node
// <!-- installed-by:tldraw-desktop-agent-skills -->
// tq — tldraw agent-api helper. Usage:
//   node tq.mjs GET  /api/doc/DOC/script-status
//   node tq.mjs POST /api/search '{"code":"return await api.getDocs()"}'             # JSON body
//   node tq.mjs POST /api/doc/DOC/exec 'return editor.getCurrentPageShapes().length' # raw JS body
import fs from 'node:fs'
import http from 'node:http'
import os from 'node:os'


// -- CommonJS Shims --
import __cjs_mod__ from 'node:module';
const __filename = import.meta.filename;
const __dirname = import.meta.dirname;
const require = __cjs_mod__.createRequire(import.meta.url);
const serverJsonPath = expandLeadingEnvVar("/home/prad/.config/tldraw/server.json")

// The embedded path can be one of the env-var defaults ($HOME/…, $APPDATA/…)
// rather than a concrete path, and node does no shell expansion — without this
// the read looks for a literal directory named "$HOME".
function expandLeadingEnvVar(p) {
	const slash = p.indexOf('/')
	if (!p.startsWith('$') || slash === -1) return p
	const name = p.slice(1, slash)
	const value = process.env[name] ?? (name === 'HOME' ? os.homedir() : null)
	return value === null ? p : value + p.slice(slash)
}

function readServerJson() {
	try {
		return JSON.parse(fs.readFileSync(serverJsonPath, 'utf8'))
	} catch {
		return null
	}
}

const [method, requestPath, body] = process.argv.slice(2)
const server = readServerJson()
if (!server?.port || !server?.token) {
	console.error(`tq: cannot read ${serverJsonPath} — the tldraw desktop app is not running`)
	process.exit(1)
}

const headers = { authorization: `Bearer ${server.token}` }
if (body) headers['content-type'] = body.startsWith('{') ? 'application/json' : 'text/plain'

// 127.0.0.1 rather than localhost, which resolves to ::1 first on Windows while
// the server binds IPv4 only.
const req = http.request(
	{ host: '127.0.0.1', port: server.port, path: requestPath, method, headers },
	(res) => res.pipe(process.stdout)
)
req.on('error', (err) => {
	console.error(`tq: ${err.message}`)
	process.exitCode = 1
})
req.end(body || undefined)
