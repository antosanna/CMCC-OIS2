#!/bin/sh -l
#BSUB -P 0784
#BSUB -M 1G
#BSUB -q s_long
#BSUB -J download_cryosat2_SIT
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2//logs/download_cryosat2_SIT_%J.err
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2//logs/download_cryosat2_SIT_%J.out

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
YY=$1
MM=$2
mkdir -p $OIS2_work//inputdata/SIT/CryoSat_SMOS_merged/$YY
cd $OIS2_work//inputdata/SIT/CryoSat_SMOS_merged/$YY
wget ftp.awi.de:sea_ice/product/cryosat2_smos/v206/nh/${YY}/${MM}/W_XX*v206*.nc 


