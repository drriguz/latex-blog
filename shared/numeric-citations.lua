-- Pandoc Lua filter to convert citations to numeric [1] style
-- Useful when you want numbered citations like in LaTeX

local citation_counter = {}
local citation_map = {}

function Cite(el)
  if FORMAT:match('html') then
    local first_id = nil
    if el.citations and #el.citations > 0 then
      first_id = el.citations[1].id
    end
    
    if first_id then
      -- Create a unique citation number
      if not citation_map[first_id] then
        citation_counter[1] = (citation_counter[1] or 0) + 1
        citation_map[first_id] = citation_counter[1]
      end
      
      local num = citation_map[first_id]
      -- Return a superscript [1] style citation
      return pandoc.RawInline('html', '<sup><a href="#ref-' .. first_id .. '">[' .. num .. ']</a></sup>')
    end
  end
  return el
end

-- Pandoc's auto-generated reference section uses #ref-id anchors, so this should work
return {
  { Cite = Cite }
}
