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
for num_memb in 1 4 6 8
do
   for YY in 2024 2025
   do
      case $YY in
        2024)m0=10;m1=12;;
        2025)m0=01;m1=05;;
      esac
      for MM in `seq -w $m0 $m1`
      do
         WK_EDA=$OIS2_work/ECMWF_FORCINGS/EDA/p${num_memb}_daily



         for var in "lwrd" "mslp" "precip" "q10m" "q2m" "snow" "sp" "sst" "swrd" "t10m" "t2m" "td2m" "wind10m";
         do
            	echo $YY $MM $var $num_memb
            	ncrcat -O $WK_EDA/ANOM/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}d??.nc $OIS2_work_inpdir/ERA5_PERT/P${num_memb}/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}.nc
         done
      done
   done
done
