************************************************* 
*    Analysis for RR-A1362-1 (HHH PLA report)   * 
*    Programmer: Jason Ward, RAND Corporation   *
*               created 210220                  *
*            last modified 210629               *
************************************************* 

* set file path (replace with appropriate file path to replicate results)
global path "INSERT YOUR FILE PATH INSIDE THESE QUOTES"
cd "$path"

* open log file
cap log close
log using "$path/output/hhh_analysis_log", text replace

************** A brief note on this code: ****************
/*
The included ".dta" dataset is saved in Stata format 12. The excel file is an export of this data set. 

For this code to run, the following folder structure (using the indicated folder titles) must be created:
-analysis (this folder should be the destination of the "path" global macro above)
	-do (this folder should contain this do file)
	-output (this folder will collect the various outputs from the code)
	-working (this folder contains the project data and subsequent derived datasets)

The code generally follows the order of figures and tables encountered in the report with the following exceptions:
1) appendix figs/tables that are directly related to figs/tables in report (e.g., full results or an alternate specification) are sometimes grouped with the relevant fig/table code from the body of the report to assure that any local data manipulation common to both (e.g., local macros used in sample selection or other data restrictions) are preserved for the related output. 
2) results from section 6 (the simulation exercise) are left to the end of the code since most of this output on the log file is just repetitive material related to building up the bootstrapped samples. So the materials goes Sections 1, 2, 3, 4, 5 (also has A2 output), A1, 6.

Note, also, that the variable "pla" is simply an indicator variable for a project comprising 65 or more housing units. It is used for both hhh and non-hhh projects and only the interaction of this variable with the hhh indicator variable (hhhpla or, for a few regressions testing the sensitivity of the results hhhplaalt) captures the estimated construction cost effects of the HHH pla.
*/

use "$path/working/hhh_nonhhh_estimation_data", clear

************** SECTION 1 OUTPUT ******************
* Figure 1.1. Cost Shares of HHH projects 
preserve
keep if concostunit2!=.
keep if hhhproject==1 
tab projects // check sample size contributing to figure 
gen conshare = concostunit2/unitcost2
gen landshare = landcostunit2/unitcost2
gen softshare = softcostunit2/unitcost2
collapse conshare landshare softshare
gen id = _n
rename conshare share1
rename landshare share2
rename softshare share3
reshape long share, i(id) j(cat)
label define catlabel 1 "Construction costs share"
label define catlabel 2 "Land costs share", add
label define catlabel 3 "Soft costs share", add
label values cat catlabel
replace share = share*100
graph bar share, over(cat) scheme(lean2) ytitle(Percent of total per unit costs) ylabel(0(10)60)

graph export "$path/output/fig_1_1.pdf", replace
export excel using "$path/output/fig_1_1_data.xlsx", firstrow(varlabels) replace
restore

* Figure 1.2. Average per Unit Costs by Category for HHH and Non-HHH Projects
preserve
keep if concostunit2!=.
tab projects // check sample size contributing to figure 
collapse concostunit2 landcostunit2 softcostunit2, by(hhhproject)
gen id = _n
rename concostunit2 cost1
rename landcostunit2 cost2
rename softcostunit2 cost3
reshape long cost, i(id) j(cat)
label define catlabel 1 "Construction costs"
label define catlabel 2 "Land costs", add
label define catlabel 3 "Soft costs", add
label values cat catlabel
label define idlabel 1 "Non-HHH"
label define idlabel 2 "HHH", add
label values id idlabel

graph bar cost, over(id) over(cat) scheme(lean2) ytitle("Average per unit costs ($1,000s)") ylabel(0(50)350)
graph export "$path/output/fig_1_2.pdf", replace
export excel using "$path/output/fig_1_2_data.xlsx", firstrow(varlabels) replace
restore

