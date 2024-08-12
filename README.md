# HHH-Project-Labor-Agreements
The Effects of Project Labor Agreements on the Production of Affordable Housing: Evidence from Proposition HHH
RAND Corporation
RAND Center for Housing & Homelessness

# Authors:
Jason M. Ward (jward@rand.org)

# Contributor:
Daniel Schwam (dschwam@rand.org)

# Repository Description
This GitHub repository contains data and code for replicating the results in RAND Research Report RR-A1362-1 (https://www.rand.org/pubs/research_reports/RRA1362-1.html).
This repository also contains a folder called "update_2024" that contains results from the 2024 RAND Research Report RR-A1362-2 "Project Labor Agreements and Affordable Housing Production Costs in Los Angeles - Revisiting the Effects of the Proposition HHH Project Labor Agreement Using Cost Data from Completed Projects"

# User Notes
The included code and data set were created using Stata 16 and 17. To enable replication by users of older versions 
of Stata, the dataset was saved in Stata version 12 format. The included MS Excel file is an export of these data.
The included code and data for the 2024 updated research report was created using Stata 18. 

# Getting Started
For this code to run, the following folder structure (using the indicated folder titles) must be created and nested as indicated by the indents below:

- analysis (this folder should be the destination of the "path" global macro above and should contain the following 3 folders)
- do (this folder should contain this do file)
- output (this folder will collect the various outputs from the code)
- working (this folder contains the project data and subsequent derived datasets)

The code generally follows the order of figures and tables encountered in the report with the following exceptions:

1) appendix figs/tables that are directly related to figs/tables in report (e.g., full results or an alternate specification) 
are sometimes grouped with the relevant fig/table code from the body of the report to assure that any local data manipulation 
common to both (e.g., local macros used in sample selection or other data restrictions) are preserved for the related output.

2) results from section 6 (the simulation exercise) are left to the end of the code since most of this output on the log file 
is just repetitive material related to building up the bootstrapped samples. So the materials goes Sections 1, 2, 3, 4, 5 (also has A2 output), A1, 6.

Note, also, that the variable "pla" is simply an indicator variable for a project comprising 65 or more housing units. 
It is used for both hhh and non-hhh projects and only the interaction of this variable with the hhh indicator variable 
(hhhpla or, for a few regressions testing the sensitivity of the results hhhplaalt) captures the estimated construction 
cost effects of the HHH pla.

The last section of code, which runs the simulation exercise (beginning on line 460) may take some time to run as it 
requires the generation of 1000 reps of 3 simulated datasets. 

* The 2024 replication code generates the needed folder structure once a user replaces the global file path macro with their local directory location.

# Additional notes
The author recommends downloading the lean2 scheme package for displaying analytic results (https://blog.stata.com/2018/10/02/scheming-your-way-to-your-favorite-graph-style/)

# Suggested Citation (2021 report):
Ward, Jason, Replication Code and Data for “The Effects of Project Labor Agreements on the Production of Affordable Housing: Evidence from Proposition HHH,” Santa Monica: RAND Corporation, 2021. 
As of July 23, 2021: https://github.com/RANDCorporation/HHH-Project-Labor-Agreements
# Suggested Citation (2024 report):
Ward, Jason, Replication Code and Data for “Project Labor Agreements and Affordable Housing Production Costs in Los Angeles - Revisiting the Effects of the Proposition HHH Project Labor Agreement Using Cost Data from Completed Projects,” Santa Monica: RAND Corporation, 2024. 
As of August 12, 2024: https://github.com/RANDCorporation/HHH-Project-Labor-Agreements
