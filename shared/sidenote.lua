-- Pandoc Lua filter to:
-- 1. Convert \sidenote{...} to <span class="sidenote">...</span> in HTML
-- 2. Handle \ref{...} references properly
-- 3. Preserve LaTeX macros for PDF output

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
    
    -- Handle \ref{...} - convert to readable section references
    if el.text:find('\\ref{', 1, true) then
      local pattern = '\\ref{([^}]*)}'
      local label = el.text:match(pattern)
      if label then
        if FORMAT:match('html') then
          -- Convert label to readable format
          -- sec:dft -> §dft, sec:fft -> §fft, etc.
          local readable = label:gsub('sec:', '§ '):gsub('_', ' ')
          return pandoc.Str(readable)
        end
        -- Leave \ref for PDF/LaTeX
        return el
      end
    end
  end
  return el
end

return {
  { RawInline = RawInline }
}
