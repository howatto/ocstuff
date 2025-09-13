markdown = require("markdown")
uri = require("uri")
mei = require("mei")
keyboard = require("keyboard")
event = require("event")
gpu = require("component").gpu
term = require("term")

local function charLine(c, len)
  local st = ""
  for i = 1,len do
    st = st .. c
  end
  return st
end

local linkFinderMenu = mei.newMenu{
  init = function(self)
    if self.links then
      self.keyNums = {}
      for i = 1, 10 do
        if not self.links[i] then break end
        local key = tostring(i % 10)
        table.insert(self.keyNums, key)
        if not self.keymap then self.keymap = {} end
        self.keymap[key] = {
          func = function(self)
            self:quit(self.links[i].href)
          end
        }
      end
    end
  end,
  draw = function(self)
    for i, link in ipairs(self.links) do
      if not self.keyNums[i] then break end
      self:drawText(link.x, link.y, ("\x1B[7m[%s]\x1B[0m"):format(self.keyNums[i]))
    end
  end,
  keymap = {
    q = {
      help = "Quit",
      func = mei.Menu.quit
    }
  }
}

local browserMenu = mei.newMenu{
  showStatus = true,
  init = function(self)
    if self.rendoc then
      self.flowed = self.rendoc:reflow()
      self.scrollPos = 1
      self.status = "Press 'h' for help."
    end
  end,
  draw = function(self)
    term.clear()
    local lines = self.flowed:renderLines(self.scrollPos, self:getHeight())
    for k, v in ipairs(lines) do
      self:drawText(1, k, v)
    end
  end,
  onQuit = function(self)
    term.clear()
  end,
  loadNew = function(self, data)
    self.rendoc = markdown.makeRendoc(data)
    self.flowed = self.rendoc:reflow()
  end,
  scroll = function(self, d)
    self.scrollPos = math.max(1, math.min(self.scrollPos + d, #self.flowed))
  end,
  followLink = function(self, link)
    local parsed = uri.parseURI(link)
    if self.schemes then
      if self.schemes[parsed.scheme] then
        return self.schemes[parsed.scheme](self, parsed)
      else
        return self.schemes[false] and self.schemes[false](self, parsed)
      end
    end
    --self.status = ("Following %s"):format(link)
    if self.onLink then
      return self:onLink(link)
    end
  end,
  keymap = {
    q = {
      help = "Quit",
      func = mei.Menu.quit
    },
    h = {
      help = "Show this window",
      func = mei.Menu.showHelp
    },
    f = {
      help = "Label links",
      func = function(self)
        -- aaaghsdfgfhg izzy why did you even suggest thiiiiiiiiiis
        local prevHref
        local links = {}
        for y = 1,self:getHeight() do
          local curLine = self.flowed[y + (self.scrollPos - 1)]
          if not curLine then break end
          for _, seg in ipairs(curLine) do
            if seg.href and seg.href ~= prevHref then
              local link = {
                x = seg.lower,
                y = y,
                href = seg.href
              }
              table.insert(links, link)
            end
            prevHref = seg.href
          end
        end
        if #links > 0 then
          self.status = "[0-9] Select link [q] Quit"
          local result = self:callSubmenu(linkFinderMenu, {links = links})
          if result then self:followLink(result) end
        else
          self.status = "No links in view"
        end
      end
    },
    up = {
      func = function(self)
        self:scroll(-1)
      end
    },
    down = {
      func = function(self)
        self:scroll(1)
      end
    },
    pageUp = {
      func = function(self)
        self:scroll(-self:getHeight())
      end
    },
    pageDown = {
      func = function(self)
        self:scroll(self:getHeight())
      end
    },
  },
  miscmap = {
    scroll = function(self, name, screen, x, y, dir)
      self:scroll(-dir*5)
    end,
    touch = function(self, name, screen, x, y, button)
      local lineClicked = y + (self.scrollPos - 1)
      local line = self.flowed[lineClicked]
      local boxes = {}
      local segClicked = nil
      for _, seg in ipairs(line) do
        if x < seg.lower then break end

        if x >= seg.lower and x <= seg.upper then
          segClicked = seg
          break
        end
      end

      if (segClicked and segClicked.href) then
        self:followLink(segClicked.href)
      end
    end
  }
}

local function runBrowser(data)
  local menuData = {
    base = browserMenu,
    keymap = data.keymap,
    onLink = data.onLink,
    rendoc = markdown.makeRendoc(data.markdown),
    schemes = data.schemes
  }
  --[[
  -- keybinds
  for k, v in pairs(browserMenu.keymap) do
    menuData.keymap[k] = v
  end
  if data.keymap then
    for k, v in pairs(data.keymap) do
      menuData.keymap[k] = v
    end
  end
  ]]--

  local function listMT(t)
    local idx = getmetatable(t).__index
    print("mt itself", idx)
    for k, v in pairs(idx) do
      --print(k, v)
    end
  end
  local m = mei.newMenu(menuData)

  m:run()

end

return {
  runBrowser = runBrowser
}
