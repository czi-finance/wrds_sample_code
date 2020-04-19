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

<img src="https://github.com/cziFinEcon/wrds_sample_code/blob/master/img/aapl.png" width="700">   

Without further ado, let's check the code!

