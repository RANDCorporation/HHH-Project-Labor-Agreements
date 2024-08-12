**** RAND HHH PLA STUDY UPDATED RESULTS ****
* Jason Ward
* RAND - Santa Monica, CA
* Created June 2024
* Last modified 240714

/* 
READ ME: THIS DO FILE RECREATES ALL RESULTS FROM THE 2024 RAND REPORT
"Project Labor Agreements and Affordable Housing Production Costs in Los Angeles:
Revisiting the Effects of the Proposition HHH Project Labor Agreement Using Cost Data from Completed Projects."
USERS MUST REPLACE THE GLOBAL MACRO "path" BELOW WITH A PATH TO THE REPLICATION FOLDER.  
*/

clear
set more off, perm 

* REPLACE THIS GLOBAL MACRO WITH THE LOCATION OF THE REPLICATION FOLDER ON THE USER'S LOCAL DRIVE
global path "(INSERT YOUR ACTUAL FILE PATH HERE)"

mkdir "$path/working"
mkdir "$path/output"

import delimited "$path/raw/LAHD_Affordable_Housing_Projects_List__2003_to_Present_.csv", clear 
keep name developmentstage constructiontype inservicedate tdc lahdfunded
rename tdc tdc_lahd
save "$path/working/lahd_data_to_merge", replace

use "$path/raw/hhh_nonhhh_estimation_data_updated_final.dta", clear

* GENERATE Variables for Revised Analysis *

	gen units_65plus=units>64
	
	//updated TDCs
	gen tdc= ActualTDC/1000
	gen tdcunit= tdc/units
	gen log_tdcunit= log(tdcunit)
	
* gen estimated tdcunit in $1000s to use below 
gen tdcunit2 = (TDCAmount_2/1000)/units

**** ADD PLACED IN SERVICE DATES (merge most and then manually complete) ****
gen name = upper(ProjectName)
merge 1:1 name using "$path/working/lahd_data_to_merge"
keep if inlist(_merge, 1, 3)
drop _merge
* This merge took care of about 87%. Hard code remaining 12. 

* code up inservice according to best current info (shows as leasing or COO issued)
gen inservice = developmentstage=="In-Service"
replace inservice = 0 if ProjectName=="11010 Santa Monica"
replace inservice = 1 if ProjectName=="Hope on Hyde Park"
replace inservice = 1 if ProjectName=="Missouri Place Apartments"
replace inservice = 1 if ProjectName=="Sherman Oaks Senior"
replace inservice = 1 if ProjectName=="The Pointe on La Brea"
replace inservice = 1 if ProjectName=="Westlake 619"
replace inservice = 0 if ProjectName=="Westlake Housing (The Lake House)"

destring inservicedate, ignore("Completed but Missing Date" "Development") replace 
replace inservicedate=2023 if ProjectName=="11010 Santa Monica"
replace inservicedate=2022 if ProjectName=="Cadence (fka 11408 S Central Ave)" 
replace inservicedate=2022 if ProjectName=="HiFi Collective (fka Temple View)" 
replace inservicedate=2022 if ProjectName=="LAMP Lodge" 
replace inservicedate=2023 if ProjectName=="Hope on Hyde Park"
replace inservicedate=2022 if ProjectName=="Missouri Place Apartments"
replace inservicedate=2022 if ProjectName=="PATH Villas Montclair/Gramercy"
replace inservicedate=2023 if ProjectName=="Sherman Oaks Senior"
replace inservicedate=2023 if ProjectName=="The Pointe on La Brea"
replace inservicedate=2023 if ProjectName=="Westlake 619"
replace inservicedate=2024 if ProjectName=="Westlake Housing (The Lake House)" // listed as in-dev in LAHD data but used in LF2024, appears to be leasing now so assume 2024.

* some projects listed as "Completed but Missing Date"
replace inservicedate=2023 if ProjectName=="Marcella Gardens (68th & Main St.)"
* gen measure of time from funding award to completion 
gen projyrs = inservicedate-year
* gen alternate year FEs by taking year of award year + (projyrs/2) or halfway point between award and in service dates
gen yearalt = round((year+(projyrs/2)), 1)

* Explore extent of unrealistic TDC amounts in LAHD data 
gen tdc_lahd_ratio = tdc_lahd/lahdfunded
gen tdc_lahd_pctdiff = (tdc_lahd-lahdfunded)/tdc_lahd
summ tdc_lahd_ratio if inservice==1, d
gen tdc_act_est_ratio = tdc_lahd/tdc_tcac 