**************** SECTION 4 OUTPUT ********************
* Figure Figure 4.1. (and S.1) Frequency Distribution of Project Sizes by Housing Unit for HHH-Funded Projects
preserve
	keep if hhhproject==1
	hist units, width(5) start(5) xline(65, lwidth(medthick) lpattern(dash)) scheme(lean2) ytitle("Number of projects") text(18 87 "Threshold for PLA") xlabel(5(15)185) frequency xtitle(Housing units per project)
	graph export "$path/output/fig_4_1.pdf", replace
	export excel using "$path/output/fig_4_1.xlsx", firstrow(varlabels) replace
restore

* Figure 4.2. (and S.2) Distribution of Project Sizes by Share for HHH and non-HHH projects 
* collapse/save nonHHH shares 
preserve
	keep if hhhproject==0 // keep non-hhh projects
	collapse (sum)projects (sum)units, by(unitgroup)
	egen nonhhh_projtot = sum(projects)
	egen nonhhh_unittot = sum(units)
	gen nonhhh_projshare = projects/nonhhh_projtot 
	gen nonhhh_unitshare = units/nonhhh_unittot 
	save "$path/working/nonHHH_projects_by_units", replace
restore 

* collapse/save HHH shares
preserve 
	keep if hhhproject==1 // keep non-hhh projects
	collapse (sum)projects (sum)units, by(unitgroup)
	egen projecttot = sum(projects)
	egen unittot = sum(units)
	gen projectshare = projects/projecttot 
	gen unitshare = units/unittot 
	save "$path/working/HHH_projects_by_units", replace
	merge 1:1 unitgroup using "$path/working/nonHHH_projects_by_units"
	sort unitgroup 
	label define unitgroups 0 "34 or fewer" 35 "35-49" 50 "50-64" 65 "65-79" 80 "80-94" 95 "95-109" 110 "110 or more" 
	label values unitgroup unitgroups
	
	* gen set of globals to use in counterfactual exercise below
	foreach x in 0 35 50 65 80 95 110{
		summ projectshare if unitgroup==`x'
		global hhhshare`x' = r(mean)
		summ nonhhh_projshare if unitgroup==`x'
		global nonhhhshare`x' = r(mean)
		}
		
	replace projectshare = projectshare*100 // transform proportions into percent measure
	replace nonhhh_projshare = nonhhh_projshare*100 // transform proportions into percent measure	
	graph bar nonhhh_projshare projectshare, over(unitgroup) scheme(lean2) ytitle("Share of total projects (percent)") legend(pos(6) col(2) label(1 "Non-HHH project share") label(2 "HHH project share")) 
	graph export "$path/output/fig_4_2.pdf", replace
	export excel using "$path/output/fig_4_2.xlsx", firstrow(varlabels) replace	

restore 

*********************** SECTION 5 OUTPUT ***************************
* Figure 5.1. Per Unit Costs and Cost Differences by Project Size
preserve
	egen unitgroupalt = cut(units), at(0 50 65 95 200)
	collapse unitcost2, by(unitgroupalt hhhproject)
	label define unitgrpsalt 0 "49 or fewer units" 50 "50-64" 65 "65-94" 95 "95+ units"  
	label values unitgroupalt unitgrpsalt
	reshape wide unitcost2, i(unitgroupalt) j(hhhproject) 
	gen unitcostdiff = unitcost21 - unitcost20 
	
	* 5.1 panel A
	graph bar unitcost20 unitcost21, over(unitgroupalt) scheme(lean2) ytitle("Total cost per unit ($1000s)") legend(pos(6) col(2) label(1 "non-HHH") label(2 "HHH"))
	graph export "$path/output/fig_5_1_panelA.pdf", replace
	
	* 5.1 panel B 
	graph bar unitcostdiff, over(unitgroupalt) scheme(lean2) legend(off) ytitle("Cost differences per unit ($1000s)")
	graph export "$path/output/fig_5_1_panelB.pdf", replace
	
	* save off data for both
	export excel using "$path/output/fig_5_1.xlsx", firstrow(varlabels) replace	
restore

