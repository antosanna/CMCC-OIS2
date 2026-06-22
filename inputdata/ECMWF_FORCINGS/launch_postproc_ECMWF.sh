#!/bin/sh -l
# this can be submitted daily by crontab without input (today)

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
LOG_FILE=$OIS2_logdir/ECMWF_FORCINGS/launch_preproc_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
if [[ $# -eq 2 ]]
then
   YYMMDDini=$1
   YYMMDDend=$2
#   YYMMDDini=20241001
#   YYMMDDend=20250507
elif [[ $# -eq 1 ]]
then
   YYMMDDend=$1
   #tmpdate=`ls $OIS2_work/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/*y????m??d??.nc|tail -1|rev|cut -d '.' -f2|cut -d '_' -f1|rev`   # get last processed date from files
   tmpdate=`ls $OIS2_data/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/*y????m??d??.nc|tail -1|rev|cut -d '.' -f2|cut -d '_' -f1|rev`   # get last processed date from files
   yyyy=`echo $tmpdate|cut -c 2-5`;mm=`echo $tmpdate|cut -c 7-8`;dd=`echo $tmpdate|cut -c 10-11`
   YYMMDDini=$yyyy$mm$dd
else
   YYMMDDend=`date +%Y%m%d -d "-3day"`  #download of data from mars completes by 10pm 2 days prior to today
   #tmpdate=`ls $OIS2_work/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/*y????m??d??.nc|tail -1|rev|cut -d '.' -f2|cut -d '_' -f1|rev`   # get last processed date from files
   tmpdate=`ls $OIS2_data/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/*y????m??d??.nc|tail -1|rev|cut -d '.' -f2|cut -d '_' -f1|rev`   # get last processed date from files
   yyyy=`echo $tmpdate|cut -c 2-5`;mm=`echo $tmpdate|cut -c 7-8`;dd=`echo $tmpdate|cut -c 10-11`
   YYMMDDini=$yyyy$mm$dd
fi
DIR_EDA=$OIS2_input/ECMWF_FORCINGS/EDA/
WK_EDA=$OIS2_work/ECMWF_FORCINGS/EDA/em_daily
mkdir -p ${OIS2_logdir}/ECMWF_FORCINGS/EDA/em_daily

$DIR_UTIL_OIS2/submitcommand.sh  -M 3000 -m $machine -q $serialq_l -j preproc_EDA_em -l ${OIS2_logdir}/ECMWF_FORCINGS/EDA/em_daily -d ${DIR_EDA} -s preproc_EDA.sh -i "em $YYMMDDini $YYMMDDend"
for member in p1 p4 p6 p8
do
   WK_EDA=$OIS2_work/ECMWF_FORCINGS/EDA/${member}_daily
   mkdir -p ${OIS2_logdir}/ECMWF_FORCINGS/EDA/${member}_daily
   rsync -av $DIR_EDA/preproc_EDA.sh $WK_EDA
   mkdir -p ${OIS2_logdir}/ECMWF_FORCINGS/EDA/${member}_daily
   $DIR_UTIL_OIS2/submitcommand.sh -M 3000 -m $machine -q $serialq_l -p preproc_EDA_em -j preproc_EDA_${member} -l ${OIS2_logdir}/ECMWF_FORCINGS/EDA/${member}_daily -d ${WK_EDA} -s preproc_EDA.sh -i "$member $YYMMDDini $YYMMDDend"
done
#
DIR_ERA5=$OIS2_input/ECMWF_FORCINGS/ERA5_daily/
WK_ERA5=$OIS2_work/ECMWF_FORCINGS/ERA5_daily
mkdir -p ${OIS2_logdir}/ECMWF_FORCINGS/ERA5_daily
mkdir -p $WK_ERA5/logs
rsync -av $DIR_ERA5/preproc_ERA5.sh $WK_ERA5
$DIR_UTIL_OIS2/submitcommand.sh  -M 5000 -m $machine -q $serialq_l -j preproc_ERA5 -l ${OIS2_logdir}/ECMWF_FORCINGS/ERA5_daily -d ${WK_ERA5} -s preproc_ERA5.sh -i "$YYMMDDini $YYMMDDend"
