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

return {
  entry = function(_, job)
    local mode = (job and job.args and job.args[1]) or "path"

    local items = {}
    for _, tab in ipairs(cx.tabs) do
      for _, url in pairs(tab.selected) do
        table.insert(items, transform(url, mode))
      end
    end

    if #items == 0 then
      ya.notify {
        title   = "copy-across-tabs",
        content = "Nothing selected in any tab",
        level   = "warn",
        timeout = 2,
      }
      return
    end

    ya.clipboard(table.concat(items, "\n"))
    ya.notify {
      title   = "copy-across-tabs",
      content = ("Copied %d %s(s)"):format(#items, mode),
      timeout = 2,
    }
  end,
}
