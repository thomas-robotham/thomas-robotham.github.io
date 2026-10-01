function Div(div)
  print("GROUP BY YEAR FILTER LOADED")

  -- Only modify bibliography
  if div.identifier ~= "refs" then
    return nil
  end

  local grouped = {}
  local years = {}

  for _, item in ipairs(div.content) do

    local text = pandoc.utils.stringify(item)

    -- extract year from citation text (APA prints "(YYYY)")
    local year = text:match("%((%d%d%d%d)%)")

    if not year then
      year = "Unknown"
    end

    if not grouped[year] then
      grouped[year] = {}
      table.insert(years, year)
    end

    table.insert(grouped[year], item)
  end

  -- newest first
  table.sort(years, function(a,b) return a > b end)

  local new_content = {}

  for _, year in ipairs(years) do
    table.insert(new_content, pandoc.Header(2, year))

    for _, entry in ipairs(grouped[year]) do
      table.insert(new_content, entry)
    end
  end

  div.content = new_content
  return div
end