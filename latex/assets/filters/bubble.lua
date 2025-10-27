function Code(el)
  local text = el.text
  
  text = text:gsub("([#$&%%{}])", "\\%1")
  text = text:gsub("_", "\\_")
  text = text:gsub("%^", "\\textasciicircum{}")
  text = text:gsub("~", "\\textasciitilde{}")
  
  return pandoc.RawInline('latex', '\\codebubble{' .. text .. '}')
end

function CodeBlock(el)
  local text = el.text
  
  text = text:gsub("%^", "\\textasciicircum{}")
  text = text:gsub("~", "\\textasciitilde{}")

  return pandoc.RawBlock('latex', '\\begin{codebubbleenv}\n' .. text .. '\n\\end{codebubbleenv}')
end
