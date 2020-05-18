# RRHO2
Improved implementation of RRHO2. In RRHO2, all quadrants of the RRHO plots are meaningful. Enrichment can be calculated and displayed according to odds ratio (using the 'fisher' method), or according to hypergeometric distribution (using the 'hyper' method). 

## Required Package
* VennDiagram

## Install This Package from github
First you need R `devtools` package installed.
* In command line:
```
R -e "devtools::install_github(\"mestill7/RRHO2\")"
```
* In R console
```R
library(devtools)
install_github("mestill7/RRHO2")
```

## Advice on implementing RRHO2
Please see the following Gist on how to set up your differential expression datasets in R for use in RRHO2:
https://gist.github.com/mestill7/beb77eeed14de5371539b81b15716b63


