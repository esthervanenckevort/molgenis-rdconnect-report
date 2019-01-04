# rd-catalogue-report

A program to generate the summary statistics for the RD-Connect Sample Catalogue.

This program generates aggregated counts of the number of samples per disease group
in the ORDO Ontology.

## How to run

```
swift run
```

The program is hardcoded for the production version of the RD-Connect Sample Catalogue
and does not take any arguments. It will output the results on the terminal. If needed you can
redirect the output to a file or a different program.

## Implementation

The program queries the RD-Connect Sample Catalogue for the aggregation of the samples
per disease and will does a depth first traversal of the ORDO ontology to find the disease
groups to which the disease belongs.

The program uses EBI's Ontology Lookup Service (OLS) RESTful API to traverse the ontology.
For performance reasons it caches the OLS responses in memory.

## RD-Connect
RD-Connect has been established thanks to the funding from the European Community’s 
Seventh Framework Program (FP7) under grant agreement n° 305444 “RD-CONNECT:
An integrated platform connecting registries, biobanks and clinical bioinformatics for rare
disease research”.

 RD-Connect was funded from this grant for 6 years: Nov 2012 - Oct 2018.
