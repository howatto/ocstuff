local rpc = require("rpc")

-- stolen from stackoverflow
local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function tableSlice(t, start, stop)
  local res = {}
  stop = stop or #t
  for i=start,stop do
    table.insert(res, t[i])
  end
  return res
end

local function parseArg(s)
  if string.match(s, "^%d") then
    return tonumber(s) or s
  elseif s=="true" then return true
  elseif s=="false" then return false
  else return s end
end

local function map(t, f)
  local res = {}
  for _, i in ipairs(t) do
    table.insert(res, f(i))
  end
  return res
end

local function parseURI(uri)
  local res = {}
  local scheme, prePath = string.gmatch(uri, "([%w%-]+)://(.+)")()
  res.scheme = scheme
  local path, preQuery = table.unpack(split(prePath, "%?"))
  res.path = path

  local query = preQuery and split(preQuery, "&") or ""
  res.query = {}
  for _, i in ipairs(query) do
    local k, v = table.unpack(split(i, "="))
    res.query[k] = parseArg(v)
  end

  local pathSplit = split(path, "/")

  local authority = pathSplit[1]
  local userInfo, preHost = table.unpack(split(authority, "@"))
  res.host, res.port = table.unpack(split(preHost, ":"))
  res.user, res.pass = table.unpack(split(userInfo, ":"))
  res.func = pathSplit[2]
  res.args = map(tableSlice(pathSplit, 3), parseArg)

  return res
end

local uriHandlers = {
  rpc = function(u)
    return rpc.call(u.host, u.func, table.unpack(u.args))
  end
}

return {callURI = function(uri)
          local u = parseURI(uri)
          if string.match(u.scheme, "^rpc%-%w+$") then
            local prefix = split(u.scheme, "%-")[2]
            return rpc.call(u.host, string.format("%s_%s", prefix, u.func), table.unpack(u.args))
          elseif uriHandlers[u.scheme] then
            return uriHandlers[u.scheme](u)
          end
          return nil, string.format("unknown uri scheme \"%s\"", u.scheme)
end,
        parseURI = parseURI
}
