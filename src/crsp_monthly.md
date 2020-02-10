The code below compiles a panel that contains monthly stock information.

```sas
/* only include stocks that are ordinary common shares issued by companies incorporated in the US and listed on the NYSE, AMEX, or NASDAQ */
%let msenames_std_filter = (shrcd in (10 , 11) and exchcd in (1 , 2 , 3));
/* choose sample period */
%let msf_sample_period = ('31jan2018'd le date le '31dec2018'd);

proc sql;
create table _tmp0 as
select a.permno , /* add other vars from msenames if necessary, e.g., a.siccd */
       b.date , b.ret , b.retx , b.prc , 
       b.vol , b.shrout , b.cfacpr , b.cfacshr
from (select * from crsp.msenames 
      where &msenames_std_filter.) as a , 
     (select * from crsp.msf 
      where &msf_sample_period.) as b
where a.permno eq b.permno and
      a.namedt le b.date le a.nameendt
order by a.permno , b.date
;
/* add delisting return */
create table _tmp1 as 
select a.* , b.dlret
from _tmp0 as a 
left join crsp.msedelist as b
  on a.permno eq b.permno and
     intck('mon' , a.date , b.dlstdt) eq 0
order by permno , date
;
quit;

data _tmp2;
format permno mdate ret sz szb turn; /* order the vars */
keep permno mdate ret sz szb turn; /* keep the needed vars */
set _tmp1;
mdate = intnx('mon' , date , 0 , 'e'); format mdate date9.;
ret = (1 + ret) * sum(1 , dlret) - 1; /* adjust for delisting */
if not missing(ret) then ret = min(max(-0.4 , ret) , 0.6); /* winsorizing */
/* adjust price */
if cfacpr eq 0 then p = abs(prc);
else p = abs(prc) / cfacpr;
if p le 0 then p = .;
/* adjust shares outstanding */
if cfacshr eq 0 then tso = shrout * 1000;
else tso = shrout * cfacshr * 1000;
if tso le 0 then tso = .;
sz = p * tso / 1000000; /* market value of the stock at month end */
szb = sz / (1 + retx); /* market value of the stock at month beginning */
turn = vol * 100 / (shrout * 1000) * 100; /* turnover ratio in percentage */
proc sort nodupkey; by permno mdate; /* check uniqueness of the key */
run;

/* a macro provided by WRDS that compiles a link table between crso and compustat */
%macro compress_ccmxpf_lnkhist; 
%let prim_link = %str(linktype in ("LC", "LS", "LU"));
 
proc sql;
create table lnk1 as 
select *
from crsp.ccmxpf_lnkhist
where &prim_link.
order by gvkey, lpermno, lpermco, linkdt, linkenddt
;
quit;
 
data lnk2;
set lnk1;
by gvkey lpermno lpermco linkdt linkenddt;
format prev_ldt prev_ledt yymmddn8.;
retain prev_ldt prev_ledt;
if first.lpermno then do;
	if last.lpermno then do;
	/* Keep this obs if it's the first and last matching permno pair */
		output;           
	end;
	else do;
	/* If it's the first but not the last pair, retain the dates for future use */
		prev_ldt = linkdt;
		prev_ledt = linkenddt;
  	  output;
	end;
end;   
else do;
	if linkdt=prev_ledt+1 or linkdt=prev_ledt then do;
	/* If the date range follows the previous one, assign the previous linkdt value
	to the current - will remove the redundant in later steps. Also retain the
	link end date value */
    	linkdt = prev_ldt;
		prev_ledt = linkenddt;
		output;
	end;
	else do;
	/* If it doesn't fall into any of the above conditions, just keep it and retain the
	link date range for future use*/
		output;
		prev_ldt = linkdt;
		prev_ledt = linkenddt;
	end;
end;
drop prev_ldt prev_ledt;
run;
 
data lnk;
  set lnk2;
  by gvkey lpermno linkdt;
  if last.linkdt;
  /* remove redundant observations with identical LINKDT (result of the previous data step), so that
     each consecutive pair of observations will have either different GVKEY-IID-PERMNO match, or
     non-consecutive link date range
   */
run;
%mend;
%compress_ccmxpf_lnkhist;

proc sql;
create table _tmp3 as 
select distinct a.* , b.gvkey
from _tmp2 as a left join lnk as b
on a.permno eq b.lpermno and
   (b.LINKDT le a.mdate or missing(b.LINKDT)) and
   (b.LINKENDDT gt a.mdate or missing(b.LINKENDDT))
order by permno , mdate
/* group by permno , mdate having count(unique gvkey) gt 1 /* one permno-mdate should be matched to only one gvkey */
;
quit;
proc sort nodupkey; by permno mdate;
run;

%let FFP = "/home/uiuc/chaozi/test.csv"; /* change csv to dta if you need stata file */
proc export data = _tmp3 outfile = &FFP. replace; run;
```
