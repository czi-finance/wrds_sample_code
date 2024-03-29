<a name="top"></a>
# Sample SAS Programs for Processing WRDS Data

In this repository, I present a selection of SAS programs that (pre-)process [WRDS data](https://wrds-www.wharton.upenn.edu/) and compute certain variables/measures, as well as conduct some simple analysis.
My goal is to provide efficient procedures for cleaning and transforming raw data from various WRDS databases (e.g., CRSP, Compustat, IBES, etc.) into well-structured datasets that contain only variables of interest and are conducive to econometric analysis.
By walking through the steps in each program, one can
(1) quickly gain a working knowledge of related raw data (e.g., file structures, variable definitions, etc.),
and (2) understand the proper steps in the cleaning and organizing processes.
I believe these programs are well-written and should be pretty straightforward to interpret (even for people who are new to SAS).
They are also very adaptable and can be easily tailored to serve specific research purposes.
(I personally have used these programs as building blocks for more complicated projects.) <!-- I provide a few examples here -->
You should be able to run these programs smoothly on [WRDS SAS Studio](https://wrds-www.wharton.upenn.edu/pages/data/sas-studio-wrds/).
Should you have any questions or find any bugs, please submit an issue or email me at [i@czi.finance](mailto:i@czi.finance).
I will do my best to help!


### Table of Contents
#### Basic programs
- [Examine companies' financial performance over time](#comp)
- [Construct stock portfolios based on past characteristics](#crsp)
- [Compare analysts' forecasts with firms' actual earnings](#ibes)
#### Additional programs
- [Calculate market betas according to Welch (2019)](./src/calc_welch_market_beta.md)


<a name="comp"></a>
## Examine companies' financial performance over time

In this program, I build from [Compustat](https://wrds-web.wharton.upenn.edu/wrds/query_forms/navigation.cfm?navId=60) a data set that contains various financial measures for U.S. companies; they are calculated from **annual** financial statements.
This data set can be used to study and compare the performance of one or more companies over time. 
As an illustration, I plot four figures below using this data. 
The first two shows the market leverage, asset turnover, and profit margin, as well as the asset and sales growth and the market-to-book (assets) ratio for **Tesla Inc.** (`gvkey = 184996`) over the past five fiscal years.
The latter two figures compare Tesla with Ford and GM.

Tesla did not use much leverage in the past five years.
Its market leverage was about 8 percent in the 2015 fiscal year.
That number increased to around 17 percent in 2016 and remained there ever since.
Tesla's asset turnover declined from 50 percent in 2015 to roughly 30-40 percent in 2016-17. 
That number climbed back and reached more than 70 percent in 2018-19, suggesting that Tesla has become more effective in generating sales.
That said, Tesla has not been good at generating profit.
It has a negative profit margin in 2015-18.
That number only turned positive in 2019.
Tesla's book value of assets almost tripled in 2016, which is driven largely by the acquisition of *SolarCity*.
But it has been growing rapidly nonetheless:
Its balance sheet expanded by 38 and 26 percent in 2015 and 2017, respectively; that number slipped to 4 and 15 percent in 2018 and 2019, respectively.
Tesla's sales also increased rapidly.
In particular, its annual sales grew by 73, 68, and 83 percent in 2016, 2017, and 2018, respectively.
But that number declined to less than 15 percent in 2019.
Before the acquisition of *SolarCity*, Tesla's market value of assets was five times its book value, while after the acquisition, that number declined to around three (still a pretty high valuation).

<img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/tsla1.png" width="365"><img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/tsla2.png" width="365">
<img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/compare2.png" width="365"><img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/compare1.png" width="365">

In comparison, Ford and GM used much more leverage: about 70-80 percent for the former, and around 60 percent for the latter.
But their growth seem to have stagnated, with both firms' sales growth hovering around zero. 

Without further ado, let's dive into the code!


1. Begin by defining a set of macro variables that indicate sample period (e.g., from 1950 to 2019), data filters, and financial statement items to include.
Obtain a complete list of covered companies, and construct a *balanced* panel (which I will refer to as the *Panel* hereafter) that spans the full sample period without time gap.
```sas
%let yr_beg = 1950; 
%let yr_end = 2019;
%let funda_filter = ((indfmt eq "INDL") and (consol eq 'C') and
                     (popsrc eq 'D') and (datafmt eq "STD") and
                     (fic eq "USA") and (curncd eq "USD") and 
                     (curcd eq "USD") and not missing(at));
%let funda_fncd_filter = ((indfmt eq "INDL") and (consol eq 'C') and
                          (popsrc eq 'D') and (datafmt eq "STD"));
%let secm_filter = (primiss eq 'P' and fic eq "USA" and curcdm eq "USD");
%let comp_sample_period = (&yr_beg. le fyear le &yr_end.);
%let secm_sample_period = ("01jan&yr_beg."d le datadate le "31dec&yr_end."d);;

/* panel variable: gvkey; time variable: fyear or datadate */
%let names_vars = gvkey conm sic naics;
%let funda_keys = gvkey datadate fyear;
%let funda_vars = sich naicsh at sale csho prcc_f seq ceq lct lt
                  dltt mib txditc txdb itcb pstk pstkrv pstkl lo
                  dlc cogs xsga revt xint xopr oiadp oibdp dp
                  ppegt invt ib ppent dpact
;

proc sort data = comp.names nodupkey
  out = _tmp0 (keep = &names_vars.);
by gvkey;
%let nyr = %eval(&yr_end. - &yr_beg.);
data _tmp0; set _tmp0;
yr_0 = &yr_beg.;
array yr {&nyr.} yr_1 - yr_&nyr.;
do i = 1 to &nyr.;
  yr(i) = yr_0 + i;
end;
drop i;
proc transpose data = _tmp0 
  out = _tmp1 (rename = (col1 = fyear)
               drop = _name_);
by &names_vars.;
var yr_0 - yr_&nyr.;
run;
```

2. Extract only the valid records and the relevant items from the Fundamental Annual file for the given sample period.
Here, only U.S. firm-years with non-missing book value of assets are included.
It is important to do a sanity check and see whether the pair of `gvkey` and `datadate` uniquely identify observations.
```sas
data funda_short; set comp.funda;
where &comp_sample_period. and &funda_filter.;
keep &funda_keys. &funda_vars.;
proc sort nodupkey; by gvkey datadate;
run;
```

3. Add to the *Panel* the relevant financial statement items as well as any variables of interest calculated from them (e.g., book value of equity `be`, market value of equity `me`, book value of debt `bd`, asset turnover `to`, profit margin `pm`, etc.).
For each firm, exclude the preceding and trailing null observations---that is, those earlier (later) than the first (last) available record.
(This makes the *Panel* unbalanced, but significantly reduces its size.)
Note that alternative definitions are used to minimize the instances of missing value. 
Besides, (preliminary) sanity checks are conducted when defining all variables.
```sas
proc sql;
create table _tmp11 (drop = _gvkey _fyear) as
select a.* , b.* from _tmp1 as a left join 
  funda_short (rename = (gvkey = _gvkey fyear = _fyear)) as b
  on a.gvkey eq b._gvkey and a.fyear eq b._fyear
group by gvkey
having min(_fyear) le fyear le max(_fyear)
;
quit;
proc sort; by gvkey fyear datadate;
data _tmp2;
format gvkey fyear datadate conm sic;
keep gvkey fyear datadate conm sic
     at sale ib be me bd PnI to pm ic;
set _tmp11; by gvkey fyear datadate;
/* if last.fyear; */
if not missing(sich) then sic = put(sich , z4.);
/* naics = coalesce(naicsh , naics); */
/* naics3 = substr(put(naics , 6. -l) , 1 , 3); */
/*************** VARIABLE DEFINITION ***************/
be = coalesce(seq , sum(ceq , pstk) , sum(at-lt , -mib))
     + coalesce(txditc , sum(txdb , itcb) ,
                lt - lct - lo - dltt , 0)
     - coalesce(pstkrv , pstkl , pstk , 0);
me = prcc_f * csho; me = ifn(me>0,me,.);
bd = dlc + dltt; bd = ifn(bd>0,bd,.);
ppegt = coalesce(ppegt , ppent+dpact);
PnI = ppegt + invt; PnI = ifn(PnI>0,PnI,.);
sale = ifn(missing(sale) , revt , sale);
to = sale / ifn(at>0,at,.);
oibdp = coalesce(oibdp , sale-xopr , sale-cogs-xsga);
oiadp = coalesce(oiadp , oibdp-dp);
pm = oiadp / ifn(sale>0,sale,.);
ic = oiadp / ifn(xint>0,xint,.);
/* check uniqueness of the key */
proc sort nodupkey; by gvkey fyear; 
run;
```

4. Complement the market value of equity using information from the monthly security file (`comp.secm`).
Consider only the primary equity issue of a company:
use its market capitalization at the end of a fiscal year (or the following quarter-end if the former is unavailable) to represent the market value of equity.
```sas
data _tmp21;
keep gvkey datadate me_secm;
set comp.secm;
where &secm_filter. and &secm_sample_period.;
me_secm = prccm * cshoq; 
if not missing(me_secm);
rename datadate = mdate;
/* check uniqueness of the key */
proc sort nodupkey; by gvkey mdate;
run;

proc sql;
create table _tmp22 as
select a.gvkey , a.fyear , a.datadate ,
       b.mdate , b.me_secm
from _tmp2 as a left join _tmp21 as b
  on a.gvkey eq b.gvkey and
     0 le intck('mon' , a.datadate , b.mdate) le 3
order by a.gvkey , a.fyear , a.datadate , b.mdate
;
quit;
proc transpose data = _tmp22 out = _tmp23 (drop = _name_)
  prefix = me_secm; 
var me_secm;
by gvkey fyear datadate; 
data _tmp3;
drop me_secm me_secm1 - me_secm2;
merge _tmp2 _tmp23;
by gvkey fyear datadate;
me_secm = coalesce(of me_secm1 - me_secm2);
me = coalesce(me , me_secm); me = ifn(me>0,me,.);
/*************** VARIABLE DEFINITION ***************/
ml = bd / (me + bd);
bm = be / me;
proc sort nodupkey; by gvkey fyear; 
run;
```

5. Obtain the footnotes for certain data items from the Fundamental Annual Footnote file. 
They can be used to identify and filter out extreme values caused by some extraordinary corporate actions/events (e.g., M&A, spin-off, bankruptcy, etc.).
```sas
proc sql;
create table _tmp4 as
select a.* , b.at_fn , b.sale_fn
from _tmp3 as a left join 
  (select * from comp.funda_fncd
   where &comp_sample_period. 
     and &funda_fncd_filter.) as b
  on a.gvkey eq b.gvkey and
     a.datadate eq b.datadate
;
quit;
proc sort nodupkey; by gvkey fyear; 
run;
```

6. *(optional)* Add to the *Panel* companies' sales to major customers (which is reported in `compsegd.seg_customer`).
Here I use the U.S. government as an example: I compute firms' total sales to federal, state, and local governments combined.
```sas
proc sql;
create table _tmp41 as
select gvkey , datadate , sum(salecs) as sale_gov
from compsegd.seg_customer
where ctype in ('GOVDOM' , 'GOVSTATE' , 'GOVLOC')
group by gvkey , datadate
having sale_gov gt 0
;
create table comp_funda_clean as
select a.* , b.sale_gov
from _tmp4 as a left join _tmp41 as b
on a.gvkey eq b.gvkey and
   a.datadate eq b.datadate
;
quit;
proc sort nodupkey; by gvkey fyear; 
run;
```

7. One can export the *Panel* in different formats (e.g., .dta, .csv) conducive to subsequent analysis. 
For example, I use `comp_funda_clean` in Stata to plot those figures above.
```sas
%let FFP = "[The Path to Your Output Folder]/comp_funda_clean.dta";
proc export data = comp_funda_clean outfile = &FFP. replace; run;
```
Note that I use `left join` when adding new variables to the *Panel*, and then check whether the uniqueness of the key is preserved.
I believe this is a good practice that helps prevent unintentionally duplicating or deleting observations when one merges data.
It also helps reveal bugs if there is any.

[Back to top](#top)

<a name="crsp"></a>
## Construct stock portfolios based on past characteristics

<a name="ibes"></a>
## Compare analysts' forecasts with firms' actual earnings

In this program, I build from [IBES](https://wrds-web.wharton.upenn.edu/wrds/query_forms/navigation.cfm?navId=221&_ga=2.202254610.2026535339.1587168594-1066308586.1576595708) a data set that contains US companies' actual *earnings per share* (EPS) for certain fiscal years, along with the corresponding forecasts made by financial analysts prior to the earnings announcements.
This data set can be used to address questions like:
- Do analysts make rational predictions?
- What is the impact of surprisingly high/low earnings?
- What is driving the earnings surprises?

As an illustration, I plot the figure below using this data. 
It shows analysts' predictions of **Apple Inc.**'s EPS for the 2019 fiscal year, as well as the actual number that was announced on October 30, 2019. 
One can see that analysts made forecasts throughout the year, and overall they seem to slightly underestimate Apple's earnings for this fiscal year.

<img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/fig/aapl.png" width="500">   

Without further ado, let's dive into the code!

1. Begin by choosing sample period (e.g., from 1970 to 2020); `pends` and `fpedats` denote fiscal period end.
Extract from `ibes.actu_epsus` the actual EPS data and apply a series of standard filters.
The resulting data set `_tmp0` covers U.S. firms that report EPS in dollars. 
In this exercise, we focus on annual EPS instead of quarterly one (i.e., `pdicity eq  "ANN"`).
Observations with missing announcement dates or EPS values are deleted.
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
where &ibes_actu_period. and &ibes_actu_filter.;
if pdicity eq "ANN" and nmiss(anndats , value) eq 0;
keep ticker pends pdicity anndats value;
/* Sanity check: there should be only one observation for a given firm-fiscal period. */
proc sort nodupkey; by ticker pends pdicity;
run;
```
2. Extract from `ibes.detu_epsus` analysts' EPS forecasts and apply a series of standard filters.
The resulting data set `_tmp1` covers U.S. firms that report EPS in dollars and analysts who report predictions in dollars. 
In this exercise, we only consider one-year-ahead forecasts (i.e., `fpi in ('1')`)
Observations with missing *forecast* announcement dates or predicted EPS values are excluded.
Each broker (`estimator`) may have multiple analysts (`analys`).
Some EPS are on a primary basis while others on a diluted basis, as indicated by `pdf`.
An analyst may make multiple forecasts throughout the period before the actual EPS announcement. 
For each analyst, only her last forecast before an EPS announcement is included. 
Alternatively, one can change the last line of code to keep the last forecast made by a given analyst on a given date.
(Yes, analysts may report multiple forecasts on a given date.)
```sas
data _tmp1;
format ticker fpedats estimator analys anndats pdf fpi value;
set ibes.detu_epsus;
where &ibes_detu_period. and &ibes_detu_filter.;
if fpi in ('1') and nmiss(anndats , value) eq 0;
keep ticker fpedats estimator analys anndats pdf fpi value;
proc sort; by ticker fpedats estimator analys anndats;
data _tmp1; set _tmp1;
by ticker fpedats estimator analys anndats;
if last.analys; * last.anndats;
run;
```

3. Run a WRDS macro to create a link table between IBES TICKER and CRSP PERMNO. 
Keep only high-quality links, and exclude cases where one *ticker* is matched to multiple *permno*.
Create a list of all relevant *permno*, and then extract their price and share adjustment factor from CRSP daily stock file; keep only observations within the sample period.
```sas
%iclink (ibesid = ibes.id , crspid = crsp.stocknames , outset = iclnk);
proc sort data = iclnk (where = (score in (0 , 1 , 2))) 
  uniout = iclnk_uniperm nouniquekey; 
by ticker; run;

proc sort data = iclnk_uniperm nodupkey
  out = allperm (keep = permno); 
by permno; run;

proc sql; 
create table dsf_short as
select a.permno , a.date , a.prc , a.cfacshr 
from crsp.dsf as a , allperm as b
where a.permno eq b.permno and
      a.date ge "01jan&yr_beg."d
;
quit;
```

4. For each firm-fiscal year, obtain the latest stock price and share adjustment factor on/before the earnings announcement date.
```sas
proc sql;
create table _tmp01 as
select a.* , b.permno
from _tmp0 as a , iclnk_uniperm as b
where a.ticker eq b.ticker
order by ticker , pends
;
create table _tmp02 as
select a.* , abs(b.prc) as prc_act , b.cfacshr as adjfac_act
from _tmp01 as a , dsf_short as b
where a.permno eq b.permno and 
      intnx("week" , a.anndats , -1 , 'b') le b.date le a.anndats
group by a.ticker , a.pends , a.anndats
having abs(a.anndats - b.date) eq min(abs(a.anndats - b.date))
order by a.ticker , a.pends , a.anndats
;
quit;
```

5. For each analysts' forecast, obtain the latest share adjustment factor on/before the *forecast* announcement date.
```sas
proc sql;
create table _tmp11 as
select a.* , b.permno
from _tmp1 as a , iclnk_uniperm as b
where a.ticker eq b.ticker
order by ticker , fpedats , estimator , analys , anndats
;
create table _tmp12 as
select a.* , b.cfacshr as adjfac_est
from _tmp11 as a , dsf_short as b
where a.permno eq b.permno and 
      intnx("week" , a.anndats , -1 , 'b') le b.date le a.anndats
group by a.ticker , a.fpedats , a.estimator , a.analys , a.anndats
having abs(a.anndats - b.date) eq min(abs(a.anndats - b.date))
order by a.ticker , a.fpedats , a.estimator , a.analys , a.anndats
;
quit;
```

6. Merge analysts' forecasts with actual EPS. 
To ensure that predicted and actual EPS are based on the same number of shares outstanding, adjust the predicted ones for stock splits etc. using the CRSP share adjustment factor.
(For details, see [A Note on IBES Unadjusted Data](https://wrds-www.wharton.upenn.edu/pages/support/manuals-and-overviews/i-b-e-s/ibes-estimates/wrds-research-notes/note-ibes-unadjusted-data/).)
```sas
proc sql;
create table _tmp2 as
select a.ticker , a.pends as fpedats , a.anndats ,
       a.value as actval , a.prc_act , a.adjfac_act ,
       b.estimator as broker , b.analys , b.anndats as estdats ,
       b.value as estval , b.adjfac_est , b.permno
from _tmp02 as a , _tmp12 as b
where a.ticker eq b.ticker and
     a.pends eq b.fpedats
order by a.ticker, a.pends , a.anndats , b.anndats
;
quit;

data _tmp3; set _tmp2;
if adjfac_est eq 0 then adjfac_est = 1;
if adjfac_act eq 0 then adjfac_act = 1;
estval_adj = estval * coalesce(adjfac_act / adjfac_est , 1);
drop adjfac: estval;
run;
```

7. Compute a number of statistics for analysts' forecasts, 
including the number of analysts who made forecasts in the 9 months prior to earnings announcement,
and their mean (median) forecast.
Also, compute the earnings-to-price ratio as well as two measures of (relative) forecast error.
```sas
proc sql;
create table _tmp4 as
select ticker , permno , fpedats , 
       anndats , actval , prc_act , 
       count(*) as num_analys ,
       mean(estval_adj) as estavg , 
       median(estval_adj) as estmed
from _tmp3
where intnx("mon" , anndats , -9 , 'b') le estdats lt anndats
group by ticker, permno, fpedats, anndats, actval, prc_act
;
quit;
/* Sanity check: there should be only one observation for a given firm-fiscal period. */
proc sort nodupkey; by ticker fpedats;
run;

data _tmp5; set _tmp4;
epratio = actval / prc_act;
ferr1 = (estavg - actval) / prc_act;
ferr2 = (estmed - actval) / prc_act;
run;
```

Finally, one can compute summary statistics for these measures.
```sas
proc means data = _tmp5
  N mean median std skew kurt min p1 p5 p95 p99 max; 
  var num_analys epratio ferr1 ferr2;
run;
```

[Back to top](#top)
