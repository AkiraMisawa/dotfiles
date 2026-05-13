-- Aggregate values from the selected files of every yazi tab and put
-- the result on the system clipboard (one per line).
--
-- Modes (positional arg, default "path"):
--   path      full path
--   dirname   parent directory
--   filename  basename
--   noext     basename without extension

local function transform(url, mode)
  local s = tostring(url)
  if mode == "dirname" then
    return s:match("^(.*)/[^/]+$") or s
  elseif mode == "filename" then
    return s:match("([^/]+)$") or s
  elseif mode == "noext" then
    local name = s:match("([^/]+)$") or s
    return name:match("^(.+)%.[^.]+$") or name
  end
  return s
end

-- POSIX shell quoting so the clipboard payload can be pasted after a
-- command (`delta <paste>`, `cat <paste>`, ...) even when paths
-- contain spaces or quotes.
local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- UI state (cx.tabs, tab.selected) can only be touched inside a sync
-- block, so collect everything we need here and return plain Lua
-- values to the async entry below.
local collect = ya.sync(function(_, mode)
  local items = {}
  local tab_count = #cx.tabs
  for i = 1, tab_count do
    local tab = cx.tabs[i]
    if tab and tab.selected then
      for _, url in pairs(tab.selected) do
        table.insert(items, transform(url, mode))
      end
    end
  end
  return items, tab_count
end)

return {
  entry = function(_, job)
    local mode = (job and job.args and job.args[1]) or "path"
    local items, tab_count = collect(mode)

    if #items == 0 then
      ya.notify {
        title   = "copy-across-tabs",
        content = ("Nothing selected across %d tab(s)"):format(tab_count),
        level   = "warn",
        timeout = 3,
      }
      return
    end

    local quoted = {}
    for i, item in ipairs(items) do
      quoted[i] = shell_quote(item)
    end
    ya.clipboard(table.concat(quoted, " "))
    ya.notify {
      title   = "copy-across-tabs",
      content = ("Copied %d %s(s) from %d tab(s)"):format(#items, mode, tab_count),
      timeout = 2,
    }
  end,
}
