screen = require("component").screen

local Menu = {}
Menu.mt = {__index = Menu}

local function newMenu(data)
  if data.base then
    print("existing base")
    setmetatable(data, {__index = data.base})
  else
    setmetatable(data, Menu.mt)
  end
  if data.init then data:init() end
  return data
end

function Menu:reallyDraw(parent)
  if parent then parent:reallyDraw() end
  self:draw()
end

function Menu:run(parent)
  local curPrecise = screen.isPrecise()
  screen.setPrecise(false)
  while not self.quitting do
    self:reallyDraw(parent)
    local raw = table.pack(event.pullMultiple("key_down","touch","scroll"))
    local evType = raw[1]
    if evType == "key_down" then
      if self.keymap then
        local key = keyboard.keys[raw[4]]
        if self.keymap[key] then
          self.keymap[key].func(self)
        end
      else
        break
      end
    elseif self.miscmap and self.miscmap[evType] then
      self.miscmap[evType](self, table.unpack(raw))
    end
  end
  if self.onQuit then self:onQuit() end
  screen.setPrecise(curPrecise)
  return self.quitReturn
end

function Menu:quit(quitReturn)
  self.quitting = true
  self.quitReturn = quitReturn
end

function Menu:callSubmenu(base, data)
  data.base = base
  return newMenu(data):run(self)
end

function Menu:showHelp()
  return self:callSubmenu(helpMenu, {helpKeys = self.keymap})
end

local helpMenu = newMenu{
  draw = function(self)
    if not self.helpLines then
      self.helpLines = {}
      self.longestHelp = 0
      for k, v in pairs(self.helpKeys) do
        if v.help then
          local line = ("[%s] %s"):format(k, v.help)
          self.longestHelp = math.max(self.longestHelp, #line)
          table.insert(self.helpLines, line)
        end
      end
    end

    local w, h = self.longestHelp + 4, #self.helpLines + 4
    local x1, y1 = 1+math.floor((scWidth - w)/2),1+math.floor((scHeight - h)/2)
    local function drawLine(x, y, st)
      term.setCursor(x, y)
      io.write(st)
    end

    drawLine(x1, y1,   "+" .. charLine("-",w-2) .. "+")
    drawLine(x1, y1+1, "|" .. charLine(" ",w-2) .. "|")

    for k, v in pairs(self.helpLines) do
      drawLine(x1, y1+1+k, "| " .. v .. charLine(" ",w-3-#v) .. "|")
    end

    drawLine(x1, y1+h-2, "|" .. charLine(" ",w-2) .. "|")
    drawLine(x1, y1+h-1, "+" .. charLine("-",w-2) .. "+")
  end,
}


return {
  Menu = Menu,
  newMenu = newMenu,
}