* Figure 5.2. Bivariate Linear Regression Lines Estimating Project Construction Costs
* Panel A (no discontinuity)
preserve
	keep if concostunit2!=. & hhhproject==1 & units<=125
	twoway (scatter concostunit2 units) (lfit concostunit2 units), scheme(plotplain) legend(off) xlabel(,nogrid) ylabel(,nogrid) xline(65,  lpattern(dash)) xtitle(Number of units) ytitle("Construction cost per unit ($1,000s)") xsc(r(20 130)) xlabel(20(20)130) ysc(r(150 500)) ylabel(150(50)500)
	graph export "$path/output/fig_5_2_panelA.png", replace
restore 

* Panel B (discontinuity at PLA threshold)
preserve
	keep if concostunit2!=. & pla_expected==1 & hhhproject==1 & units<=125
	twoway (scatter concostunit2 units) (lfit concostunit2 units if units<=64) (lfit concostunit2 units if units>=65), scheme(plotplain) legend(off) xlabel(,nogrid) ylabel(,nogrid) xline(65,  lpattern(dash)) xtitle(Number of units) ytitle("Construction cost per unit ($1,000s)") xsc(r(20 130)) xlabel(20(20)130) ysc(r(150 500)) ylabel(150(50)500)
	graph export "$path/output/fig_5_2_panelB.png", replace
	
	* estimate underlying bivariate regression for these plots to reference in text
	reg concostunit2 unitrun
	reg concostunit2 unitrun units65 pla
restore 

* Figure C.1 PANEL A (no discontinuity)
preserve
	keep if concostunit2!=. & hhhproject==1 
	twoway (scatter concostunit2 units) (lfit concostunit2 units), scheme(plotplain) legend(off) xlabel(,nogrid) ylabel(,nogrid) xline(65,  lpattern(dash)) xtitle(Number of units) ytitle("Construction cost per unit ($1,000s)") xsc(r(20 180)) xlabel(20(20)180) ysc(r(150 500)) ylabel(150(50)500)
	graph export "$path/output/fig_C_1_panelA.png", replace
restore 

* Figure C.1 PANEL B (discontinuity)
preserve
	keep if concostunit2!=. & pla_expected==1 & hhhproject==1 
	twoway (scatter concostunit2 units) (lfit concostunit2 units if units<=64) (lfit concostunit2 units if units>=65), scheme(plotplain) legend(off) xlabel(,nogrid) ylabel(,nogrid) xline(65,  lpattern(dash)) xtitle(Number of units) ytitle("Construction cost per unit ($1,000s)") xsc(r(20 180)) xlabel(20(20)180) ysc(r(150 500)) ylabel(150(50)500)
	graph export "$path/output/fig_C_1_panelB.png", replace
restore 

***** REGRESSION RESULTS (HAS RESULTS FROM TABLE 5.1 AND MULTIPLE TABLES FROM APPENDIX 2) *****
* local macros of var lists 
* hhhplaalt var switches the PLA status of 2 HHH projects proposed before the PLA. They are used below in alt specs. 
local rhs_main pla hhhproject hhhpla unitrun
local rhs_alt plaalt hhhproject hhhplaalt unitrun
local rhs_alt2 plaalt hhhproject hhhplaalt  
local controls_main Stories story6 story9 cpw pw studio_share twobr_share threebr_share sh_share
local controls_addtl tod elevator parking family specpop 

