#!/usr/bin/sh -l
#BSUB -J mv_ERA5
#BSUB -o logs/mv_ERA5_%J
#BSUB -j logs/mv_ERA5_%J
#BSUB -q s_long
#BSUB -M 1G
#BSUB -P 0784



. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco

set -euvx
YYMMDD=$1
YY=`echo $YYMMDD|cut -c 1-4`
MM=`echo $YYMMDD|cut -c 5-6`
WK_ERA5=$OIS2_work/ECMWF_FORCINGS/ERA5_daily
ARCH_ERA5=${OIS2_data}/ECMWF_FORCINGS/ERA5_daily

cd $OIS2_work_inpdir/ERA5/



for var in "lwrd" "mslp" "precip" "q10m" "q2m" "snow" "sp" "sst" "swrd" "t10m" "t2m" "td2m" ;
do 
   echo $YY $MM $var 
   ncrcat -O $WK_ERA5/TEMPORARY/ERA5_${var}_y${YY}m${MM}d??.nc $ARCH_ERA5/ARCHIVE/Era5_${var}.${YY}-${MM}.nc
   ln -sf $ARCH_ERA5/ARCHIVE/Era5_${var}.${YY}-${MM}.nc .
   #ncrcat -O $WK_ERA5/ARCHIVE/ERA5_${var}_y${YY}m${MM}d??.nc $OIS2_work_inpdir/ERA5/Era5_${var}.${YY}-${MM}.nc
done
#ncrcat -O $WK_ERA5/ARCHIVE/ERA5_wind10m_y${YY}m${MM}d??.nc $OIS2_work_inpdir/ERA5/Era5_uv10m.${YY}-${MM}.nc

ncrcat -O $WK_ERA5/TEMPORARY/ERA5_wind10m_y${YY}m${MM}d??.nc $ARCH_ERA5/ARCHIVE/Era5_uv10m.${YY}-${MM}.nc
ln -sf $ARCH_ERA5/ARCHIVE/Era5_uv10m.${YY}-${MM}.nc .
