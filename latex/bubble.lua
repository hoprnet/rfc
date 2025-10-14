function Code(el)
  local text = el.text
  -- Escape LaTeX special characters except backslash
  text = text:gsub("([#$&%%{}])", "\\%1")
  text = text:gsub("_", "\\_")
  text = text:gsub("%^", "\\textasciicircum{}")
  text = text:gsub("~", "\\textasciitilde{}")
  -- Now add break hints (do NOT escape the backslash!)
  text = text:gsub("([|/_%-%.%+:%=])", "%1\\hspace{0pt}")
  return pandoc.RawInline('latex', '\\begin{codebubble}' .. text .. '\\end{codebubble}')
end
