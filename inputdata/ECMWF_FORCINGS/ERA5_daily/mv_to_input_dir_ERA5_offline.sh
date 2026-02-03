#!/usr/bin/sh -l
#BSUB -J mv_ERA5
#BSUB -o ../../../logs/mv_ERA5_%J.out
#BSUB -e ../../../logs/mv_ERA5_%J.err
#BSUB -q s_long
#BSUB -M 1G
#BSUB -P 0490



. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco

set -euvx
WK_ERA5=$OIS2_work/ECMWF_FORCINGS/ERA5_daily



cd $OIS2_work_inpdir/ERA5/ 
for YY in 2024 2025
do
   case $YY in
   2024)m0=10;m1=12;;
   2025)m0=01;m1=05;;
   esac
   for MM in `seq -w $m0 $m1`
   do

      for var in swrd lwrd mslp precip q10m q2m snow sp sst t10m t2m td2m ;
      do 
         echo $YY $MM $var 
         ncrcat -O $WK_ERA5/TEMPORARY/ERA5_${var}_y${YY}m${MM}d??.nc $WK_ERA5/ARCHIVE/Era5_${var}.${YY}-${MM}.nc
         ln -sf $WK_ERA5/ARCHIVE/Era5_${var}.${YY}-${MM}.nc .
      done
      ncrcat -O $WK_ERA5/TEMPORARY/ERA5_wind10m_y${YY}m${MM}d??.nc $WK_ERA5/ARCHIVE/Era5_uv10m.${YY}-${MM}.nc
      ln -sf $WK_ERA5/ARCHIVE/Era5_uv10m.${YY}-${MM}.nc .
   done
done
