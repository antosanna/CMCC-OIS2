#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
LOG_FILE=$OIS2_logdir/input_data_download/input_data_download_EN4_`date +%Y%m%d%H%M`
exec 3>&1 1>>${LOG_FILE} 2>&1
# data are assimilated from October to March yet the procedure is submitted everyday
mkdir -p ${OIS2_logdir}/EN4
for yyyy in 2025
do
    case $yyyy in
       2025) m0=07;m1=07;;
    esac
    for mm in `seq -w $m0 $m1`
    do
       $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $serialq_l -j download_EN4 -l ${OIS2_logdir}/EN4 -d $OIS2_input/EN4 -M 30GB -s download_EN4.sh -i "$yyyy $mm"
    done
done