* explore extent of bad data points in LAHD data (low ratio indicates potential issue, ratio of 1 is def an error)
tab name if tdc_lahd_ratio<=2.5 & inservice==1
tab name if tdc_lahd_ratio==1 & inservice==1
tab tdc_act_est_ratio if tdc_lahd_ratio<2 & inservice==1

*** IDENTIFY PROJECTS W/INCORRECT TDC (HHH AWARD AND TDC AMOUNT EQUAL) ***
tab ProjectName if lahdfunded==tdc_lahd & tdc_lahd!=. & inservice==1
gen exclude = lahdfunded==tdc_lahd & tdc_lahd!=. & inservice==1
tab exclude 

* Now replace incorrect LAHD costs for 4 projects in LF2024 analysis where the TDC was equal to the HHH funding amount 
* (TDC data obtained directly from email correspondence with relevant developers of each project)
	gen tdc_alt = tdc
	replace tdc_alt = 57800 if ProjectName=="McCadden Campus Senior (aka McCadden Plaza Senior)"
	replace tdc_alt = 39870 if ProjectName=="The Wilcox (fka 4906-4926 Santa Monica)"
	replace tdc_alt = 33158.596 if ProjectName=="The Quincy (fka 2652 Pico)"
	replace tdc_alt = 33578 if ProjectName=="SagePointe (fka Deepwater)"	
	
	* additionally correct problem with the "King 1101" project that had a TDC value 
	* (using the "ActualTDC" var from the UCBLB data) that was 2.4 times the LAHD reported TDC value
	replace tdc_alt = (tdc_lahd/1000) if ProjectName=="King 1101"	
	
	* add in one more TDC amount that did not merge from LAHD data 
	replace tdc_alt = (48140164/1000) if ProjectName=="Hartford Villa Apartments"
	
	gen tdcunit_alt= tdc_alt/units // tdc using corrected cost data 

*** EXPLORE COMPLETENESS OF DATA TO ASSESS ABILITY TO INCREASE SAMPLE SIZE WITH MORE COMPLETED PROJECTS ***
* VARIABLES tdcunit2 pw cpw Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop year
foreach x in tdcunit2 tdcunit_alt landcostunit2 pw cpw Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop year inservice{
	qui summ `x'
	local N = r(N)
	di "outcome is `x', number of nonmissing obs is `N'"
	}
foreach x in tdcunit2 tdcunit_alt landcostunit2 pw cpw Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop year{
	qui summ `x' if inservice==1
	local N = r(N)
	di "outcome is `x', number of nonmissing obs classified as in-development is `N'"
	}

* parking and elevator missingness seem to be the most binding factor on sample size
* tab other vars conditional on these things 
foreach x in tdcunit2 tdcunit_alt landcostunit2 pw cpw Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop year inservicedate{
	qui summ `x' if parking!=. & elevator!=. 
	local N = r(N)
	di "outcome is `x', number of nonmissing obs classified as in-development is `N'"
	}

**** Complete some parking and elevator info to maximize potential sample size ****
**** Also complete data on totalresidentialbuildings (should have used this last time) ****
replace parking=1 if projectnumber=="CA-14-169"
replace elevator=1 if projectnumber=="CA-14-169"
replace parking=1 if projectnumber=="CA-17-729"
replace elevator=1 if projectnumber=="CA-17-729"

