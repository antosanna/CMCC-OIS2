#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx

# this script submits the analyses that will be run for current month
tstamp=`date +%Y%m%d`
checkfile=$OIS2_logdir/WEEKLY_SUBMISSION/weekly_ois2_submit_${tstamp}.submitted
if [[ -f $checkfile ]]
then
   exit
fi

mkdir -p $OIS2_logdir/WEEKLY_SUBMISSION
LOG_FILE=$OIS2_logdir/WEEKLY_SUBMISSION/weekly_ois2_submit_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
today_yy=`date +%Y`
today_mm=`date +%m`
today_dd=`date +%d`


if [[ ${today_dd} == "01" ]] ; then
  #launched to produce forecast IC - checking the flag for reanalysis of 2 month before
  today_yymmm4rean=`date -d ' '${today_yy}${today_mm}15' - 2 month' +%Y%m` #`date +%Y%m -d "-2 month"`
  is_forecast=1
  forecast_day=`date +%Y%m%d`
else
  #launched as weekly analysis - checking the flag for reanalysis of 1 month before
  today_yymmm4rean=`date -d ' '${today_yy}${today_mm}15' - 1 month' +%Y%m` #`date +%Y%m -d "-1 month"`   
  #date of the current month explicitly put to 15 to avoid problems on the 31st
  is_forecast=0
  forecast_day="DUMMY"
fi
if [[ ! -f $OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_${today_yymmm4rean}_submitted ]]
then
   echo "Today the OIS2 analysis cannot run since reanalyses not yet run for previous month. Exiting now" 
   exit 
fi

days_from_previous_sunday=`date +%w`
days_from_previous_saturday=$(($days_from_previous_sunday + 1))
starting_saturday=`date -d "-$(($days_from_previous_saturday + 7)) days" +%Y%m%d`

if [[ $is_forecast -eq 0 ]] ; then
   starting_saturday=`date -d "-$(($days_from_previous_saturday + 7)) days" +%Y%m%d`
   #defining explicitely $last_avail_day (even if not strictly necessary) avoids the "false-error" at the end of the weekly run
   #for weekly analysis, last_avail_day is last saturday
   last_avail_day=`date -d "- ${days_from_previous_saturday} days" +%Y%m%d`

else
   if [[ $days_from_previous_sunday -le 1 ]] ; then
      # 1st of the month on Monday (last analysis run until two saturdays 
      # before e.g. forecast 20251201 last restart is 20251122)
      starting_saturday=`date -d "-$(($days_from_previous_saturday + 7)) days" +%Y%m%d`
   else
      starting_saturday=`date -d "- $days_from_previous_saturday days" +%Y%m%d`
   fi
   #1st of the month: last_avail_day is today (default enddate)
   last_avail_day=`date +%Y%m%d`
fi

# this variable is not used yet reminds how config is structured
#saturday_before_starting_saturday=`date -d "$starting_saturday -7 days" +%Y%m%d`


jobsrunning=`$DIR_UTIL_OIS2/findjobs.sh -n OPSLAMB -c yes`
# this step update ENDDATE in each run_assum script for every perturbation
if [[ $jobsrunning -eq 0 ]] ; then
   ${OIS2_scripts}/input2wois_operational.sh
   #DO THE UPDATE ONLY IF THERE ARE NO MEMBERS RUNNING
   $OIS2_scripts/update_assim.sh $last_avail_day

fi

#for member in 0 1 2 7 8
for member in {0..8}
do
   
   EXPNAME=OPSLAMB${member}
   configfile=$DIR_CASES_OIS2/$EXPNAME/config
   if [[ -f $configfile ]] ; then
       tmp=`cat $configfile`
       datetorun=`echo ${tmp:0:8}`
       jobsrunning=`$DIR_UTIL_OIS2/findjobs.sh -n $EXPNAME -c yes`

       if [[ $datetorun -ne $starting_saturday ]]
       then
          if [[ $jobsrunning -eq 0 ]] ; then   #if nothing running, otherwise it is possible that reanalysis is still going on
             title="[OIS2 $machine] OIS2 ERROR $EXPNAME weekly assimilation"
             body="OIS2 $EXPNAME not submittable since config dates are not the expected"
             ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"
          fi
          continue
       fi
       title="[OIS2 $machine] OIS2 $EXPNAME weekly assimilation"
       body="OIS2 $EXPNAME going to submit from $datetorun"
       ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"

   else
      title="[OIS2 $machine] OIS2 ERROR $EXPNAME"
      body="OIS2 $EXPNAME missing $configfile - skipping submission"
      ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$body" -t "$title"
      continue
   fi
   if [[ $member -eq 0 ]] ; then
        subm_script=run_assim.sh
   else
        subm_script=run_assim${member}.sh
   fi
   $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j run_assim_${EXPNAME} -l $DIR_CASES_OIS2/$EXPNAME/logs -d ${DIR_CASES_OIS2}/$EXPNAME -s $subm_script -i "${is_forecast} ${forecast_day}"

done
touch $checkfile

