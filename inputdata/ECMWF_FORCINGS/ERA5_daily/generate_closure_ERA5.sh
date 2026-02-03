#!/bin/sh -l

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco
. $DIR_UTIL_OIS2/load_cdo

set -euvx
rest=$(ls  ARCHIVE/ERA5_q2m* | tail -1 | rev | cut -d_ -f1 | cut -d. -f2 | rev)

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
      cp ARCHIVE/ERA5_${var}_y${YY}m${MM}d${DD}.nc ARCHIVE/ERA5_${var}_y${Y1}m${M1}d${D1}.nc
      ncap2 -s "time=time+24" ARCHIVE/ERA5_${var}_y${Y1}m${M1}d${D1}.nc -O ARCHIVE/ERA5_${var}_y${Y1}m${M1}d${D1}.nc
   done

   rest=$(date +%Y%m%d -d "$YY$MM$DD +1 days")
   it=$(($it + 1))
done