replace totalresidentialbuildings=1 if projectnumber=="CA-14-169"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-050"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-064"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-088"
replace totalresidentialbuildings=2 if projectnumber=="CA-15-122"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-827"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-834"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-845"
replace totalresidentialbuildings=1 if projectnumber=="CA-15-950"
replace totalresidentialbuildings=1 if projectnumber=="CA-16-067"
replace totalresidentialbuildings=1 if projectnumber=="CA-16-863"
replace totalresidentialbuildings=1 if projectnumber=="CA-16-928"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-023"
replace totalresidentialbuildings=2 if projectnumber=="CA-17-025"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-044"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-073"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-086"
replace totalresidentialbuildings=2 if projectnumber=="CA-17-122"
replace totalresidentialbuildings=2 if projectnumber=="CA-17-729"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-740"
replace totalresidentialbuildings=1 if projectnumber=="CA-17-749"
replace totalresidentialbuildings=1 if projectnumber=="CA-18-018"
replace totalresidentialbuildings=1 if projectnumber=="CA-18-051"
replace totalresidentialbuildings=1 if projectnumber=="CA-18-091"
replace totalresidentialbuildings=1 if projectnumber=="CA-19-018"
replace totalresidentialbuildings=1 if projectnumber=="CA-19-041"
replace totalresidentialbuildings=1 if projectnumber=="CA-20-555"
replace totalresidentialbuildings=1 if projectnumber=="CA-20-695"
replace totalresidentialbuildings=1 if projectnumber=="CA-21-529"
replace totalresidentialbuildings=1 if projectnumber=="CA-21-534"
replace totalresidentialbuildings=1 if projectnumber=="CA-21-535"
replace totalresidentialbuildings=1 if projectnumber=="CA-21-536"
replace totalresidentialbuildings=1 if ProjectName=="6th and San Julian"

**** Complete odd missing values for additional projects ****
replace landcostunit2 = 2585/units if projectnumber=="CA-14-169" // Marmion Way project 

replace tdcunit2 = (TDCAmount_1/1000)/units if ProjectName=="My Angel (fka The Angel)"
replace landcostunit2 = (LandCosts_1/1000)/units if ProjectName=="My Angel (fka The Angel)"
replace year=2021 if ProjectName=="My Angel (fka The Angel)"

drop if ProjectName=="Panama Hotel Apartments" // this is a rehab project 

replace tdcunit2 = (TDCAmount_1/1000)/units if ProjectName=="Watts Works"
replace landcostunit2 = (LandCosts_1/1000)/units if ProjectName=="Watts Works"
replace year = 2019 if ProjectName=="Watts Works"

**** IMPLEMENT EXTERNAL REVIEWER SUGGESTION TO SIMPLIFY CERTAIN CONTROLS TO INCREASE PRECISION ****
* simplify share of units by bedrooms (use just studio share and two+ bedroom share, 1br as omitted)
gen twobrplus_share = 1 - studio_share - onebr_share
* simplify prevailing wage to single measure 
gen prevwagetemp = pw+cpw 
gen prevwage = prevwagetemp>=1 
drop prevwagetemp
tab prevwage hhhproject 
* gen simpler story 6+ variable
gen story6plus = story6 + story9 
* gen quadratic term in stories (to allow for diminishing costs as stories are added)
gen Stories2 = Stories*Stories
* aggregate early year FEs to facilitate larger "within" comparison group for earliest years
gen yearalt2 = yearalt
replace yearalt2 = 2018 if yearalt2<=2017 // mean development year 
cap drop year2
gen year2 = year
replace year2 = 2016 if year2<=2015 // LIHTC award year

**** ADJUST PRICES BY PPI DEFLATOR (UNCOMMENT IF RUNNING CODE FOR FIRST TIME) ****
* Merge on deflator to harmonize prices (using both ) 
preserve 
	* import and save off deflator data 
	import excel "$path/raw/FRED_PPI_PCE_ECI_2010_2023.xls", sheet("FRED Graph") cellrange(A13:D27) firstrow clear
	gen year = year(observation_date)
	save "$path/working/deflator_data_2010_2023", replace
restore 

* merge to LIHTC award yr
merge m:1 year using "$path/working/deflator_data_2010_2023"
keep if _merge==3 // drops obs without valid LIHTC year
drop _merge
rename year year1
rename ECIWAG_NBD20210101 year_eci 
rename PCEPI_NBD20210101 year_pce 
rename WPUSI012011_NBD20210101 year_ppi 

* merge to middle development yr
rename yearalt year 
merge m:1 year using "$path/working/deflator_data_2010_2023"
keep if _merge==3 // drops obs without valid inservice year
drop _merge
rename ECIWAG_NBD20210101 yearalt_eci 
rename PCEPI_NBD20210101 yearalt_pce 
rename WPUSI012011_NBD20210101 yearalt_ppi 
rename year yearalt // re-rename estimated primary construction year
rename year1 year // re-rename original "year" var which is for LIHTC award year 

* adjust costs by earlier & later deflator 
gen tdcunit2_adj = tdcunit2/(year_pce/100)
gen tdcunit_adj = tdcunit/(yearalt_pce/100)
gen tdcunit_alt_adj = tdcunit_alt/(yearalt_pce/100)
gen landcostunit2_adj = landcostunit2/(year_pce/100)

