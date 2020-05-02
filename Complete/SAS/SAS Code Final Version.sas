/* Reads the CSV File */
proc import out=bankfull 
datafile="/home/u45403742/Group Project/bank-additional-full.csv"
		dbms=csv replace;
	getnames=yes;
	delimiter=';';
run;

/* Frequency table for to find any Missing Values */
proc freq data=bankfull;
	tables age--y/ nocum nopercent;
run;

/* Renaming of few variables, since showing error while creating plots */
data bankfull;
	set bankfull;
	rename 'emp.var.rate'n=empvarrate;
	rename 'cons.price.idx'n=conspriceidx;
	rename 'cons.conf.idx'n=consconfidx;
	rename 'nr.employed'n=nremployed;
run;

/* Computing summary statistics, generate graphs and finding Outliers */
proc univariate data=bankfull robustscale plot;
	var age duration campaign pdays previous empvarrate conspriceidx consconfidx 
		euribor3m nremployed;
run;

/* Deletion of Outlier in duration */
data bankfull;
	set bankfull;
	if find(Duration, 4918) then
		delete;
run;

data bankfull;
    set bankfull;
    if find(Campaign, 56) then
        delete;      
run;

/* Frequency table to check the removed Outliers */
proc freq data=bankfull;
	tables age--y/ nocum nopercent;
run;

/* How many missing observations does each numeric variable have */
proc means data=bankfull n nmiss mean std min max;
run;

/* how many missing observations does each character variable have */
proc freq data = bankfull;
	table job marital education default housing loan contact month day_of_week poutcome  / cumcol;
run;

/* Are there dependencies among the variables? */
proc sgscatter data=bankfull;
	matrix age duration campaign pdays previous empvarrate conspriceidx 
		consconfidx euribor3m nremployed / diagonal=(histogram kernel);
run;

/*  It is not clear from the Plots to tell the dependencies among variables */

/* Delete rows with "Unknown or Unkno" values */

data bankfull1;
	set bankfull;
	if find(job, "unknown") then delete;
	if find(marital, "unknown") then delete;
	if find(education, "unknown") then delete;
	if find(default, "unknown") then delete;
	if find(housing, "unkno") then delete;
	if find(loan, "unkno") then delete;
run;

/* Drop duration column */
data bankfull1;
    set bankfull1;
    drop duration;
run;

/* Creating correlation table to find the values */
proc corr data=bankfull1;
	var age campaign pdays previous empvarrate conspriceidx consconfidx 
		euribor3m nremployed;
run;

/* Euribo3m & empvarrate (0.97), nremployed & empvarrate (0.90),nremployed & Euribo3m (0.94),
   hence,we will be dropping nremployed & Euribo3m and keeping empvarrate instead */

/* Dropping nremployed & Euribo3m  */

data bankfull1;
   set bankfull1;
   drop nremployed euribor3m;
run;

/* Sorting by the Outcome "y" */
proc sort data = bankfull1;
	by y;
run;

/* Subsetting the data into Testing and Training sets. 
   Strata: To maintain the proportion of "Yes" and "No" in each subset. */
proc surveyselect data = bankfull1 out = banktraintest outall
	samprate = 0.7 seed = 123;
	strata y;
run;

/* Create a new column for clarity of what data is in what dataset. Also remove columns created in
surveyselect step */
data banktraintest;
	set banktraintest;
	if Selected = 1 then Dataset = "Training";
	else Dataset = "Testing";
	drop Selected SelectionProb SamplingWeight;
run;

/* Check to confirm that the subsets were created correctly */
proc freq data = banktraintest;
	tables Dataset*y;
run;

/* Create Training & Testing datasets */
data banktraining;
	set banktraintest;
	if (Dataset = "Training");
run;

data banktesting;
	set banktraintest;
	if (Dataset = "Testing");
run;

/* Simple model fitting and scoring ------------------------------------------------------------------- */
/* Fit simple logistic model */
proc logistic data = banktraining plots(only) = ROC;
	class y job;
	SimpleModel: model y = job;
	score data = banktesting out = SimpleOutput outroc= SimpleROC;
run;

/* AIC: 15822.532, Train AUC: 0.6015, Test AUC: 0.6042 */

/* Complex model fitting and scoring */
/* Fit a full logistic model with backwards elimination*/
proc logistic data = banktraining plots(only) = ROC;
	class y job marital education default housing loan contact month day_of_week poutcome;
	FullModel: model y = age job marital education default housing loan contact 
		month day_of_week campaign pdays previous poutcome empvarrate conspriceidx consconfidx
		/ selection = backward;
	score data = banktesting out = FullOutput outroc= FullROC;
run;

/* AIC: 12700.854, Train AUC: 0.8033, Test AUC: 0.7937 */

/* Fit a logistic model with variables chosen by backwards elimination*/
proc logistic data = banktraining plots(only) = ROC;
	class  y job contact month day_of_week poutcome;
	BackwardsElimModel: model y = job contact month day_of_week campaign pdays poutcome empvarrate conspriceidx consconfidx;
	ROC 'JobModel' job;
	ROC 'ContactModel' contact;
	ROC 'MonthModel' month;
	ROC 'DayofWeekModel' day_of_week;
	ROC 'CampaignModel' campaign;
	ROC 'PdaysModel' pdays;
	ROC 'PoutcomeModel' poutcome;
	ROC 'EmpvarrateModel' empvarrate;
	ROC 'ConspriceidxModel' conspriceidx;
	ROC 'ConsconidxModel' consconfidx;
	score data = banktesting out = BackwardsElimOutput outroc= BackwardsElimROC;
run;

/* AIC: 12679.712, Train AUC: 0.8033, Test AUC: 0.7937 */

/* Create confusion matrix */
proc freq data=BackwardsElimOutput;
	tables F_y*I_y;
run;

