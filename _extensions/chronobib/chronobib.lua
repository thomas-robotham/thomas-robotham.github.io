-- chronobib.lua
-- Pandoc/Quarto filter that groups bibliography entries by year with
-- reverse-chronological section headings.
--
-- Requires: citeproc: false in YAML (so this filter controls when citeproc runs).
-- If another filter (e.g. highlight-author) already ran citeproc,
-- this filter detects the existing refs div and skips the citeproc call.
--
-- Usage in YAML front matter:
--   citeproc: false
--   filters:
--     - michaelaye/chronobib
--
-- Optional configuration:
--   chronobib:
--     heading-level: 2    # heading level for year sections (default: 2)
--     sort: descending     # descending (default) or ascending
--     split-keyword: refereed  # split refs into target divs by keyword (optional)
--
-- When split-keyword is set, the filter looks for placeholder divs in the
-- document body named #refs-{keyword} and #refs-non-{keyword} and fills them
-- with the matching year-grouped entries. Use these inside a native Quarto
-- ::: {.panel-tabset} for tab rendering.
--
-- When split-keyword is not set, the filter replaces the #refs div with
-- year-grouped output (original behavior).

--- Check whether the refs div already exists (citeproc already ran).
local function has_refs_div(blocks)
  local found = false
  blocks:walk({
    Div = function(div)
      if div.identifier == "refs" then
        found = true
      end
    end
  })
  return found
end

--- Given a list of ref Div elements, group by year and return
--- Blocks with year headings and year-grouped ref divs.
local function group_by_year(entries, key_to_year, heading_level, sort_order, ref_classes, ref_attributes, id_suffix)
  local by_year = {}
  local year_order = {}

  for _, elem in ipairs(entries) do
    if elem.t == "Div" then
      local key = elem.identifier:gsub("^ref%-", "")
      local year = key_to_year[key] or "Unknown"
      if not by_year[year] then
        by_year[year] = {}
        year_order[#year_order + 1] = year
      end
      by_year[year][#by_year[year] + 1] = elem
    end
  end

  if sort_order == "ascending" then
    table.sort(year_order)
  else
    table.sort(year_order, function(a, b) return a > b end)
  end

  local blocks = pandoc.Blocks{}
  for _, year in ipairs(year_order) do
    blocks:insert(pandoc.Header(
      heading_level,
      pandoc.Str(year),
      pandoc.Attr("section-" .. year .. (id_suffix or ""))
    ))
    local year_div = pandoc.Div(
      by_year[year],
      pandoc.Attr(
        "refs-" .. year .. (id_suffix or ""),
        ref_classes,
        ref_attributes
      )
    )
    blocks:insert(year_div)
  end

  return blocks
end

function Pandoc(doc)
  -- Read configuration from metadata
  local heading_level = 2
  local sort_order = "descending"
  local split_keyword = nil

  local meta = doc.meta["chronobib"]
  if meta then
    local meta_type = pandoc.utils.type(meta)
    if meta_type == "table" then
      if meta["heading-level"] then
        heading_level = tonumber(pandoc.utils.stringify(meta["heading-level"])) or 2
      end
      if meta["sort"] then
        sort_order = pandoc.utils.stringify(meta["sort"])
      end
      if meta["split-keyword"] then
        split_keyword = pandoc.utils.stringify(meta["split-keyword"])
      end
    end
  end

  -- Build citation key -> year mapping from bibliography metadata
  local key_to_year = {}
  local key_has_keyword = {}
  local refs = pandoc.utils.references(doc)
  for _, ref in ipairs(refs) do
    if ref.issued and ref.issued["date-parts"] then
      local dp = ref.issued["date-parts"]
      if dp[1] and dp[1][1] then
        key_to_year[ref.id] = tostring(dp[1][1])
      end
    end

    -- Build keyword mapping if split-keyword is configured
    if split_keyword and ref.keyword then
      local kw_str = pandoc.utils.stringify(ref.keyword)
      local has_it = false
      for word in kw_str:gmatch("[^,]+") do
        word = word:match("^%s*(.-)%s*$")  -- trim whitespace
        if word == split_keyword then
          has_it = true
          break
        end
      end
      key_has_keyword[ref.id] = has_it
    end
  end

  -- Run citeproc only if it hasn't already been run by a previous filter
  if not has_refs_div(doc.blocks) then
    doc = pandoc.utils.citeproc(doc)
  end

  -- Extract entries from the #refs div
  local ref_entries = {}
  local ref_classes = {}
  local ref_attributes = {}
  doc.blocks:walk({
    Div = function(div)
      if div.identifier == "refs" then
        ref_classes = div.classes
        ref_attributes = div.attributes
        for _, elem in ipairs(div.content) do
          if elem.t == "Div" then
            ref_entries[#ref_entries + 1] = elem
          end
        end
      end
    end
  })

  if split_keyword then
    -- Split entries into two groups
    local with_kw = {}
    local without_kw = {}
    for _, elem in ipairs(ref_entries) do
      local key = elem.identifier:gsub("^ref%-", "")
      if key_has_keyword[key] then
        with_kw[#with_kw + 1] = elem
      else
        without_kw[#without_kw + 1] = elem
      end
    end

    -- Year-group each set (use heading_level + 1 since tab headers are at heading_level)
    local with_kw_blocks = group_by_year(
      with_kw, key_to_year,
      heading_level + 1, sort_order,
      ref_classes, ref_attributes,
      "-" .. split_keyword
    )
    local without_kw_blocks = group_by_year(
      without_kw, key_to_year,
      heading_level + 1, sort_order,
      ref_classes, ref_attributes,
      "-non" .. split_keyword
    )

    -- Fill target divs and remove the original #refs div
    local target_with = "refs-" .. split_keyword
    local target_without = "refs-non" .. split_keyword

    doc.blocks = doc.blocks:walk({
      Div = function(div)
        if div.identifier == "refs" then
          -- Remove the original refs div
          return pandoc.Blocks{}
        elseif div.identifier == target_with then
          div.content = with_kw_blocks
          return div
        elseif div.identifier == target_without then
          div.content = without_kw_blocks
          return div
        end
      end
    })
  else
    -- Original behavior: replace #refs with flat year-grouped list
    local new_blocks = pandoc.Blocks{}
    for _, block in ipairs(doc.blocks) do
      if block.t == "Div" and block.identifier == "refs" then
        local year_blocks = group_by_year(
          ref_entries, key_to_year,
          heading_level, sort_order,
          ref_classes, ref_attributes, ""
        )
        new_blocks:extend(year_blocks)
      else
        new_blocks:insert(block)
      end
    end
    doc.blocks = new_blocks
  end

  return doc
end