* Table 5.1 (and B.1) Estimates of Effect of PLA on Construction Costs
* (CONSTRUCTION COST PER UNIT IN $1000s AS OUTCOME)
preserve
	keep if pla_expected==1
	qui summ units if concostunit2!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95' // sample indicator that "windsorizes" data (excludes 5th/95th pctile obs)

	* FIRST PASS to generate main tables
	eststo clear
	eststo est2: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year // SPECIFICATION 1
	cap drop tcac_data_sample
	gen tcac_data_sample = e(sample)
	keep if tcac_data_sample==1 // keep this common sample with valid values for all controls for all other regressions
	eststo est3: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if sample1==1 // SPECIFICATION 2
	* SAVE OFF GLOBALS FROM "PREFERRED MODEL" FOR USE IN GENERATING FIGURE 5.3 BELOW
	global pla_est = _b[hhhpla] // save off global with value of preferred PLA estimate
	di "preferred estimate is $pla_est"
	global hhh_est = _b[hhhproject] // save off global with value of main preferred HHH (avg HHH "premium") estimate
	di "preferred estimate is $hhh_est"
	eststo est5: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1 // SPECIFICATION 3
	
	esttab using "$path/output/table_5_1_panelA_table_B_1.rtf", se compress star(+ 0.10 * 0.05) b(3) keep(`rhs_main' units65 `controls_main' `controls_addtl' _cons) ar2 replace
	
	* SECOND PASS to generate p-values for inclusion in Table 5.1
	eststo clear
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year  // SPECIFICATION 1
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if sample1==1 // SPECIFICATION 2
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1 // SPECIFICATION 3
	
	esttab, p ar2 compress star(+ 0.10 * 0.05) b(3) keep(hhhpla) replace

	* tab of data in full regression sample and sample cuts by hhh status
	tab hhhproject if tcac_data_sample==1
	tab hhhproject if sample1==1
	tab hhhproject if sample1==1 & !inrange(units, 64, 74)
	
	* Table B.2. Estimates of Effect of PLA on Construction Costs (Logged Dependent Variable)
	gen logconcost = log(concostunit2)
	keep if pla_expected==1
	qui summ units if concostunit2!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95' // sample indicator that "windsorizes" data (excludes <5th/>95th pctile obs)

	eststo clear
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year // SPECIFICATION 1
	cap drop tcac_data_sample
	gen tcac_data_sample = e(sample)
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year if sample1==1 // SPECIFICATION 2
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1 // SPECIFICATION 3

	esttab using "$path/output/table_5_1_panelB_table_B_2.rtf", se compress star(+ 0.10 * 0.05) b(3) keep(`rhs_main' units65 `controls_main' `controls_addtl' _cons) ar2 replace
	
	* generate p-values for estimates
	eststo clear
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year
	cap drop tcac_data_sample
	gen tcac_data_sample = e(sample)
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year if sample1==1
	eststo: qui reg logconcost `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1
	
	esttab, p compress star(+ 0.10 * 0.05) b(3) keep(hhhpla) replace

	* Table B.3. Estimates of Effect of PLA on Soft Costs
	* (note, this uses same data sample as used in con cost model with all controls above )
	eststo clear
	eststo: qui reg softcostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year // SPECIFICATION 1
	eststo: qui reg softcostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if sample1==1 // SPECIFICATION 2
	eststo: qui reg softcostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1 // SPECIFICATION 3
	
	esttab using "$path/output/table_B_3.rtf", se compress b(3) star(+ 0.10 * 0.05) keep(`rhs_main' units65 `controls_main' `controls_addtl' _cons) ar2 replace
	eststo clear 
	
	tab units // data point used in results interpretation in text regarding the number of 64-unit projects 
	
	* Table B.5. Estimated PLA Cost Effect Using Quadratic Modeling of Unit Size
	eststo: qui reg concostunit2 `rhs_main' unitrun_2 `controls_main' `controls_addtl' i.year if pla_expected==1 & sample1==1
	eststo: qui reg concostunit2 `rhs_main' units65 unitrun_2 units65_2 `controls_main' `controls_addtl' i.year if pla_expected==1 & sample1==1
	
	* results with both se and p values
	esttab, se compress b(3) star(+ 0.10 * 0.05) keep(hhhpla) ar2 replace
	esttab, p compress b(3) star(+ 0.10 * 0.05) keep(hhhpla) ar2 replace
	eststo clear
	
	* Table B.6. Senstivity of Estimates to Alternate Data Exclusions Around the PLA Threshold
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 74) & sample1==1 
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 64, 80) & sample1==1 
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if !inrange(units, 60, 90) & sample1==1 
	esttab, se compress b(3) star(+ 0.10 * 0.05) keep(hhhpla) ar2 replace
	esttab, p compress b(3) star(+ 0.10 * 0.05) keep(hhhpla) ar2 replace
	eststo clear
	
	* Table B.7. Descriptive Statistics of Analysis Sample
	eststo clear   
	estpost tabstat units hhhpla Stories story6 story9 cpw pw studio_share twobr_share threebr_share sh_share `controls_addtl', statistics(mean sd) by(hhhproject) col(stat) nototal 
	esttab, main(mean) aux(sd) label unstack // display table in results window
	esttab using "$path/output/table_B_7.rtf", main(mean) aux(sd) label unstack replace 
	eststo clear

	*********
	* mean unit cost below used for calculating addtl housing units possible to build with simulated savings in absence of PLA (in summary and discussion).
	summ unitcost2 concostunit2 if hhhproject==1 & inrange(units, 50, 63)
	*********

	* save required values for fig 5.3
	summ concostunit2 if hhhproject==1 & inrange(units, 50, 63)
	global concosthhh5063 = r(mean)
	summ concostunit2 if hhhproject==0 & units>=65
	global concostnonhhh65plus = r(mean) + $hhh_est
	di "non-HHH comparison cost is $concostnonhhh65plus"
