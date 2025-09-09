screen = require("component").screen
keyboard = require("keyboard")
event = require("event")

local function charLine(c, len)
  local st = ""
  for i = 1,len do
    st = st .. c
  end
  return st
end

local Menu = {}
Menu.mt = {__index = Menu}

local function newMenu(data)
  if data.base then
    setmetatable(data, {__index = data.base})
    if data.base.keymap and data.keymap then
      -- could do setmetatable, but we need pairs() to show ALL the keys for
      -- the help screen
      local newKeymap = {}
      for k, v in pairs(data.base.keymap) do
        newKeymap[k] = v
      end
      for k, v in pairs(data.keymap) do
        newKeymap[k] = v
      end
      data.keymap = newKeymap
    end
  else
    setmetatable(data, Menu.mt)
  end

  if data.init then data:init() end
  return data
end

function Menu:reallyDraw(parent)
  if parent then parent:reallyDraw() end
  if self.draw then
    self:draw()
  else
    term.reset()
    io.stderr:write("either 'draw' is undefined or something has gone horribly wrong.")
  end
  if self.status then
    term.setCursor(1, scHeight)
    io.write("\x1B[7m")
    for i = 1,scWidth do
      io.write(" ")
    end
    io.write("\x1B[0m")
    term.setCursor(1, scHeight)

    io.write("\x1B[7m"..self.status.."\x1B[0m")
    self.status = ""
  end
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

function Menu:showHelp()
  return self:callSubmenu(helpMenu, {helpKeys = self.keymap})
end

listMenu = newMenu{
  init = function(self)
    self.scrollPos = 1
    self.cursorPos = 1
  end,
  draw = function(self)
    term.clear()
    for i = 1, scHeight-1 do
      local realI = i+self.scrollPos-1
      local item = self.items[realI]
      if not item then break end
      term.setCursor(1, i)
      io.write((self.cursorPos == realI) and "\x1B[7m" or "")
      io.write(item.text)
      io.write(charLine(" ", scWidth-#item.text).. "\x1B[0m")
    end
    if self.items[self.cursorPos].desc then
      self.status = self.items[self.cursorPos].desc
    end
  end,
  moveCursor = function(self, delta)
    self:setCursor(self.cursorPos + delta)
  end,
  setCursor = function(self, pos)
    local lastPos = self.cursorPos
    self.cursorPos = math.max(1, math.min(pos, #self.items))
    if self.cursorPos < self.scrollPos or self.cursorPos >= self.scrollPos+scHeight-1 then
      self.scrollPos = math.max(1, self.scrollPos + (self.cursorPos - lastPos))
    end
  end,
  selectItem = function(self)
    if self.onSelect then
      return self:onSelect(self.items[self.cursorPos])
    else
      self:quit(self.items[cursorPos])
    end
  end,
  keymap = {
    q = {
      help = "Quit",
      func = Menu.quit
    },
    enter = {
      help = "Select item",
      func = function(self)
        self:selectItem()
      end
    },
    up = {
      func = function(self)
        self:moveCursor(-1)
      end
    },
    down = {
      func = function(self)
        self:moveCursor(1)
      end
    },
    pageUp = {
      func = function(self)
        self:moveCursor(-(scHeight-1))
      end
    },
    pageDown = {
      func = function(self)
        self:moveCursor(scHeight-1)
      end
    },
    home = {
      func = function(self)
        self:setCursor(1)
      end
    },
    ["end"] = {
      func = function(self)
        self:setCursor(#self.items)
      end
    }
  }
}


return {
  Menu = Menu,
  newMenu = newMenu,
  listMenu = listMenu,
  charLine = charLine
}
