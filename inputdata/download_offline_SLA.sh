#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
LOG_FILE=$OIS2_logdir/input_data_download/input_data_download_SLA_recover_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
for yyyy in 2024 2025
do
    case $yyyy in
       2024) m0=10;m1=12;;
       2025) m0=01;m1=05;;
    esac
    for mm in `seq -w $m0 $m1`
    do
       $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_SLA -l ${OIS2_logdir}/SLA -d $OIS2_input/SLA -M 1GB -s submit_download_interp_operational.sh -i "$yyyy $mm"
    done
done
