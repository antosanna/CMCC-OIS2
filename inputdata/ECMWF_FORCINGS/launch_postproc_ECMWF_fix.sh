#!/bin/sh -l
# this can be submitted daily by crontab without input (today)

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
LOG_FILE=$OIS2_logdir/ECMWF_FORCINGS/launch_preproc_ERA5_fix_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
YYMMDDini=20241001
YYMMDDend=20250501
#
DIR_ERA5=$OIS2_input/ECMWF_FORCINGS/ERA5_daily/
WK_ERA5=$OIS2_work/ECMWF_FORCINGS/ERA5_daily
mkdir -p ${OIS2_logdir}/ECMWF_FORCINGS/ERA5_daily
mkdir -p $WK_ERA5/logs
rsync -av $DIR_ERA5/preproc_ERA5_fix.sh $WK_ERA5
#$DIR_UTIL_OIS2/submitcommand.sh  -M 30000 -m $machine -sla SC_SERIAL_sps35 -app SERIAL_sps35 -q $serialq_l -j preproc_ERA5 -l ${OIS2_logdir}/ECMWF_FORCINGS/ERA5_daily -d ${WK_ERA5} -s preproc_ERA5_fix.sh -i "$YYMMDDini $YYMMDDend"
$DIR_UTIL_OIS2/submitcommand.sh  -M 30000 -m $machine -q $serialq_l -j preproc_ERA5 -l ${OIS2_logdir}/ECMWF_FORCINGS/ERA5_daily -d ${WK_ERA5} -s preproc_ERA5_fix.sh -i "$YYMMDDini $YYMMDDend"
