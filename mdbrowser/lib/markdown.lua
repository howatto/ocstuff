local gpu = require("component").gpu

-- stolen from stackoverflow then generalized a bit
local function splitGen(st, match)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(st, match) do
    table.insert(t, str)
  end
  return t
end

local function split(st, sep)
  return splitGen(st, "([^"..sep.."]+)")
end

local function splitLines(st)
  return splitGen(st, "(.-)\n")
end

local function trim(st)
  return st:gsub("^%s+", ""):gsub("%s+$", "")
end

local function charLine(c, len)
  local st = ""
  for i = 1,len do
    st = st .. c
  end
  return st
end

local blockHooks = {
  -- h2 (yeah. lua's dogass pattern matching doesn't allow for ^ so i gotta do
  -- it in reverse.)
  {pattern = "## (.*)",
   process = function(s)
     return {s, charLine("-", #s)}
   end,
   newline = true
  },
  -- h1
  {pattern = "# (.*)",
   process = function(s)
     return {s, charLine("=", #s)}
   end,
   newline = true
  }
}

local IHOOK_SKIP = 0

local inlineHooks = {
  -- hyperlinks. that's it. (god this pattern looks ass)
  {
    pattern = "%[([^%]]+)%]%(([^%)]+)%)",
    process = function(text, uri)
      return {
        text = (gpu.getDepth() > 1) and text or '[['..text..']]',
        href = uri
      }
    end
  }
}

-- rendoc (n.) renderable document. or maybe rendered document. i don't care, i
-- thought it up in like a second
local Rendoc = {}
Rendoc.mt = {__index = Rendoc}

local function newRendoc()
  return setmetatable({}, Rendoc.mt)
end

local function makeRendoc(rawText)
  -- juryrig to fix splitLines
  if rawText:sub(#rawText) ~= "\n" then rawText = rawText.."\n" end

  -- pass 1: turn each line into one or more blox0rz
  -- (hey remember that flash game?)
  local blocks = {}
  local lastLine
  for _, l in ipairs(splitLines(rawText)) do
    local foundHook = false

    for hIdx, hook in ipairs(blockHooks) do
      if l:find(hook.pattern) then
        foundHook = true
        if lastLine and lastLine ~= "" and hook.newline then
          table.insert(blocks, { text = "" })
        end

        for _, toAdd in ipairs(hook.process(l:gmatch(hook.pattern)())) do
          table.insert(blocks, type(toAdd)=="string" and { text = toAdd } or toAdd )
        end

        break
      end
    end
    if not foundHook then
      table.insert(blocks, { text = trim(l) })
    end

    lastLine = trim(l)
  end

  -- pass 2: parse markdown within blocks
  local rendoc = newRendoc()
  for _, block in pairs(blocks) do
    -- yes, i know this needs to be rewritten to work with multiple inline hooks.
    -- no, i don't care.
    for hIdx, hook in ipairs(inlineHooks) do
      local pos = 1
      local procLine = {}
      local function addPreSeg(hookID, a, b)
        table.insert(procLine, {hookID, trim(block.text:sub(a, b))})
      end

      -- subpass 1: split it up
      repeat
        local start, stop = string.find(block.text, hook.pattern, pos)

        if start then
          addPreSeg(IHOOK_SKIP, pos, start-1)
          addPreSeg(hIdx, start, stop)
          pos = stop+1
        else
          addPreSeg(IHOOK_SKIP, pos, #block.text)
        end

      until start == nil

      -- subpass 2: k now actually process, yanno?
      for plIdx, seg in ipairs(procLine) do
        local hookID, segText = table.unpack(seg)
        local hookData = inlineHooks[hookID]

        if hookID == IHOOK_SKIP then
          procLine[plIdx] = {text = segText}
        else
          procLine[plIdx] = hookData.process(segText:match(hookData.pattern))
        end
      end

      table.insert(rendoc, procLine)
    end
  end

  return rendoc
end

-- now we got something we can technically render. but for extra (i.e. any)
-- readability we gotta reflow this, don't we?
--
-- use this copy of the rendoc for rendering only. keep the original in memory
-- to reflow whenever needed (e.g. after a change in screen/window size).
function Rendoc:reflow(width)
  width = width or gpu.getResolution()
  -- basically use a seg as a template to create a new one
  local function newSeg(basis)
    local res = {}
    for k, v in pairs(basis) do
      res[k] = v
    end
    res.text = ""
    return res
  end

  local newDoc = newRendoc()

  for _, block in ipairs(self) do
    local workBlock
    local workBlockLen

    local function initWorkBlock()
      workBlock = {}
      workBlockLen = 0
    end

    initWorkBlock()

    for _, seg in ipairs(block) do
      local segWords = split(seg.text, "%s")
      local workSeg -- = newSeg(seg)
      local function initWorkSeg()
        workSeg = newSeg(seg)
        workSeg.lower = workBlockLen + (#workBlock > 0 and 2 or 1)
      end

      local function finishWorkSeg()
        workSeg.upper = workSeg.lower + #workSeg.text - 1
        table.insert(workBlock, workSeg)
      end

      initWorkSeg()

      local function append(w)
        -- only prepend space if seg length > 0.
        -- only raise block length by word length+1 if block length > 0.
        -- i don't know why i kept this comment afterward but hey. maybe i'll
        -- need it later.
        local toAppend = (#workSeg.text > 0 and ' ' or '') .. w
        local toIncrease = (workBlockLen > 0 and 1 or 0) + #w
        if workBlockLen + toIncrease >= width then
          -- we gotta make a new block.
          --table.insert(workBlock, workSeg)
          finishWorkSeg()
          --workSeg = newSeg(seg)
          initWorkSeg()

          table.insert(newDoc, workBlock)
          initWorkBlock()

          append(w)
        else
          workSeg.text = workSeg.text .. toAppend
          workBlockLen = workBlockLen + toIncrease
        end
      end

      for _, word in ipairs(segWords) do
        append(word)
      end

      --table.insert(workBlock, workSeg)
      finishWorkSeg()
    end

    table.insert(newDoc, workBlock)
  end
  return newDoc
end

function Rendoc:debugDraw()
  for _, block in ipairs(self) do
    local workBlock = {}
    local workBlockLen = 0

    for _, seg in ipairs(block) do
      io.write("[\"" .. seg.text .. "\"] ")
    end

    io.write("\n")
  end
end

function Rendoc:renderLines(start, height)
  start = start or 1
  height = height or #self

  local linkCode = (gpu.getDepth() > 1) and "\x1B[36m" or "\x1B[7m"

  local res = {}
  for i = start,start+height-1 do
    local block = self[i]
    if block then
      local line = ""
      for j, seg in ipairs(block) do
        local render = seg.text
        if seg.href then render = linkCode .. render .. "\x1B[0m" end
        render = (j>1 and " " or "") .. render
        line = line .. render
      end
      table.insert(res, line)
    else
      break
    end
  end

  return res
end

function Rendoc:draw(start, height)
  local lines = self:renderLines(start, height)

  for _, line in ipairs(lines) do
    print(line)
  end
end

return {
  makeRendoc = makeRendoc
}
