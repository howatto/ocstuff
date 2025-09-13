component = require("component")
screen = component.screen
gpu = component.gpu
keyboard = require("keyboard")
event = require("event")

local scWidth, scHeight = gpu.getResolution()

local function map(t, f)
  local res = {}
  for k, v in pairs(t) do
    table.insert(res, f(v))
  end
  return res
end

local function charLine(c, len)
  local st = ""
  for i = 1,len do
    st = st .. c
  end
  return st
end

local function tabulate(spacing, items)
  local i = 0
  local formatSt = table.concat(map(spacing, function(item)
                                      i = i+1
                                      return ("%%%ds"):format(spacing[i])
                                   end), " ")
  i = 0
  return formatSt:format(table.unpack(map(items, function(x)
                                            i = i+1
                                            return tostring(x):sub(1, math.abs(spacing[i]))
  end)))
end

local Menu = {
  x = 1, y = 1
}
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

function Menu:getPos()
  return self.x, self.y + (self.showHeader and 1 or 0)
end

function Menu:getSize()
  local w, h = gpu.getResolution()
  return w, h - ((self.showStatus and 1 or 0) + (self.showHeader and 1 or 0))
end

function Menu:getHeight()
  local w, h = self:getSize()
  return h
end

function Menu:drawText(xOfs, yOfs, st)
  local x, y = self:getPos()
  term.setCursor(x+xOfs-1, y+yOfs-1)
  io.write(st)
end

function Menu:drawBox(x, y, w, h)
  self:drawText(x, y,   "\u{250c}" .. charLine("\u{2500}",w-2) .. "\u{2510}")

  for i=1,h-2 do
    self:drawText(x, y+i, "\u{2502}" .. charLine(" ",w-2) .. "\u{2502}")
  end

  self:drawText(x, y+h-1, "\u{2514}" .. charLine("\u{2500}",w-2) .. "\u{2518}")
end

function Menu:drawInverseLine(y, text)
  term.setCursor(1, y)
  io.write("\x1B[7m")
  for i = 1,scWidth do
    io.write(" ")
  end
  io.write("\x1B[0m")
  term.setCursor(1, y)
  io.write("\x1B[7m"..text.."\x1B[0m")
end

function Menu:reallyDraw(parent)
  if parent then parent:reallyDraw() end
  if self.draw then
    self:draw()
  else
    term.reset()
    io.stderr:write("either 'draw' is undefined or something has gone horribly wrong.")
  end
  if self.showHeader then
    self:drawInverseLine(1, self.header or "")
  end
  if self.showStatus then
    self:drawInverseLine(scHeight, self.status or "")
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

    self:drawBox(x1, y1, w, h)

    for k, v in pairs(self.helpLines) do
      self:drawText(x1+2, y1+1+k, v)
    end

  end,
}

function Menu:showHelp()
  return self:callSubmenu(helpMenu, {helpKeys = self.keymap})
end

listMenu = newMenu{
  showStatus = true,
  init = function(self)
    self.scrollPos = 1
    self.cursorPos = 1
    if not self.items then self.items = {} end
  end,
  draw = function(self)
    term.clear()
    if #self.items > 0 then
      for i = 1, self:getHeight() do
        local realI = i+self.scrollPos-1
        local item = self.items[realI]
        if not item then break end
        self:drawText(1, i, (self.cursorPos == realI) and "\x1B[7m" or "")
        local text = self:itemText(item)
        io.write(text)
        io.write(charLine(" ", scWidth-#text).. "\x1B[0m")
      end
      local desc = self:descText(self.items[self.cursorPos])
      if desc then
        self.status = desc
      end
    end
  end,
  itemText = function(self, item)
    return item.text
  end,
  descText = function(self, item)
    return item.desc
  end,
  moveCursor = function(self, delta)
    self:setCursor(self.cursorPos + delta)
  end,
  setCursor = function(self, pos)
    local lastPos = self.cursorPos
    self.cursorPos = math.max(1, math.min(pos, #self.items))
    if self.cursorPos < self.scrollPos or self.cursorPos >= self.scrollPos+self:getHeight() then
      self.scrollPos = math.max(1, self.scrollPos + (self.cursorPos - lastPos))
    end
  end,
  selectItem = function(self)
    if #self.items == 0 then return end
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
        self:moveCursor(-self:getHeight())
      end
    },
    pageDown = {
      func = function(self)
        self:moveCursor(self:getHeight())
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
  charLine = charLine,
  tabulate = tabulate
}
