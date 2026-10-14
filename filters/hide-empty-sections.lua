-- Show a listing section only when its folder actually holds entries.
--
-- Quarto leaves an empty listing div untouched, so a section with no entries
-- renders as a heading above nothing -- and the render still succeeds, so the
-- problem is silent. This filter checks each folder on disk (independent of
-- when Quarto populates listings) and removes whichever marked divs do not
-- apply.
--
-- For each entry below:
--   class      the section wrapper: removed when ALL its folders are empty
--   lists      listing div id -> folder; each listing is removed on its own
--              when its folder is empty, so one section can hold several
--   fallback   an optional stand-in div: removed when any folder is NOT empty
--
-- Student positions are deliberately NOT listed here: that section carries a
-- standing invitation to get in touch, so it stays on the page whether or not
-- any vacancies are open. Only the cards come and go.
--
-- Add or delete a file in the folder and the page follows automatically.

local SECTIONS = {
  -- Videos and interactive 3D models share the one Media heading.
  { class = "media-section", lists = { models = "models", media = "media" }, fallback = nil },
}

local function has_entries(dir)
  local ok, names = pcall(pandoc.system.list_directory, dir)
  if not ok or names == nil then
    return false
  end
  for _, name in ipairs(names) do
    -- Skip _metadata.yml, the scaffold template, and anything else underscored.
    if name:match("%.qmd$") and not name:match("^_") then
      return true
    end
  end
  return false
end

function Pandoc(doc)
  local drop, drop_id = {}, {}
  for _, section in ipairs(SECTIONS) do
    local any = false
    for id, dir in pairs(section.lists) do
      if has_entries(dir) then any = true else drop_id[id] = true end
    end
    if any then
      if section.fallback then drop[section.fallback] = true end
    else
      drop[section.class] = true
    end
  end

  doc.blocks = doc.blocks:walk({
    Div = function(div)
      if drop_id[div.identifier] then return {} end
      for _, class in ipairs(div.classes) do
        if drop[class] then return {} end
      end
    end
  })

  return doc
end
