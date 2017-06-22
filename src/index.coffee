fs = require 'fs'
fs.path = require 'path'
{exec} = require 'child_process'
http = require 'http'
connect = require 'connect'
open = require 'open'
colors = require 'colors'
program = require 'commander'
connect = require 'connect'
ws = require 'ws'
WebSocketServer = ws.Server
_ = require 'underscore'


program
    .version('0.2.0')
    .usage '[directory] [options]'
    .option '-p, --port <n>',
        'The port on which to serve [3000]', parseInt, 3000
    .option '-w, --watch [directory]',
        'The directory to watch for changes (defaults to the directory being served)'
    .option '-r, --reload',
        'Enable live reloading'
    .option '-i, --inject',
        'Inject the live reload script into HTML (obviating the need for a live reloading browser plugin)'
    .option '-e, --exec',
        'The command to execute when the watched directory has changed'
    .option '-t, --target [target]',
        'The make target to execute when the watched directory has changed [all]', 'all'
    .option '-o, --open',
        'Launch a web browser and point it to the served directory'
    .option '-v, --verbose',
        'Be more verbose'
    .parse process.argv


here = _.partial fs.path.join, process.cwd()
serveRoot = here program.args[0] or '.'
watchRoot = here (if program.watch is true then '.' else program.watch or program.args[0])
vendorRoot = fs.path.join __dirname, '../vendor'
hasMakefile = here 'Makefile'

if program.watch and serveRoot is watchRoot
    throw new Error 'Cannot watch the same directory to which we build'

app = connect()
app.use (require 'connect-livereload')() if program.inject
app.use (require 'serve-index') serveRoot
app.use (require 'serve-static') serveRoot

socketApp = connect()
socketApp.use (require 'serve-static') vendorRoot

handshake =
    command: 'hello'
    serverName: 'serve-cli 0.2.0'
    protocols: [
        'http://livereload.com/protocols/official-7'
    ]

noop = ->

isBroken = no

rebuild = (done=noop) ->
    command = program.exec or "make #{program.target}"
    exec command, (err, stdout, stderr) ->
        wasBroken = isBroken and not stderr
        if program.verbose or wasBroken
            isBroken = no
            if wasBroken
                console.info stdout.green
            else
                console.info stdout
        if stderr
            isBroken = yes
            console.error stderr.red
        done err

livereload = (server) ->
    webSocketServer = new WebSocketServer {server}
    console.log "Live reloader listening on port 35729"

    livereload.clients = []
    webSocketServer.on 'connection', (client) ->
        livereload.clients.push client

        client.on 'message', (body) ->
            message = JSON.parse body
            switch message.command
                when 'hello'
                    client.send JSON.stringify handshake
                when 'info'
                else
                    throw new Error "Unrecognized message command: #{message.command}"

    fs.watch watchRoot, (event, filename) ->
        reload = (path) ->
            if program.verbose
                console.log "reloading for #{path}"

            # FIXME: `path` is supposed to be the rendered path,
            # not the original file (e.g. `test.html` instead of `test.pug`)
            for client in livereload.clients
                switch client.readyState
                    when 0
                        break
                    when 1
                        message =
                            command: 'reload'
                            path: path
                        client.send JSON.stringify message
                    when 2, 3
                        client.terminate()

        if program.exec or program.target
            rebuild -> reload filename
        else
            reload filename


if program.exec or program.target
    rebuild()

if program.reload
    socketServer = http.createServer socketApp
    livereload socketServer
    socketServer.listen 35729

server = http.createServer app
server.listen program.port, (err) ->
    console.log "File server listening on port #{program.port}"
    if program.open
        open "http://localhost:#{program.port}/"
