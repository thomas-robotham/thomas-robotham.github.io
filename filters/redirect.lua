-- Turns `redirect: <url>` in a page's front matter into a client-side forward.
-- Used by stub highlights: the card links straight out, and this catches
-- anyone who lands on the stub page directly (bookmark, search engine).
function Pandoc(doc)
  local target = doc.meta.redirect
  if target == nil then
    return doc
  end

  local url = pandoc.utils.stringify(target)
  quarto.doc.include_text("in-header",
    '<meta http-equiv="refresh" content="0; url=' .. url .. '">')

  return doc
end