* merge on indicator for inclusion in analysis sample of LF (2024)
merge 1:1 ProjectName using "$path/raw/lf_sample_inclusion" // simple indicator dataset derived from LF (2024) code
drop _merge 

**** Chapter 1: Scatter plot ****	

local outcome1 tdcunit_alt_adj
local outcome2 tdcunit2_adj
local landcost landcostunit2_adj

preserve
	keep if units>30
	keep if `outcome1'!=. & `outcome1'>0 & pla_expected==1 & hhhproject==1 & inservice==1
	fre ProjectName if `outcome1'<320

	twoway (scatter `outcome1' units) (lfit `outcome1' units if units<=64, lwidth(medthick) lstyle(solid)) (lfit `outcome1' units if units>=65, lwidth(medthick) lstyle(solid)), scheme(plotplain) legend(off) xlabel(,nogrid) ylabel(,nogrid) xline(65,  lpattern(dash)) xtitle(Number of Housing Units) ytitle("TDC per Unit ($1000s)") xsc(r(35 125)) xlabel(35(10)125) ysc(r(300 900)) ylabel(300(50)900)
	graph export "$path/output/scatterfig_tdcact_lf2024.png", replace

	* estimate underlying bivariate regression for these plots to reference in text
	reg tdcunit unitrun
	reg tdcunit unitrun units65 pla
restore 

********* Chapter 2: Replication of LF (2024) and effects of omitting or correcting incorrect LAHD data *********
* This code generates the coefficient plot in the main text and the results for appendix table A.2 

local outcome1 tdcunit_alt_adj
local outcome2 tdcunit2_adj
local landcost landcostunit2_adj

** Replicate LF (2024) result (Panel A of Table A.2) **
eststo clear
	preserve
			
	drop if hhhpla==1 & hhhplaalt==0 
	keep if `outcome1'>0 & `outcome1'!=. 
	keep if pla_expected==1
	qui summ units if tdcunit!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95'
	
		tab yearalt yearalt2 if sample1==1
		rename hhhpla hhhpla1
		label var hhhpla1 "Original LF(2024)"
		eststo est0: qui reg tdcunit hhhpla1 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 // Model 1
				gen mod1sample = e(sample)
				tab pla if mod1sample==1 
				local est0beta = _b[hhhpla]
				
		eststo est1: qui reg tdcunit hhhpla1 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 & sample1==1 // Model 2
				gen mod2sample = e(sample)
				tab pla if mod2sample==1 
				local est1beta = _b[hhhpla]
				
		esttab est0 est1, keep(hhhpla1) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001)
		drop mod*sample 

** Estimate same model OMITTING incorrect data points in LAHD data (Panel B of Table A.2) **	

		gen hhhpla2 = hhhpla1
		label var hhhpla2 "Omit incorrect data"
		eststo est2: qui reg tdcunit hhhpla2 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 & exclude==0 // Model 1
				gen mod1sample = e(sample)
				tab pla if mod1sample==1 
				local est2beta = _b[hhhpla]
				
		eststo est3: qui reg tdcunit hhhpla2 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 & sample1==1 & exclude==0 // Model 2
				gen mod2sample = e(sample)
				tab pla if mod2sample==1 
				local est3beta = _b[hhhpla]
				
		esttab est2 est3, keep(hhhpla2) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001)
		drop mod*sample 

** Estimate same model CORRECTING incorrect data points in LAHD data (Panel C of Table A.2) **	

		gen hhhpla3 = hhhpla2
		label var hhhpla3 "Use corrected data"
		eststo est4: qui reg tdcunit_alt hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 // Model 1
				gen mod1sample = e(sample)
				tab pla if mod1sample==1 
				local est4beta = _b[hhhpla]
				
		eststo est5: qui reg tdcunit_alt hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.year if lfsample==1 & sample1==1 // Model 2
				gen mod2sample = e(sample)
				tab pla if mod2sample==1 
				local est5beta = _b[hhhpla]
				
		esttab est4 est5, keep(hhhpla3) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001)
		drop mod*sample 

		* COEFFICIENT PLOT FOR MAIN TEXT of first 3 estimates (Figure 2.1)
		coefplot est1 est3 est5, keep(hhhpla1 hhhpla2 hhhpla3) xline(0) scheme(lean2) msymbol(O) xtitle("Estimated PLA Cost Effect ($1000s)") legend(off) mlabel(cond(@pval<.001, string(@b, "%9.2fc") + "***", cond(@pval<.01, string(@b, "%9.2fc") + "**", cond(@pval<.05, string(@b, "%9.2fc") + "*", string(@b, "%9.2fc")))) ) mlabposition(12)
		graph export "$path/output/lf2024_mod2est_w_data_omission_correction.png", replace

