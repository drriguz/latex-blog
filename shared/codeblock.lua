-- Lua filter to move language class from <pre> to <code> for highlight.js
-- Pandoc with --no-highlight puts class on CodeBlock, but highlight.js
-- expects class="language-xxx" on the <code> element.

function CodeBlock(el)
  -- el.classes contains the language classes (e.g., {"rust"})
  if #el.classes > 0 then
    local lang = el.classes[1]
    -- Return raw HTML with proper highlight.js structure
    local escaped = el.text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return pandoc.RawBlock('html',
      '<pre><code class="language-' .. lang .. '">' .. escaped .. '</code></pre>')
  end
  return el
end
