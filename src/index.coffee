fs = require 'fs'
fs.path = require 'path'
{exec} = require 'child_process'
http = require 'http'
connect = require 'connect'
open = require 'open'
program = require 'commander'
connect = require 'connect'
WebSocketServer = (require 'ws').Server
_ = require 'underscore'


program
    .version('0.1.0')
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
    .option '-t, --target', 
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


app = connect()
app.use (require 'connect-livereload')() if program.inject
app.use (require 'serve-index') serveRoot
app.use (require 'serve-static') serveRoot

socketApp = connect()
socketApp.use (require 'serve-static') vendorRoot

handshake = 
    command: 'hello'
    serverName: 'serve-cli 0.1.0'
    protocols: [
        'http://livereload.com/protocols/official-7'
    ]

livereload = (server) ->
    webSocketServer = new WebSocketServer {server}
    console.log "Live reloader listening on port 35729"

    livereload.sockets = []
    webSocketServer.on 'connection', (socket) ->
        livereload.sockets.push socket
        livereload.sockets = _.where livereload.sockets, readyState: 1

        socket.on 'message', (body) ->
            message = JSON.parse body
            switch message.command
                when 'hello'
                    socket.send JSON.stringify handshake
                when 'info'
                else
                    throw new Error "Unrecognized message command: #{message.command}"

    fs.watch watchRoot, (event, filename) ->
        console.log filename, event

        reload = (path) ->
            if program.verbose
                console.log "reloading for #{path}"

            for socket in livereload.sockets
                socket.send JSON.stringify \
                    command: 'reload', 
                    path: path

        if program.exec or program.target
            command = program.exec or "make #{program.target}"
            exec command, (err, stdout, stderr) ->
                console.log stdout
                reload filename
        else
            reload filename


if program.reload
    socketServer = http.createServer socketApp
    livereload socketServer
    socketServer.listen 35729

server = http.createServer app
server.listen program.port, (err) ->
    console.log "File server listening on port #{program.port}"
    if program.open
        open "http://localhost:#{program.port}/"