** Estimate same model adding controls for land costs and correct year FEs (Panel D of Table A.2) **	

		eststo est6: qui reg tdcunit_alt hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.yearalt2 if lfsample==1 // Model 1
				gen mod1sample = e(sample)
				tab pla if mod1sample==1 
				local est6beta = _b[hhhpla]
				
		eststo est7: qui reg tdcunit_alt hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.yearalt2 if lfsample==1 & sample1==1 // Model 2
				gen mod2sample = e(sample)
				tab pla if mod2sample==1 
				local est7beta = _b[hhhpla]
				
		esttab est6 est7, keep(hhhpla3) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001)
		drop mod*sample 

** Estimate same model adding controls for land costs and correct year FEs and use deflated costs (Panel E of Table A.2) **	

		eststo est8: qui reg tdcunit_alt_adj hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.yearalt2 if lfsample==1 // Model 1
				gen mod1sample = e(sample)
				tab pla if mod1sample==1 
				local est8beta = _b[hhhpla]
				
		eststo est9: qui reg tdcunit_alt_adj hhhpla3 pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop i.yearalt2 if lfsample==1 & sample1==1 // Model 2
				gen mod2sample = e(sample)
				tab pla if mod2sample==1 
				local est9beta = _b[hhhpla]
				
		esttab est8 est9, keep(hhhpla3) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001)

		summ tdcunit_alt if mod2sample==1 & inrange(units, 50, 64) & hhhproject==1

		local avgcost = r(mean) 
	
		*** COMPARISON RESULTS WITH FINAL MAIN MODEL BELOW ***
		reg tdcunit_alt_adj hhhpla3 prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if lfsample==1 // Model 1

		reg tdcunit_alt_adj hhhpla3 prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if lfsample==1 & sample1==1 // Model 2

		reg tdcunit_alt_adj hhhpla3 prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if inservice==1 & sample1==1
		
		*** Document differences in analysis sample (for text in appendix) ***
		tab ProjectName if lfsample==1 & inservice==0 // projects in LF(2024) sample that are not in service according to LAHD website
		tab ProjectName if lfsample==0 & inservice==1 // projects that ARE in service according to LAHD (included in main ests)
		
	restore

		** calculate effect sizes in percent terms using avg cost given above **
		* Original L&F estimates 
		di `est0beta'/`avgcost'
		di `est1beta'/`avgcost'
		* Estimates omitting bad data points
		di `est2beta'/`avgcost'
		di `est3beta'/`avgcost'
		* Estimates corrrecting bad data points
		di `est4beta'/`avgcost'
		di `est5beta'/`avgcost'
		* Estimates corrrecting bad data points, add land costs, mod year FEs
		di `est6beta'/`avgcost'
		di `est7beta'/`avgcost'
		* Estimates corrrecting bad data points, add land costs, mod year FEs, 2021$s
		di `est8beta'/`avgcost'
		di `est9beta'/`avgcost'
		
**** Chapter 3: DESCRIPTIVE STATISTICS (Table 3.1 of main text) ****

local outcome1 tdcunit_alt_adj
local outcome2 tdcunit2_adj
local landcost landcostunit2_adj

