# Sample SAS Programs for Processing WRDS Data

In this repository, I present a selection of SAS programs that (pre-)process [WRDS](https://wrds-www.wharton.upenn.edu/) data.
My goal is to provide efficient procedures for turning raw data from various WRDS databases (e.g., CRSP, Compustat, IBES, etc.) into clean and well-structured datasets with only variables of interest, which are conducive to econometric analysis that may follow.
By walking through the steps in each program, one can
(1) quickly gain a working knowledge of related raw data (e.g., file structures, variable definitions, etc.),
and (2) understand the proper steps in the relevant prep processes.
I believe these programs are well-written and should be pretty straightforward to interpret, even for people who are new to SAS.
They are also very flexible and can be easily customized to fit specific research needs.
(I personally have used these programs as building blocks for more complicated projects.)
You should be able to run these programs smoothly on [SAS Studio](https://wrds-www.wharton.upenn.edu/pages/data/sas-studio-wrds/).
Should you have any questions and see any bugs, please submit an issue or email me at czi.academic@gmail.com.
I am happy to help!

### Table of Contents

- [Track companies' fundamentals with variables/measures from financial statements]()
- [Compare companies' actual earnings with analysts' forecasts](#ibes)

<a name="ibes"></a>
## Compare companies' actual earnings with analysts' forecasts

In this program, I build from [IBES](https://wrds-web.wharton.upenn.edu/wrds/query_forms/navigation.cfm?navId=221&_ga=2.202254610.2026535339.1587168594-1066308586.1576595708) a data set that contains US companies' actual *earnings per share* (EPS) for certain fiscal years, along with the corresponding forecasts made by financial analysts prior to earnings announcements.
This data set can be used to address questions like:
- Do analysts make rational predictions?
- What is the impact of surprisingly high/low earnings?
- What is driving the earnings surprises?

As an illustration, I plot the figure below using this data. 
It shows analysts' predictions of **Apple Inc.**'s EPS for the 2019 fiscal year, as well as the actual number that was announced on October 30, 2019. 
One can see that analysts made forecasts throughout the year, and overall, they seem to slightly underestimate Apple's earnings for this fiscal year.

<img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/aapl.png" width="700">   

Without further ado, let's dive into the code!

1. Begin by choosing sample period (e.g., from 1970 to 2020); `pends` and `fpedats` denote fiscal period end.
Extract from `ibes.actu_epsus` the actual EPS data and apply a series of standard filters.
The resulting data set `_tmp0` only covers U.S. firms that report EPS in dollars. 
In this exercise, we focus on annual EPS instead of quarterly EPS (i.e., `pdicity eq  "ANN"`).
Observations with missing announcement dates or EPS values are excluded.
```sas
%let yr_beg = 1970;
%let yr_end = 2020;
%let ibes_actu_period = ("01jan&yr_beg."d le pends le "31dec&yr_end."d);
%let ibes_actu_filter = (measure eq "EPS" and anndats le actdats and
                         curr_act eq "USD" and usfirm eq 1);
%let ibes_detu_period = ("01jan&yr_beg."d le fpedats le "31dec&yr_end."d);
%let ibes_detu_filter = (missing(currfl) and measure eq "EPS" and missing(curr) and
                         usfirm eq 1 and anndats le actdats and report_curr eq "USD" );

data _tmp0;
format ticker pends pdicity anndats value;
set ibes.actu_epsus;
where &ibes_actu_filter.;
if pdicity eq "ANN" and nmiss(anndats , value) eq 0;
keep ticker pends pdicity anndats value;
/* Sanity check: there should be only one observation for a given firm-fiscal period. */
proc sort nodupkey; by ticker pends pdicity;
run;
```
2. Extract from `ibes.detu_epsus` analysts' EPS forecasts and apply a series of standard filters.
The resulting data set `_tmp1` only covers U.S. firms that report EPS in dollars and analysts who report predictions in dollars. 
In this exercise, we only consider one-year-ahead forecasts (i.e., `fpi in ('1')`)
Observations with missing *forecast* announcement dates or predicted EPS values are excluded.
Each broker (`estimator`) may have multiple analysts (`analys`).
Some EPS are on a primary basis while others on a diluted basis, as indicated by `pdf`.
An analyst may make multiple forecasts throughout the period before the actual EPS announcement. 
One can uncomment the last three lines of code to keep only the latest forecast from a given analyst. 
```sas
data _tmp1;
format ticker fpedats estimator analys anndats pdf fpi value;
set ibes.detu_epsus;
where &ibes_detu_filter.;
if fpi in ('1') and nmiss(anndats , value) eq 0;
keep ticker fpedats estimator analys anndats pdf fpi value;
proc sort; by ticker fpedats estimator analys anndats;
/* data _tmp1; set _tmp1; */
/* by ticker fpedats estimator analys anndats; */
/* if last.analys; */
run;
```

