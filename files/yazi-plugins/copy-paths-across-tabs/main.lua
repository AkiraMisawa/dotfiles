-- Aggregate selected file paths from every yazi tab and put them on
-- the system clipboard, one path per line.
return {
  entry = function()
    local paths = {}
    for _, tab in ipairs(cx.tabs) do
      for _, url in pairs(tab.selected) do
        table.insert(paths, tostring(url))
      end
    end

    if #paths == 0 then
      ya.notify {
        title   = "copy-paths-across-tabs",
        content = "Nothing selected in any tab",
        level   = "warn",
        timeout = 2,
      }
      return
    end

    ya.clipboard(table.concat(paths, "\n"))
    ya.notify {
      title   = "copy-paths-across-tabs",
      content = ("Copied %d path(s)"):format(#paths),
      timeout = 2,
    }
  end,
}
