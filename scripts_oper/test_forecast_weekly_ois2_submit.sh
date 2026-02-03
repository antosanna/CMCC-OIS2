#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx

# this script submits the analyses that will be run for current month

mkdir -p $OIS2_logdir/WEEKLY_SUBMISSION
LOG_FILE=$OIS2_logdir/WEEKLY_SUBMISSION/weekly_ois2_submit_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1

today_yymmm1=`date +%Y%m -d "-1 month"`
if [[ ! -f $OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_${today_yymmm1}_submitted ]]
then
   echo "Today the OIS2 analysis cannot run since reanalyses not yet run for previous month. Exiting now" 
   exit 
fi

days_from_previous_sunday=`date +%w`
days_from_previous_saturday=$(($days_from_previous_sunday + 1))
starting_saturday=`date -d "-$(($days_from_previous_saturday + 7)) days" +%Y%m%d`
# this variable is not used yet reminds how config is structured
#saturday_before_starting_saturday=`date -d "$starting_saturday -7 days" +%Y%m%d`

# this step update ENDDATE in each run_assum script for every perturbation
$OIS2_scripts/update_assim.sh

for member in 0
do
   
   EXPNAME=OPSLAMB${member}
   configfile=$DIR_CASES_OIS2/$EXPNAME/config
   if [[ -f $configfile ]] ; then
       tmp=`cat $configfile`
       datetorun=`echo ${tmp:0:8}`
       if [[ $datetorun -ne $starting_saturday ]]
       then
          title="[OIS2] OIS2 ERROR $EXPNAME weekly assimilation"
          body="OIS2 $EXPNAME not submittable since config dates are not the expected"
          ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"
          continue
       fi
       title="[OIS2] OIS2 $EXPNAME weekly assimilation"
       body="OIS2 $EXPNAME going to submit from $datetorun"
       ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"

   else
      title="[OIS2] OIS2 ERROR $EXPNAME"
      body="OIS2 $EXPNAME missing $configfile - skipping submission"
      ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"
      continue
   fi
   if [[ $member -eq 0 ]] ; then
        subm_script=run_assim.sh
   else
        subm_script=run_assim${member}.sh
   fi 
   $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j run_assim_${EXPNAME} -l $DIR_CASES_OIS2/$EXPNAME/logs -d ${DIR_CASES_OIS2}/$EXPNAME -s $subm_script

done


