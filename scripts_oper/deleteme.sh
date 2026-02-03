#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx


mkdir -p $OIS2_logdir/MONTHLY_SUBMISSION
LOG_FILE=$OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_ois2_submit_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1

#this script submits long analyses starting from the last saturday of 2 months before (to include the entire previous month - incase the first of the month is a saturday it will cover the previous week anyway)

first_prev_month=`date -d "-1 month" +%Y%m`01
days_from_previous_sunday=`date -d "$first_prev_month" +%w`
days_from_previous_saturday=$(($days_from_previous_sunday + 1))
starting_saturday=`date -d "$first_prev_month -$days_from_previous_saturday days" +%Y%m%d`
saturday_before_starting_saturday=`date -d "$starting_saturday -7 days" +%Y%m%d`

today_yymmm1=`date +%Y%m -d "-1 month"`
if [[ ! -f $OIS2_logdir/EN4/donwload_${today_yymmm1}_ok ]]
then
   echo "Today the OIS2 reanalysis cannot run since EN4 from previous month are not available. Exiting now" 
   exit 
fi
#if [[ -f $OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_${today_yymmm1}_submitted ]]
#then
#   echo "The OIS2 reanalysis already submitted. Exiting now" 
#   exit 
#fi
  

# this step update ENDDATE in each run_assum script for every perturbation
$OIS2_scripts/update_assim.sh
#for member in {0..8}
#for member in 0 1 2 7 8 3
for member in {0..8}
do
   
   EXPNAME=OPSLAMB${member}
   configfile=$DIR_CASES_OIS2/$EXPNAME/config
#   echo ${starting_saturday}00 > $configfile
#   echo ${saturday_before_starting_saturday}00 >> $configfile
   tmp=`cat $configfile`
   datetorun=`echo ${tmp:0:10}`
   title="[OIS2] OIS2 $EXPNAME reanalysis assimilation"
   body="OIS2 $EXPNAME going to submit from $datetorun"
   ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"

   if [[ $member -eq 0 ]] ; then
        subm_script=run_assim.sh
   else
        subm_script=run_assim${member}.sh
   fi 
   $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j run_assim_${EXPNAME} -l $DIR_CASES_OIS2/$EXPNAME/logs -d ${DIR_CASES_OIS2}/$EXPNAME -s $subm_script

done
touch $OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_${today_yymmm1}_submitted

