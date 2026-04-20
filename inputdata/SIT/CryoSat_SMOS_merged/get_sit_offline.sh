#!/bin/sh -l
#BSUB -P 0784
#BSUB -M 1G
#BSUB -q s_long
#BSUB -J download_cryosat2_SIT
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2//logs/CRYOSAT_SIT/download_cryosat2_SIT_%J.err
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2//logs/CRYOSAT_SIT/download_cryosat2_SIT_%J.out

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx

#YY=$1
#MM=$2
startdate=20250101
#YY=`date +%Y`
#MM=`date +%m`

for nmonth in `seq 0 3` ; do
  YY=$(date +%Y -d "$startdate +${nmonth} month ")
  MM=$(date +%m -d "$startdate +${nmonth} month ")
  echo $YY
  echo $MM
  mkdir -p $OIS2_work/inputdata/SIT/CryoSat_SMOS_merged/$YY/
  cd $OIS2_work/inputdata/SIT/CryoSat_SMOS_merged/$YY/
  set +e
  wget -N ftp.awi.de:sea_ice/product/cryosat2_smos/v206/nh/${YY}/${MM}/W_XX*v206*.nc .
  set -e
done