restore 
	
	* (this code is out of order from above since data cut at beginning of regressions excludes the two projects that are the subject of this sensitivity test)
	* Table B.4. Estimated PLA Cost Effect Using Alternate PLA-Related Sample Inclusion Criteria
	eststo clear
	* main estimate (exclude 2 non-PLA large projects)
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if pla_expected==1 
	* include projects that do not follow the threshold rule and use expected pla status  
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year
	* include projects that do not follow the threshold rule and use actual pla status
	eststo: qui reg concostunit2 `rhs_alt' units65 `controls_main' `controls_addtl' i.year
	esttab using "$path/output/table_B_4.rtf" , se compress b(3) star(+ 0.10 * 0.05) keep(hhhpla hhhplaalt) ar2 replace
	eststo clear
	
	*** pvalues for above estimates 
	* main estimate (exclude 2 non-PLA large projects)
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year if pla_expected==1
	* include projects that do not follow the threshold rule and use expected pla status  
	eststo: qui reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' i.year 
	* include projects that do not follow the threshold rule and use actual pla status
	eststo: qui reg concostunit2 `rhs_alt' units65 `controls_main' `controls_addtl' i.year 
	esttab, p compress b(3) star(+ 0.10 * 0.05) keep(hhhpla hhhplaalt) ar2 replace
	eststo clear

* Figure 5.3. Two Interpretations of Cost Increases Associated with PLA
preserve 
	clear 
	set obs 2
	gen hhh = _n-1 // gens a binary indicator for hhh avg cost or non-hhh avg cost (as summarized above)
	label define hhhlabel 0 "Non-HHH (65+ units)"
	label define hhhlabel 1 "HHH (50-63 units)", add
	label values hhh hhhlabel
	gen cost = .
	replace cost = $concostnonhhh65plus if hhh==0
	replace cost = $concosthhh5063 if hhh==1
	gen pla = $pla_est 
	gen pctdiff = (pla/cost)*100

	* display exact pct values for text 
	bys hhh: summ pctdiff

	graph bar pctdiff, over(hhh) scheme(lean2) ytitle(Percent increase in construction costs) ylabel(0(5)20)
	graph export "$path/output/fig_5_3.pdf", replace
	* save off data
	export excel using "$path/output/fig_5_3.xlsx", firstrow(varlabels) replace	
restore 

*********************** ADDITIONAL APPENDIX OUTPUT ***************************
* Table A.1. Costs of Projects Grouped by Number of Units 
* descriptive stats for hhh projects  
preserve
	keep if concostunit2!=.
	keep if hhhproject==1 & pla_expected==1
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units // overall unit cost distribution
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units<=49
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 50, 64)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 65, 94)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units>=95
restore 