preserve
	gen projtype = 0
	replace projtype = 1 if hhhproject==0 & pla==0
	replace projtype = 2 if hhhproject==1 & pla==0
	replace projtype = 3 if hhhproject==0 & pla==1 
	replace projtype = 4 if hhhproject==1 & pla==1

	drop if hhhpla==1 & hhhplaalt==0 
	keep if tdcunit_alt>0 & tdcunit_alt!=. & inservice==1
	keep if pla_expected==1
	qui summ units if tdcunit!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95'

	foreach x in `outcome1' `outcome2' `landcost' year inservicedate units Stories studio_share onebr_share twobrplus_share sh_share totalresidentialbuildings prevwage {
		
	di "Characteristic is `x'"
	bys projtype: summ `x'
	}

	bys projtype: summ units, d // check minimum sizes for HHH and non-HHH projects
restore 

********* Chapter 3: HHH PLA cost effect estimates using original est TDC data from Ward (2021) and actual TDC *********
* Figure 3.1 and tables A.3 and A.4

local outcome1 tdcunit_alt_adj
local outcome2 tdcunit2_adj
local landcost landcostunit2_adj

eststo clear
	preserve
	drop if hhhpla==1 & hhhplaalt==0 
	keep if `outcome1'>0 & `outcome1'!=. 
	* keep if pla_expected==1
	qui summ units if tdcunit!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95'

	** Make dot plot of year for projects in analysis sample (Appendix figure A.1) **
	lab def hhhprojectlab 0 "Non-HHH project" 1 "HHH project"
	lab val hhhproject hhhprojectlab
	* Mean dev year
	dotplot yearalt, over(hhhproject) center scheme(lean2) ytitle(Mean development year) xtitle("")
	graph export "$path/output/project_mean_dev_yr_dotplot.png", replace 
	
tab yearalt yearalt2 if sample1==1 

* measure actual TDC for HHH projects of between 50 and 64 units for comparison with actual PLA proj costs 
	summ `outcome2' if hhhproject==1 & inrange(units, 50, 64) & inservice==1
	local tdcavg_est = r(mean)
	summ `outcome1' if hhhproject==1 & inrange(units, 50, 64) & inservice==1
	local tdcavg_act = r(mean)

* measure actual TDC for non-HHH projects of 65 units or higher alternate comparison with actual PLA proj costs 
	summ `outcome2' if hhhproject==0 & units>65 & inservice==1
	local tdcavg_est = r(mean)
	summ `outcome1' if hhhproject==0 & units>65 & inservice==1
	local tdcavg_act = r(mean)

* Model 1: TDC reg w/LAHD costs
eststo est1: qui reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if inservice==1 // Model 1
		local tdcact1 = _b[hhhpla]
		
		gen mod1sample = e(sample)
		tab hhhproject pla if mod1sample==1
		
		* estimate as percent of cost of avg HHH project of 50-64 units (actual costs)
		di (`tdcact1'/`tdcavg_act')*100
		
* Model 1: same TDC reg w/orig estimated costs
eststo est2: qui reg `outcome2' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.year2 if mod1sample==1  // Model 1 with estimated TDC using same sample as above		
		local tdcest1 = _b[hhhpla]
		
		* estimate as percent of cost of avg HHH project of 50-64 units (estimated costs)
		di (`tdcest1'/`tdcavg_est')*100

* Model 2: TDC reg w/LAHD costs
eststo est3: qui reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if inservice==1 & sample1==1 // Model 2
		local tdcact2 = _b[hhhpla]

		gen mod2sample = e(sample)
		tab hhhproject pla if mod2sample==1 

		* estimate as percent of cost of avg HHH project of 50-64 units (actual costs)
		di (`tdcact2'/`tdcavg_act')*100

* Model 2: same TDC reg w/orig estimated costs
eststo est4: qui reg `outcome2' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.year2 if mod2sample==1   // Model 2 with estimated TDC using same sample as above	
		local tdcest2 = _b[hhhpla]

		* estimate as percent of cost of avg HHH project of 50-64 units (estimated costs)
		di (`tdcest2'/`tdcavg_est')*100

* Model 3: TDC reg w/LAHD costs
eststo est5: qui reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if units!=64 & mod2sample==1 // Model 3
		local tdcact3 = _b[hhhpla]

		gen mod3sample = e(sample)
		tab hhhproject pla if mod3sample==1 

		* estimate as percent of cost of avg HHH project of 50-64 units (actual costs)
		di (`tdcact3'/`tdcavg_act')*100
		
		* Alt model without inclusion of number of buildings (discussed briefly in text introducing model changes)
		reg `outcome1' hhhpla pw cpw hhhproject unitrun units65 pla Stories story6 story9 onebr_share twobr_share threebr_share sh_share parking tod elevator family specpop `landcost' i.yearalt if units!=64 & mod2sample==1 // Model 3
	
* Model 3: same TDC reg w/orig estimated costs
eststo est6: qui reg `outcome2' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.year2 if units!=64 & mod2sample==1  // Model 3 with estimated TDC using same sample as above
		local tdcest3 = _b[hhhpla]

		* estimate as percent of cost of avg HHH project of 50-64 units (estimated costs)
		di (`tdcest3'/`tdcavg_est')*100

	* Estimated TDC
	esttab est2 est4 est6, keep(hhhpla) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001) ar2
	esttab est2 est4 est6, keep(hhhpla) p compress 
	
	* Actual TDC
	esttab est1 est3 est5, keep(hhhpla) se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001) ar2
	esttab est1 est3 est5, keep(hhhpla) p compress 

	* Estimated TDC (all coefficients)
	esttab est2 est4 est6 using "$path/output/pla_ests_estimated_tdc_all_coeffs.rtf", se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001) ar2 replace

	* Actual TDC (all coefficients)
	esttab est1 est3 est5 using "$path/output/pla_ests_actual_tdc_all_coeffs.rtf", se compress star starlevel(+ 0.10 * 0.05 ** 0.01 *** 0.001) ar2 replace
		
		**** COEFFICIENT PLOT FOR MAIN TEXT of estimates for specification 2 (estimated and actual TDC outcomes) ****
		eststo clear 
		drop mod*sample 
		
		lab var hhhpla "Actual TDC per unit"	
		* Model 2: TDC reg w/LAHD costs
		eststo est1: qui reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if inservice==1 & sample1==1 // Model 2

		gen mod2sample = e(sample)
		tab hhhproject pla if mod2sample==1 

		* estimate as percent of cost of avg HHH project of 50-64 units (actual costs)
		di (`tdcact2'/`tdcavg_act')*100

		gen hhhpla1 = hhhpla
		lab var hhhpla1 "Estimated TDC per unit"
* Model 2: same TDC reg w/orig estimated costs
		eststo est0: qui reg `outcome2' hhhpla1 prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.year2 if mod2sample==1   // Model 2 with estimated TDC using same sample as above	

		* estimate as percent of cost of avg HHH project of 50-64 units (estimated costs)
		di (`tdcest2'/`tdcavg_est')*100

		coefplot est0 est1, keep(hhhpla1 hhhpla) xline(0) scheme(lean2) msymbol(O) xtitle("Estimated PLA Cost Effect ($1000s)") legend(off) mlabel(cond(@pval<.001, string(@b, "%9.2fc") + "***", cond(@pval<.01, string(@b, "%9.2fc") + "**", cond(@pval<.05, string(@b, "%9.2fc") + "*", string(@b, "%9.2fc")))) ) mlabposition(12) 
		graph export "$path/output/main_mod2est_results_estimated_actual.png", replace

	
	restore

