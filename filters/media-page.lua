-- An entry's own page (media/*.qmd, models/*.qmd): put its media carousel at
-- the top of the page, under the title block, followed by the entry's
-- `credit:` and headphones note. Whatever is written in the body follows.
--
-- The cards are the same list _templates/media-all.ejs builds for the home
-- page (see the comment there for the fields); keep the two in step when
-- adding a field. partials/media-carousel.html turns the list into the
-- carousel in the browser.
--
-- Quarto leaves a page out of its own listings, so the home-page template
-- cannot be reused here; this filter reads the same front matter instead.

local stringify = pandoc.utils.stringify

-- Front matter -> plain Lua values for JSON. YAML numbers reach Lua as text,
-- so anything that reads as a number becomes one (the viewer checks that
-- positions are finite numbers).
local function plain(v)
  local t = pandoc.utils.type(v)
  if t == "boolean" then return v end
  if t == "List" then
    local out = {}
    for i, x in ipairs(v) do out[i] = plain(x) end
    return out
  end
  if t == "table" then
    local out = {}
    for k, x in pairs(v) do out[k] = plain(x) end
    return out
  end
  local s = stringify(v)
  return tonumber(s) or s
end

local function text(meta, key)
  return meta[key] and stringify(meta[key]) or ""
end

local function nonempty(s) return s ~= "" and s or nil end

-- Like encodeURIComponent. ASCII spelled out: Lua's %w can match bytes above
-- 127 in some locales, which would leave UTF-8 (e.g. "·") half-encoded.
local function uri_encode(s)
  return (s:gsub("[^A-Za-z0-9%-_%.!~%*'%(%)]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function has(tbl, field)
  return type(tbl) == "table" and type(tbl[field]) == "table"
end

local function cards_for(meta)
  local cards = {}
  local title = text(meta, "title")
  local vid, model = text(meta, "video"), text(meta, "model")

  if vid ~= "" then
    table.insert(cards, { type = "video", id = vid, title = title, poster = nonempty(text(meta, "poster")) })
  end

  if model ~= "" then
    local camera = meta.camera and plain(meta.camera) or nil
    if not (has(camera, "position") and has(camera, "target")) then camera = nil end
    local source = meta.source and plain(meta.source) or nil
    if not has(source, "position") then source = nil end
    local speaker = meta.speaker and plain(meta.speaker) or nil
    if not has(speaker, "range") then speaker = nil end
    local seats = meta.seats and plain(meta.seats) or nil
    if type(seats) ~= "table" or #seats == 0 then seats = nil end
    table.insert(cards, {
      type = "model", title = title, model = model,
      mtl = nonempty(text(meta, "mtl")),
      poster = nonempty(vid ~= "" and text(meta, "model-poster") or text(meta, "poster")),
      camera = camera, seats = seats, source = source, speaker = speaker,
      note = nonempty(text(meta, "note")),
    })
  end

  if meta.images then
    for _, im in ipairs(meta.images) do
      local src = im.src and stringify(im.src) or ""
      if src ~= "" then
        table.insert(cards, {
          type = "image", src = src,
          caption = im.caption and nonempty(stringify(im.caption)) or nil,
          alt = im.alt and nonempty(stringify(im.alt)) or nil,
        })
      end
    end
  end
  return cards
end

function Pandoc(doc)
  local meta = doc.meta
  local cards = cards_for(meta)
  if #cards == 0 then return nil end

  local blocks = {
    pandoc.RawBlock("html", '<div class="media-page-media"><div class="media-carousel" data-cards="'
      .. uri_encode(pandoc.json.encode(cards)) .. '"></div></div>'),
  }
  local credit = text(meta, "credit")
  if credit ~= "" then
    table.insert(blocks, pandoc.RawBlock("html", '<p class="media-row-credit">' .. html_escape(credit) .. "</p>"))
  end
  if meta.headphones == true then
    table.insert(blocks, pandoc.RawBlock("html", '<p class="media-row-note">Headphones recommended</p>'))
  end

  doc.blocks = pandoc.Blocks(blocks) .. doc.blocks
  return doc
end
