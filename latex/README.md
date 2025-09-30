## LaTeX generation of the RFCs from the .md files



For the VS Code, it's good to use plugin https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop

Prep for generating

macOS:

```
brew install pandoc 
brew install --cask mactex
npm install --global mermaid-filter @mermaid-js/mermaid-cli
brew install inkscape
```

Full all in one generator:

```
cd latex
bash ./generator-pdf.sh
```
