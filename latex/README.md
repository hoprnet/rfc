## LaTeX generation of the RFCs from the .md files



For the VS Code, it's good to use plugin https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop

Prep for generating

Tested on macOS:

```
brew install pandoc 
brew install --cask mactex
npm install --global mermaid-filter @mermaid-js/mermaid-cli
brew install inkscape
```

For .md to .tex pandoc is used.
https://pandoc.org/installing.html


```
xelatex -shell-escape main.tex
```