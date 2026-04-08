-- Pandoc Lua filter to:
-- 1. Convert \sidenote{...} to <span class="sidenote">...</span> in HTML
-- 2. Handle \ref{...} references with actual section titles
-- 3. Preserve LaTeX macros for PDF output

-- Global table to store section labels and their titles
local section_titles = {}

-- First pass: collect section titles from headers
function Header(el)
  if el.identifier and el.identifier ~= '' then
    -- el.content is a list of inline elements
    -- Convert to plain text by concatenating Str elements
    local title = pandoc.utils.stringify(el.content)
    section_titles[el.identifier] = title
  end
  return el
end

function RawInline(el)
  if el.format == 'latex' then
    -- Handle \sidenote{...}
    if el.text:find('\\sidenote{', 1, true) then
      local pattern = '\\sidenote{([^}]*)}'
      local content = el.text:match(pattern)
      if content and FORMAT:match('html') then
        return pandoc.RawInline('html', '<span class="sidenote">' .. content .. '</span>')
      end
    end
    
    -- Handle \ref{...} - convert to clickable section references with real titles
    if el.text:find('\\ref{', 1, true) then
      local pattern = '\\ref{([^}]*)}'
      local label = el.text:match(pattern)
      if label then
        if FORMAT:match('html') then
          -- Look up the section title
          local title = section_titles[label]
          if not title then
            -- Fallback if title not found
            title = label:gsub('sec:', ''):gsub('_', ' ')
          end
          local link = '<a href="#' .. label .. '">§ ' .. title .. '</a>'
          return pandoc.RawInline('html', link)
        end
        -- Leave \ref for PDF/LaTeX
        return el
      end
    end
  end
  return el
end

return {
  { Header = Header },
  { RawInline = RawInline }
}
