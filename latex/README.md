## LaTeX generation of the RFCs from the .md files


For the VS Code, it's good to use plugin https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop.
This extension already has settings saved in the repo for easy usage.


### To run the generator:

```
cd latex
bash ./generator-pdf.sh
```


### Prep for generating: 
\* might be outdated

macOS:

```
brew install pandoc 
brew install imagemagick
brew install ghostscript
brew install --cask mactex
npm install --global mermaid-filter @mermaid-js/mermaid-cli
brew install inkscape
```