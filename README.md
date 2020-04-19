# Sample SAS Programs for Processing WRDS Data

In this repository, I present a selection of SAS programs that (pre-)process [WRDS](https://wrds-www.wharton.upenn.edu/) data.
My goal is to provide efficient procedures for turning raw data from various WRDS databases (e.g., CRSP, Compustat, IBES, etc.) into clean and well-structured datasets with only variables of interest, which are conducive to econometric analysis that may follow.
By walking through the steps in each program, one can
(1) quickly gain a working knowledge of related raw data (e.g., file structures, variable definitions, etc.),
and (2) understand the role of each step in the relevant prep process.
I believe these programs are well-written and should be pretty straightforward to interpret, even for people who are new to SAS.
They are also very flexible and can be easily customized to fit specific research needs.
You should be able to run these programs smoothly on [SAS Studio](https://wrds-www.wharton.upenn.edu/pages/data/sas-studio-wrds/).
Should you have any questions and see any bugs, please submit an issue or email me at czi.academic@gmail.com.
I am happy to help!

### Table of Contents

- [Construct a firm-year panel without time gap from Compustat]()
- [Compare companies' actual earnings with analysts' forecasts using IBES]()
