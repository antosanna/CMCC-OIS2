#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
if [[ $# -eq 0 ]]
then
   yyyy=`date +%Y`
   mm=`date +%m`
else
   yyyy=$1
   mm=$2
fi
LOG_FILE=$OIS2_logdir/input_data_download/input_data_download_${yyyy}${mm}_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
# data are assimilated from October to March yet the procedure is submitted everyday
mkdir -p ${OIS2_logdir}/CRYOSAT_SIT
ic=0
while [[ $ic -le 2 ]]
do
   im=`date -d "$yyyy${mm}15 -$ic month" +%m` 
   iyyyy=`date -d "$yyyy${mm}15 -$ic month" +%Y` 
   $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_SIT -l ${OIS2_logdir}/CRYOSAT_SIT -d $OIS2_input/SIT/CryoSat_SMOS_merged -M 1GB -s get_sit.sh -i "$iyyyy $im"
   ic=$(($ic + 1))
done
# from 202410 analysis not in use
#mkdir -p ${OIS2_logdir}/PIOMAS_SIT
#$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_SIT_PIOMAS -l ${OIS2_logdir}/PIOMAS_SIT -d $OIS2_input/SIT/PIOMAS -M 1GB -s get_PIOMAS.sh -i "$yyyy"

mkdir -p ${OIS2_logdir}/OSISAF_SIC
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_SIC -l ${OIS2_logdir}/OSISAF_SIC -d $OIS2_input/SIC/OSISAF -M 1GB -s get_nrt_oper.sh 

mkdir -p ${OIS2_logdir}/SLA
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_SLA -l ${OIS2_logdir}/SLA -d $OIS2_input/SLA -M 5GB -s submit_download_interp_operational.sh 

mkdir -p ${OIS2_logdir}/cobe_SST
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_cobe_SST -l ${OIS2_logdir}/cobe_SST -d $OIS2_input/SST/cobe -M 1GB -s download_cobe_operational.sh

mkdir -p ${OIS2_logdir}/ers_SST
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_ers_SST -l ${OIS2_logdir}/ers_SST -d $OIS2_input/SST/ers -M 1GB -s download_ers_operational.sh

mkdir -p ${OIS2_logdir}/ESACCI_SST
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_ESACCI_SST -l ${OIS2_logdir}/ESACCI_SST -d $OIS2_input/SST/ESACCI -M 1GB -s submit_download_operational.sh 

mkdir -p ${OIS2_logdir}/EN4
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_EN4 -l ${OIS2_logdir}/EN4 -d $OIS2_input/EN4 -M 5GB -s download_EN4.sh 

$OIS2_input/ECMWF_FORCINGS/launch_postproc_ECMWF.sh   # log in $OIS2_logdir/ECMWF_FORCINGS/launch_preproc_`date +%Y%m%d%H%M`

mkdir -p ${OIS2_logdir}/data_preproc
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $parallelq_s -j data_preproc -l ${OIS2_logdir}/data_preproc -d $OIS2_input/data_preproc -M 40GB -s run_prepobs_to_assim.sh 

