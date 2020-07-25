%macro comp_funda_clean (yr_beg = 1980 , yr_end = 2019 , output_ds = );
/* %let yr_beg = 1978; %let yr_end = 2018; */
%let funda_filter = ((indfmt eq "INDL") and (consol eq 'C') and
                     (popsrc eq 'D') and (datafmt eq "STD") and
                     (fic eq "USA") and (curncd eq "USD") and 
                     (curcd eq "USD") and not missing(at));
%let funda_fncd_filter = ((indfmt eq "INDL") and (consol eq 'C') and
                          (popsrc eq 'D') and (datafmt eq "STD"));
%let secm_filter = (primiss eq 'P' and fic eq "USA" and curcdm eq "USD");
%let comp_sample_period = (&yr_beg. le fyear le &yr_end.);
%let secm_sample_period = ("01jan&yr_beg."d le datadate le "31dec&yr_end."d);;

/* panel variable: gvkey; time variable: fyear and datadate */
%let names_vars = gvkey conm sic naics;
%let funda_keys = gvkey datadate fyear;
%let funda_vars = sich naicsh at sale csho prcc_f seq ceq lct lt
                  dltt mib txditc txdb itcb pstk pstkrv pstkl lo
                  dlc cogs xsga revt xint ebitda
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

data funda_short; set comp.funda;
where &comp_sample_period. and
      &funda_filter.;
keep &funda_keys. &funda_vars.;
proc sort nodupkey; by gvkey datadate;
run;

proc sql;
create table _tmp11 (drop = _gvkey _fyear) as
select a.* , b.*
from _tmp1 as a 
left join funda_short (rename = (gvkey = _gvkey fyear = _fyear)) as b
  on a.gvkey eq b._gvkey and a.fyear eq b._fyear
group by gvkey
having min(_fyear) le fyear le max(_fyear)
;
quit;
proc sort; by gvkey fyear datadate;
data _tmp2;
format gvkey fyear datadate conm sic;
keep gvkey fyear datadate conm
     sic at sale be me bd to pm;
set _tmp11; by gvkey fyear datadate;
/* if last.fyear; */
sic = coalescec(put(sich,4.) , sic);
/* naics = coalesce(naicsh , naics); */
/* naics3 = substr(put(naics , 6. -l) , 1 , 3); */
sale = ifn(missing(sale) , revt , sale);
be = coalesce(seq , sum(ceq , pstk) , sum(at - lt , -mib))
     + coalesce(txditc , sum(txdb , itcb) ,
                lt - lct - lo - dltt , 0)
     - coalesce(pstkrv , pstkl , pstk , 0);
be = ifn(be>0 , be , .);
me = prcc_f * csho; me = ifn(me>0,me,.);
bd = dlc + dltt;
to = sale / ifn(at>0,at,.);
pm = ebitda / ifn(sale>0,sale,.);
/* check uniqueness of the key */
proc sort nodupkey; by gvkey fyear; 
run;

data _tmp21;
keep gvkey datadate me_secm;
set comp.secm;
where &secm_filter. and
      &secm_sample_period.;
me_secm = prccm * cshoq;
rename datadate = mdate;
if not missing(me_secm);
/* check uniqueness of the key */
proc sort nodupkey; by gvkey mdate; 
run;

proc sql;
create table _tmp22 as
select a.gvkey , a.fyear , a.datadate ,
       b.mdate , b.me_secm
from _tmp2 as a
left join _tmp21 as b
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
if bd gt 0 then ml = bd / (me + bd);
if at gt 0 then mb = (at - be + me) / at;
proc sort nodupkey; by gvkey fyear; 
run;

proc sql;
create table _tmp4 as
select a.* , b.at_fn , b.sale_fn
from _tmp3 as a
left join 
  (select * from comp.funda_fncd
   where &comp_sample_period. 
   and &funda_fncd_filter.) as b
  on a.gvkey eq b.gvkey and
     a.fyear eq b.fyear and
     a.datadate eq b.datadate
;
quit;
proc sort nodupkey; by gvkey fyear; 
run;

proc sql;
create table _tmp41 as
select gvkey , datadate , sum(salecs) as sale_gov
from compsegd.seg_customer
where ctype in ('GOVDOM' , 'GOVSTATE' , 'GOVLOC')
group by gvkey , datadate
having sale_gov gt 0
;
create table &output_ds. as
select a.* , b.sale_gov
from _tmp4 as a
left join _tmp41 as b
on a.gvkey eq b.gvkey and
   a.datadate eq b.datadate
;
quit;
proc sort nodupkey; by gvkey fyear; 
run;

proc datasets library = work nolist; save &output_ds.; run; 

%mend comp_funda_clean;

%comp_funda_clean (output_ds = comp_funda_clean);

%let FFP = "[...]/comp_funda_clean.dta";
proc export data = comp_funda_clean outfile = &FFP. replace; run;
