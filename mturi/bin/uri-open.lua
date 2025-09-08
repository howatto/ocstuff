uri = require("uri")
serialization = require("serialization")
shell = require("shell")
CONF_FILENAME = "/etc/uri-open.cfg"
confFile = io.open(CONF_FILENAME, "r")
config = confFile and serialization.unserialize(confFile:read("*all")) or {
  handlers = {}
}
if confFile then confFile:close() end

function err(st)
  io.stderr:write(st.."\n")
  os.exit(1)
end

args = table.pack(...)
if #args == 0 then
  err("no uri specified")
end

function writeConfig()
  confFile = io.open(CONF_FILENAME, "w")
  confFile:write(serialization.serialize(config))
  confFile:close()
end

if args[1]:find("^%-%-") then
  funcs = {
    add = function()
      config.handlers[args[2]] = args[3]
      writeConfig()
    end,
    remove = function()
      config.handlers[args[2]] = nil
      writeConfig()
    end
  }
  cmd = funcs[args[1]:sub(3)]
  if cmd then
    cmd()
  else
    err("unknown option " .. args[1])
  end
else
  parsed = uri.parseURI(args[1])
  if config.handlers[parsed.scheme] then
    shell.execute(config.handlers[parsed.scheme] .. " " .. args[1])
  else
    err("no handler for scheme "..parsed.scheme)
  end
end