* descriptive stats for non-hhh projects  
preserve
	keep if concostunit2!=.
	keep if hhhproject==0 & pla_expected==1
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units // overall unit cost distribution
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units<=49
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 50, 64)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 65, 94)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units>=95
restore 

* Table A.2. Construction Costs of Projects Using Alternate PLA-Related Sample Inclusion Criteria
* (only certain data points as described in report are used from output below)
* alt descriptive stats for hhh projects (includes projects with non-expected PLA status)
preserve
	keep if concostunit2!=.
	keep if hhhproject==1 
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units // overall unit cost distribution
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units<=49
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 50, 64)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 65, 94)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units>=95
restore 

* ALTERNATIVE GROUPINGS DISCUSSED IN FOOTNOTE OF TEXT (DETAILS NOT REPORTED)
* alt descriptive stats for hhh projects 1 (use other unit size groupings away from PLA threshold)
preserve
	keep if concostunit2!=.
	keep if hhhproject==1 & pla_expected==1
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units // overall unit cost distribution
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units<=59
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 60, 64)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 65, 104)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units>=105
restore 

* alt descriptive stats for hhh projects 2 (use other unit size groupings away from PLA threshold)
preserve
	keep if concostunit2!=.
	keep if hhhproject==1 & pla_expected==1
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units // overall unit cost distribution
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units<=39
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 40, 64)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if inrange(units, 65, 84)
	summ unitcost2 concostunit2 landcostunit2 softcostunit2 hhhcostunit2 units if units>=85
restore 

* Figure A.1. Average Estimated Per Unit Construction Costs for HHH Projects Over Time
preserve
collapse concostunit1 concostunit2 concostunit3, by(hhhproject) 
graph hbar concostunit1 concostunit2 concostunit3 if hhhproject==1, scheme(lean2) legend(pos(6) col(3) label(1 "Initial cost estimates") label(2 "LIHTC estimates") label(3 "CA DIR contract amount")) ytitle("Average estimated construction cost per unit ($1000s)")
label var concostunit1 "Initial Cost Estimates"
label var concostunit2 "LIHTC estimates"
label var concostunit3 "CA DIR contract amount"
graph export "$path/output/fig_A1_1.pdf", replace
export excel using "$path/output/fig_A_1.xlsx", firstrow(varlabels) replace
restore 

* Figure A.2. Percent Change in Estimated Per Unit Construction Costs Over Time by PLA Status
* changes in percent terms (city to tcac then tcac to dir)
preserve
	gen pctconstcostchg1 = ((concostunit2 - concostunit1)/concostunit1)*100
	gen pctconstcostchg2 = ((concostunit3 - concostunit2)/concostunit2)*100
	* reg estimate of diff
	reg pctconstcostchg2 plaalt if hhhproject==1 
	collapse pctconstcostchg1 pctconstcostchg2, by(hhhproject plaalt) 
	label define plalabel 0 "Non-PLA"
	label define plalabel 1 "PLA", add
	label values plaalt plalabel
	graph hbar pctconstcostchg1 pctconstcostchg2 if hhhproject==1, over(plaalt) scheme(lean2) legend(pos(6) col(1) label(1 "Initial estimates to LIHTC estimates") label(2 "Initial estimates to CA DIR contract amount")) ytitle(Percent change)
	label var pctconstcostchg1 "Initial ests to LIHTC"
	label var pctconstcostchg2 "LIHTC ests to DIR"
	graph export "$path/output/fig_A1_2.pdf", replace
	export excel using "$path/output/fig_A_2.xlsx", firstrow(varlabels) replace
restore 

* Table C.2. Developers of HHH and Non-HHH Projects in the Analysis Data
* (necessary table source data - requires further manual editing)
preserve
	gen count=1
	collapse (sum)count, by(Developer hhhproject)
	export excel using "$path/output/table_C_2.xlsx", firstrow(varlabels) replace
restore 	

************** SECTION 6 ******************
**** counterfactual simulation exercise ***
* uses specification 4 (output in $1000s) *
clear 
set seed 123456789 
cd "$path/working"
use hhh_nonhhh_estimation_data, clear
tab year, gen(yeardum)

