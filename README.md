# Utilities

#### Table of Contents

- NBER recession indicator (SAS & Stata)
- [Construct a panel without time gaps from Compustat](#build_panel)


<a name="build_panel"></a>
### Construct a panel without time gaps from [Compustat](https://wrds-web.wharton.upenn.edu/wrds/query_forms/navigation.cfm?navId=60)

*Step 1*: choose sample period and apply the standard and self-defined filters. 
The combination of `gvkey` and `datadate` is the key that uniquely identifies each observation.
Only keep variables of interest.
```sas
%let yr_beg = 1978;
%let yr_end = 2017;
%let std_comp_filter = ((consol eq 'C') and (indfmt eq 'INDL') and 
                        (datafmt eq 'STD') and (popsrc eq 'D'));
%let comp_sample_period = ("01jan&yr_beg."d le datadate le "31dec&yr_end."d);
%let my_comp_filter = ((fic eq 'USA') and (at gt 0) and (sale gt 0));
%let comp_keys = gvkey datadate;
%let comp_funda_vars = conm sich at sale seq ceq pstk lt mib
                       txditc txdb itcb pstkrv pstkl prcc_f 
                       csho dlc dltt capx ppent ppegt invt ib
                       dp cogs xsga lct lo
;

data _tmp1;
set comp.funda;
where &comp_sample_period. 
  and &std_comp_filter. 
  and &my_comp_filter.
;
keep &comp_keys. &comp_funda_vars.;
run;
```

*Step 2*: build a full yearly series without gap for each `gvkey`.
```sas
proc sql;
create table _tmp11 as
select gvkey , 
       min(year(datadate)) as yr_beg ,
       max(year(datadate)) as yr_end
from _tmp1
group by gvkey
;
quit;

%let nyr = %eval(&yr_end. - &yr_beg.);
data _tmp12;
set _tmp11;
yr_0 = &yr_beg.;
array yr {&nyr.} yr_1 - yr_&nyr.;
do i = 1 to &nyr.;
  yr(i) = yr_0 + i;
end;
drop i;
proc transpose 
  data = _tmp12 
  out = _tmp13 (drop = _name_ 
                rename = (col1 = yr)
                where = (yr_beg le yr le yr_end))
;
by gvkey yr_beg yr_end;
var yr_0 - yr_&nyr.;
run;

proc sql;
create table _tmp2 as
select a.gvkey , a.yr , b.*
from _tmp13 as a
     left join
     _tmp1 as b
on a.gvkey eq b.gvkey and
   a.yr eq year(b.datadate)
order by a.gvkey , a.yr , b.datadate
;
quit;
```

*Step 3*: calculate a group of variables.
Keep only the relevant ones and reorder them.
```sas
data _tmp21;
format gvkey yr datadate
       conm sich at sale ib
       be me_comp debt ol pni 
;
keep gvkey yr datadate 
     conm sich at sale ib
     be me_comp debt ol pni 
;
set _tmp2;
be = coalesce(seq , ceq + pstk , at - lt - mib)
	 + coalesce(txditc , txdb + itcb , 
	            lt - lct - lo - dltt , 0)
	 - coalesce(pstkrv , pstkl , pstk , 0)
;
me_comp = prcc_f * csho;
debt = dlc + dltt;
ol = (cogs + xsga) / at;
pni = ppegt + invt;
run;
```

*Step 4*: keep only the last observation for each `gvkey` each `yr`.
```sas
proc sort data = _tmp21; by gvkey yr datadate;
data _tmp21;
set _tmp21;
by gvkey yr datadate;
if last.yr;
/* check uniqueness of the key */
proc sort data = _tmp21 nodupkey; by gvkey yr; 
run;
```
