fs     = require 'fs'
path   = require 'path'
util   = require 'util'
net    = require 'net'
events = require 'events'
coffee = require 'coffee-script'

EventEmitter = events.EventEmitter
warn = console.warn

parseCSON = (str) ->
  return (new Function coffee.compile "return {\n#{str.replace /^/gm, '  '}}" \
  , bare: 1)()

class FakeServer
  constructor: (@conf) ->
    EventEmitter.call @
    @scriptPath = path.normalize @conf.script
    @scriptIndex = 1
    @mode = []

    @listen = true
    @eol = @conf.eol or '\r\n'
    @port = @conf.port or 2001
    @host = @conf.host or 'localhost'
  util.inherits FakeServer, EventEmitter

  end: ->
    @socket.end()

  start: (next) ->
    @loadScript (err, script) =>
      if err
        return next err
      @script = script
      @set = @script[@scriptIndex]

      if @listen
        @conn = net.createServer @
        @conn.on 'connection', (@socket) =>

          index = 0
          while typeof @set.data[index] == 'string'
            @socket.write @set.data[index] + @eol
            index += 1

          if not @set.data[index]
            @scriptIndex += 1

          @socket.on 'data', (data) =>
            @set = @script[@scriptIndex]
            if not @set
              return @_finished()
            index = 0
            while typeof @set.data[index] == 'string'
              index += 1
            regex = @set.data[index]

            lines = data.toString().split /\n|\r\n/

            m = regex.exec lines[0]
            if not m
              msg = "Expected #{@set.name}, got #{JSON.stringify data.toString()}"
              warn 'error', msg
              @socket.write msg + @eol
              return

            index += 1
            type = typeof @set.data[index]

            if type == 'string'
              reply = @set.data.slice(index).join @eol
              i = 1
              loop
                if not m[i]
                  break
                reply = reply.replace new RegExp("\\$#{i}", 'g'), m[i]
                i += 1
            else if type == 'function'
              reply = @set.data[index].apply @, m.slice 1
            else
              reply = "What is this type: #{type}?\r\n"

            @socket.write reply + @eol

            @scriptIndex += 1
            @set = @script[@scriptIndex]
            if not @set
              return @_finished()

            warn "Next up #{@set.name}"

          @socket.on 'end', (data) =>
            warn "end"
          @socket.on 'error', (err) =>
            warn "Got error #{err.stack}"
          @socket.on 'timeout', (data) =>
            warn "timeout"
          @socket.on 'close', (data) =>
            warn "close"

        @conn.listen @port, =>
          warn "Listening to #{@host}:#{@port}"

  _finished: ->
    return @socket.end()

  loadScript: (next) ->
    fs.readFile @scriptPath, (err, data) =>
      if err
        return next err
      result = []
      set = {}

      data = data.toString().replace(/\\\n/g, '').split /\n|\r\n/g
      data.push '# end'
      headerCount = 0
      header = ''

      for line, i in data
        if /^--/.test line
          headerCount += 1
          continue
        if headerCount == 1
          header += line + "\n"
        if headerCount == 2
          break
        if headerCount == 0 and /^#/.test line
          throw new Error "Please add a conf section to top of script"

      if header.length > 0
        header = parseCSON header
        for key of header
          @[key] = header[key]

      fn = ''
      for line in data.slice i

        m = /^(#+)\s*(.+)$/.exec line
        if m
          if fn.length > 0
            jsFun = (new Function "return #{(coffee.compile fn, bare: 1) \
                                                    .replace /^\n+/, ''}")()
            if jsFun
              set.data.push jsFun
            fn = ''

          if set.data and not set.data[set.data.length - 1]
            set.data.pop()

          result.push set
          set = {
            name: m[2].replace /\s+$/g, ''
            state: m[1].length
            data: []
          }
          continue

        m = /^([<>=])\s*(.*)$/.exec line
        if m
          @mode = m

        switch @mode[1]
          when '>'
            set.data.push line.slice(2).replace \
              /(\\\\|\\x(?:[0-9A-Z]{2}){1,2})/gi,($0, $1) ->
                if $1 == '\\\\'
                  return '\\'
                String.fromCharCode parseInt $1.slice(2), 16
            @mode = ['', '>']
          when '<'
            set.data.push new RegExp @mode[2]
          when '='
            fn += (line.slice 1) + '\n'

      result.push set
      next 0, result

module.exports = FakeServer