local rhs_alt plaalt hhhproject hhhplaalt unitrun 
local rhs_main pla hhhproject hhhpla unitrun 
local controls_main Stories story6 story9 cpw pw studio_share twobr_share threebr_share sh_share
local controls_addtl tod elevator parking family specpop 
local yeardum yeardum2 yeardum3 yeardum4 yeardum5 yeardum6 yeardum7

qui summ units if concostunit2!=., d 
local p5=r(p5)
local p95=r(p95)
cap drop sample* 
gen sample1 = units>`p5' & units<`p95' // sample indicator that "windsorizes" data (excludes <5th/>95th pctile obs)

reg concostunit2 `rhs_main' units65 `controls_main' `controls_addtl' `yeardum' if pla_expected==1 & sample1==1
local estimate = _b[hhhpla] // save off pla estimate 
di "estimated PLA effect is `estimate'" // check that pla estimate agrees with preferred estimate above 
predict yhat, xb
* generate alternate predicted values after setting pla to zero for hhh projects
replace hhhpla=0
predict yhat2, xb
replace yhat2 = yhat if pla_expected==0 // this includes the two non-PLA projects at their full predicted cost 
gen unitcost2_cf = unitcost2 - concostunit2 + yhat2 

keep if hhhproject==1 & concostunit2!=.
order concostunit2 yhat yhat2 
summ concostunit2 yhat yhat2 
summ unitcost2 unitcost2_cf 

* generate actual data values for hhh projects with expected PLA status to compare to baseline simulation
preserve 
keep if hhhproject==1 
collapse (sum)units (sum)SHTotal (mean)concostunit2 (mean)unitcost2 
summ units concostunit2 unitcost2 
restore 

* gen numbered unitgroup var to use with share macros below
gen group=1
replace group=2 if unitgroup==35
replace group=3 if unitgroup==50 
replace group=4 if unitgroup==65
replace group=5 if unitgroup==80
replace group=6 if unitgroup==95
replace group=7 if unitgroup==110 

save cf_dataset_pla_zero, replace 

preserve 
keep if hhhproject==1
collapse (sum)units (mean)concostunit2 (mean)unitcost2
summ units concostunit2 unitcost2 
save cf_simulation_observed_data_values, replace 
restore 

* generate projects according to distributions in 3 counterfactual scenarios 
/*
Scenario					Shares
			20-34		35-49		50-64		65-79		80-94		95-109		110+		
O			4.1			19.4		45.9		 7.1		 5.1		12.2		6.1
2			4.1			19.4		19.4		19.4		19.4		12.2		6.1	
3			4.1			19.4		12.5		20.8		24.9		12.2		6.1
*/

cap program drop cf_stats 
program define cf_stats
	syntax [if] [in], [reps(string)] [cfscenario(string)]
	
****** define share macros for alternate cf scenarios ******
* start with static shares (top 2 and bottom 2)
foreach x in cf0_1 cf1_1 cf2_1 cf3_1{
	local `x' = 4.1	
	}
foreach x in cf0_2 cf1_2 cf2_2 cf3_2{
	local `x' = 19.4	
	}
foreach x in cf0_6 cf1_6 cf2_6 cf3_6{
	local `x' = 12.2	
	}
foreach x in cf0_7 cf1_7 cf2_7 cf3_7{
	local `x' = 6.1	
	}
local cf0_3 = 45.9
local cf0_4 = 7.1 
local cf0_5 = 5.1

local cf2_3 = 19.4
local cf3_3 = 14.5

local cf2_4 = 19.4
local cf3_4 = 19.4

local cf2_5 = 19.4
local cf3_5 = 24.2

