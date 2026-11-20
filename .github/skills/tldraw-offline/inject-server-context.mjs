#!/usr/bin/env node
// <!-- installed-by:tldraw-desktop-agent-skills -->
// Injects the running tldraw desktop canvas server's base URL + auth token as hook
// additionalContext. Prints nothing when the app is not running.
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

const event = process.argv[2] || 'SubagentStart'
const server = readServerJson()
if (!server?.port || !server?.token) process.exit(0)

const { port, token } = server
let context = `The tldraw desktop canvas server is running at http://localhost:${port}. Send the header 'Authorization: Bearer ${token}' on every request except GET / and /readme. Use these values directly — you do not need to read server.json.`

const docs = await getOpenDocs()
if (docs) {
	context += `

The user's currently open tldraw office canvases (most-recently-active first): ${docs}`
}

process.stdout.write(
	JSON.stringify({ hookSpecificOutput: { hookEventName: event, additionalContext: context } })
)

// Snapshot the open documents so the agent starts knowing what canvases exist.
// Best-effort: a dead server, a stale port, or a slow response must not delay or
// fail the subagent launch. 127.0.0.1 rather than localhost, which resolves to
// ::1 first on Windows while the server binds IPv4 only.
function getOpenDocs() {
	return new Promise((resolve) => {
		try {
			const req = http.request(
				{
					host: '127.0.0.1',
					port,
					path: '/api/search',
					method: 'POST',
					headers: { 'content-type': 'text/plain', authorization: `Bearer ${token}` },
				},
				(res) => {
					let body = ''
					res.setEncoding('utf8')
					res.on('data', (chunk) => (body += chunk))
					res.on('end', () => {
						try {
							const result = JSON.parse(body).result
							resolve(Array.isArray(result) && result.length > 0 ? JSON.stringify(result) : null)
						} catch {
							resolve(null)
						}
					})
				}
			)
			req.setTimeout(2000, () => {
				req.destroy()
				resolve(null)
			})
			req.on('error', () => resolve(null))
			req.end('return await api.getDocs()')
		} catch {
			resolve(null)
		}
	})
}