***** Chapter 3: Mean TDC per unit diffs w/ and w/out regression adjustment for model controls (tables 3.2 and 3.3) ******

local outcome1 tdcunit_alt_adj
local outcome2 tdcunit2_adj
local landcost landcostunit2_adj

eststo clear
	preserve
	drop if hhhpla==1 & hhhplaalt==0 
	keep if `outcome1'>0 & `outcome1'!=. & inservice==1
	keep if pla_expected==1
	qui summ units if tdcunit!=., d 
	local p5=r(p5)
	local p95=r(p95)
	cap drop sample* 
	gen sample1 = units>`p5' & units<`p95'
	
	* Model 1: TDC reg w/LAHD costs
	reg `outcome1' prevwage hhhproject unitrun units65 Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 // Model 1

	gen samp = e(sample)

	predict tdcunit_ra, residuals

	* Model 1: TDC reg w/est costs
	reg `outcome2' prevwage hhhproject unitrun units65 Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.year2 if samp==1  // Model 1

	predict tdcunit2_ra, residuals

	di "Outcome 1 is `outcome1'"
	di "Outcome 2 is `outcome2'"
	
	* difference in TDC/unit estimated versus actual by PLA status 
	gen tdcdiffunit = `outcome1' - `outcome2'
	gen tdcdiffunit_ra = tdcunit_ra - tdcunit2_ra

	* means of HHH-funded projects (PLA and non-PLA)
	bys hhhpla: summ `outcome2' if samp==1 & hhhproject==1
	bys hhhpla: summ `outcome1' if samp==1 & hhhproject==1
	bys hhhpla: summ tdcdiffunit if samp==1 & hhhproject==1
	bys hhhpla: summ tdcdiffunit_ra if samp==1 & hhhproject==1

	* means of non-HHH-funded projects ("PLA-sized" and "non-PLA" sized projects)
	bys pla: summ `outcome2' if samp==1 & hhhproject==0
	bys pla: summ `outcome1' if samp==1 & hhhproject==0
	bys pla: summ tdcdiffunit if samp==1 & hhhproject==0
	bys pla: summ tdcdiffunit_ra if samp==1 & hhhproject==0

	reg tdcdiffunit hhhpla if samp==1
	reg tdcdiffunit_ra hhhpla if samp==1
	
	* explore heterogeneity in cost changes for PLA projects by size 
	tab units if hhhpla==1 & samp==1
	tab units if pla==1 & hhhproject==0 & samp==1
	* suggests a good split is 90 (half the HHH PLA sample)
	
	* means of HHH-funded PLA projects above and below 90 units
	summ `outcome2' if samp==1 & hhhpla==1 & units<=90
	summ `outcome2' if samp==1 & hhhpla==1 & units>90

	summ `outcome1' if samp==1 & hhhpla==1 & units<=90
	summ `outcome1' if samp==1 & hhhpla==1 & units>90

	summ tdcdiffunit if samp==1 & hhhpla==1 & units<=90
	summ tdcdiffunit if samp==1 & hhhpla==1 & units>90

	summ tdcdiffunit_ra if samp==1 & hhhpla==1 & units<=90
	summ tdcdiffunit_ra if samp==1 & hhhpla==1 & units>90

	* means of non-HHH-funded PLA projects above and below 90 units
	summ `outcome2' if samp==1 & hhhproject==0 & pla==1 & units<=90
	summ `outcome2' if samp==1 & hhhproject==0 & pla==1 & units>90

	summ `outcome1' if samp==1 & hhhproject==0 & pla==1 & units<=90
	summ `outcome1' if samp==1 & hhhproject==0 & pla==1 & units>90

	summ tdcdiffunit if samp==1 & hhhproject==0 & pla==1 & units<=90
	summ tdcdiffunit if samp==1 & hhhproject==0 & pla==1 & units>90

	summ tdcdiffunit_ra if samp==1 & hhhproject==0 & pla==1 & units<=90
	summ tdcdiffunit_ra if samp==1 & hhhproject==0 & pla==1 & units>90

