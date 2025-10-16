function Code(el)
  local text = el.text
  
  -- Check if text contains newlines
  if text:find('\n') then
    -- Multi-line code: use environment
    -- Escape LaTeX special characters for environment content
    text = text:gsub("([#$&%%{}])", "\\%1")
    text = text:gsub("_", "\\_")
    text = text:gsub("%^", "\\textasciicircum{}")
    text = text:gsub("~", "\\textasciitilde{}")
    
    return pandoc.RawInline('latex', '\\begin{codebubble}\n' .. text .. '\n\\end{codebubble}')
  else
    -- Single-line code: use command
    -- Escape LaTeX special characters for command argument
    -- return pandoc.RawInline('latex', ''..text..'');

    text = text:gsub("([#$&%%{}])", "\\%1")
    text = text:gsub("_", "\\_")
    text = text:gsub("%^", "\\textasciicircum{}")
    text = text:gsub("~", "\\textasciitilde{}")
    
    
    return pandoc.RawInline('latex', '\\codebubble{' .. text .. '}')
  end
end

function CodeBlock(el)
  local text = el.text
  
  -- For code blocks, always use environment
  -- Escape LaTeX special characters
  text = text:gsub("([#$&%%{}])", "\\%1")
  text = text:gsub("_", "\\_")
  text = text:gsub("%^", "\\textasciicircum{}")
  text = text:gsub("~", "\\textasciitilde{}")

  return pandoc.RawBlock('latex', '\\begin{codebubbleenv}\n' .. text .. '\n\\end{codebubbleenv}')
end