forvalues g=1/`reps'{
	forvalues i=1/7{
		cd "$path/working"
		use cf_dataset_pla_zero, clear
		*tab cfsample // use to generate count of all observations to use in local below
		tab hhhproject // use to generate count of all observations to use in local below
		local count = r(N) // used to set size of counterfactual dataset equivalent to size of estimation sample   
		local share `cf`cfscenario'_`i'' // redefine local with unit group share according to cf scenario chosen
		di "share value for unit group `i' is `share'"
		local drawstemp = ((`share')/100)*`count' // generate integer value of draws from cfsample
		local draws = round(`drawstemp', 1)
		di "number of draws for group `i' is `draws'" 
		keep if group==`i' // keep only observations in unit group of interest
		gen randnum = runiform() 
		sort randnum 
		preserve 
		keep if _n==1
		save group_`i'_temp, replace // save off dataset with 1 obs 
		summ projects // use to generate obs count 
		local sampsize = r(N) // obs count to use in while loop below
		restore
		drop randnum 	
		while `sampsize'<`draws'{
			gen randnum = runiform() 
			sort randnum 
			preserve 
			keep if _n==1
			append using group_`i'_temp
			save group_`i'_temp, replace 
			tab group 
			local sampsize = r(N)
			restore
			drop randnum 
		}
	}

	use group_1_temp, clear
	forvalues i=2/7{
		append using group_`i'_temp 
		erase group_`i'_temp.dta
	}
	
	* generate statistics of interest for each simulation rep and save off
	collapse (sum)units (mean)concostunit2 (mean)yhat (mean)yhat2 (mean)unitcost2 (mean)unitcost2_cf
	save cf`cfscenario'`g'_temp, replace 
	}
	* assemble full set of simulation run results
	use cf`cfscenario'1_temp, clear
	forvalues k=2/`reps'{
		append using cf`cfscenario'`k'_temp
		erase cf`cfscenario'`k'_temp.dta
	}
	save cf_results_scenario`cfscenario'_reps`reps'_spec4, replace 
	erase group_1_temp.dta 
	erase cf`cfscenario'1_temp.dta

end 

* counterfactual scenario 0 (observed outcomes) 
cf_stats, reps(1000) cfscenario(0)
cf_stats, reps(1000) cfscenario(2)
cf_stats, reps(1000) cfscenario(3)

foreach i in 0 2 3{
	cd "$path/working"
	di "Results from counterfactual scenario `i'"
	use cf_results_scenario`i'_reps1000_spec4, clear
	di " "
	di "means used as simulation results for scenario `i'"
	summ units yhat unitcost2 yhat2 unitcost2_cf 
	di " "
	qui summ units, d 
	di "median of unit simulation results for scenario `i'"
	di r(p50)
	di " "
	di "5th pctile of unit simulation results for scenario `i'"
	di r(p5)
	di " "
	di "95th pctile of unit simulation results for scenario `i'"
	di r(p95)
	di " "
	qui summ yhat2, d 
	di "median of constr cost simulation results for scenario `i'"
	di r(p50)
	di " "
	di "5th pctile of constr cost simulation results for scenario `i'"
	di r(p5)
	di " "
	di "95th pctile of constr cost simulation results for scenario `i'"
	di r(p95)
	di " "
	qui summ unitcost2_cf, d 
	di "median of unit cost simulation results for scenario `i'"
	di r(p50)
	di " "
	di "5th pctile of unit cost simulation results for scenario `i'"
	di r(p5)
	di " "
	di "95th pctile of unit cost simulation results for scenario `i'"
	di r(p95)

	* hist figs of distr of simulated outcomes
	* units
	cd "$path/output"
	hist units, normal xtitle(Simulated number of units) scheme(lean2)
	graph export simulation_hist_spec4_scenario`i'_units.pdf, replace
	* construction costs
	hist yhat2, normal xtitle(Simulated per unit construction cost) scheme(lean2)
	graph export simulation_hist_spec4_scenario`i'_concost.pdf, replace
	* unit costs
	hist unitcost2_cf, normal xtitle(Simulated per unit total cost) scheme(lean2)
	graph export simulation_hist_spec4_scenario`i'_unitcost.pdf, replace
	}	
	
log close
