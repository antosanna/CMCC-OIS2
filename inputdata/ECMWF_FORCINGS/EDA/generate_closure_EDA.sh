#!/bin/sh -l
#BSUB -e Err_anom
#BSUB -o Out_anom
#BSUB -q s_long
#BSUB -P 0490

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco

set -xuve

MEMB=member
WK_ANOM=$OIS2_work/ECMWF_FORCINGS/EDA/${MEMB}_daily/ANOM

rest=$(ls  $WK_ANOM/ANOM_ECMWF_${MEMB}_q2m* | tail -1 | rev | cut -d_ -f1 | cut -d. -f2 | rev)

it=1
while [[ $it -le 3 ]]
do
   YY=$(echo $rest | cut -c 2-5)
   MM=$(echo $rest | cut -c 7-8)
   DD=$(echo $rest | cut -c 10-11)
   nextday=$(date +%Y%m%d -d "$YY$MM$DD +1 days")
   Y1=$(echo $nextday | cut -c 1-4)
   M1=$(echo $nextday | cut -c 5-6)
   D1=$(echo $nextday | cut -c 7-8)


   for var in "lwrd" "mslp" "precip" "q10m" "q2m" "snow" "sp" "sst" "swrd" "t10m" "t2m" "td2m" "wind10m";
   do
      cp $WK_ANOM/ANOM_ECMWF_${MEMB}_${var}_y${YY}m${MM}d${DD}.nc $WK_ANOM/ANOM_ECMWF_${MEMB}_${var}_y${Y1}m${M1}d${D1}.nc
      ncap2 -s "time=time+24" $WK_ANOM/ANOM_ECMWF_${MEMB}_${var}_y${Y1}m${M1}d${D1}.nc -O $WK_ANOM/ANOM_ECMWF_${MEMB}_${var}_y${Y1}m${M1}d${D1}.nc
   done

   rest=$(date +%Y%m%d -d "$YY$MM$DD +1 days")
   it=$(($it + 1))
done