********* Chapter 3: Mean differences in completion time for PLA and non-PLA projects (table 3.4) ************
	* HHH projects subject and not subject to PLA
	bys hhhpla: summ projyrs if samp==1 & hhhproject==1
	reg projyrs hhhpla if samp==1 & hhhproject==1 
	
	* HHH and non-HHH projects above PLA threshold	
	bys hhhproject: summ projyrs if samp==1 & pla==1
	reg projyrs hhhproject if samp==1 & pla==1 
	
restore 

**** ASSESSMENT OF POTENTIAL BIAS IN PLA EFFECT FROM INACCURATE LAND COSTS (discussed in footnote/appendix) ****
	set seed 123456789
	gen randnum = runiform()
	
		* Estimate with no random land cost drops 
		reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop `landcost' i.yearalt2 if inservice==1 
	
		* Estimate with random land cost drops (~20%)
		gen landcostalt = `landcost'
		tab units if hhhproject==1 & randnum<.2
		replace landcostalt=0 if hhhproject==1 & randnum<.2
		reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop landcostalt i.yearalt2 if inservice==1 

		drop landcostalt 

		* Estimate with nonrandom land cost drops among larger projects (~20%)
		gen landcostalt = `landcost'
		tab units if hhhpla==1 & randnum<.2
		replace landcostalt=0 if hhhpla==1 & randnum<.2
		reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop landcostalt i.yearalt2 if inservice==1 

		drop landcostalt 

		* Estimate with nonrandom land cost drops among smaller projects (~20%)
		gen landcostalt = `landcost'
		tab units if hhhpla==0 & hhhproject==1 & randnum<.2
		replace landcostalt=0 if hhhpla==0 & hhhproject==1 & randnum<.2
		reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop landcostalt i.yearalt2 if inservice==1 

		replace landcostalt=0 if hhhproject==1 & randnum<.2
		
		* Estimate with no land cost controls
		reg `outcome1' hhhpla prevwage hhhproject unitrun units65 pla Stories Stories2 story6 twobrplus_share sh_share totalresidentialbuildings family specpop i.yearalt2 if inservice==1 
	


