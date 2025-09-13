markdown = require("markdown")
mdbrowser = require("mdbrowser")
keyboard = require("keyboard")
event = require("event")
gpu = require("component").gpu
term = require("term")
shell = require("shell")

args = table.pack(...)

if args[1] then
  local file, err, code = io.open(args[1], "r")
  if file then
    text = file:read("*all")
  else
    io.stderr:write(("could not open %s (%s)\n"):format(args[1], err))
    os.exit(code)
  end
else
  text = io.read("*all")
end

mdbrowser.runBrowser{
    markdown = text,
    onLink = function(self, uri)
      if uri:find("://") then
        local success, err = os.execute("uri-open " .. uri)
        if not success then
          self.status = ("Error opening URI: %s"):format(err)
        end
      else
        -- must be a file. what else could it be.
        local f, err = io.open(uri, "r")
        if f then
          self:loadNew(f:read("*all"))
        else
          self.status = ("Error opening %s: %s"):format(uri, err)
        end
      end
    end
}
