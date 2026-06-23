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
MEMB=$1
YYMMDD=$2

YY=`echo $YYMMDD|cut -c 1-4`
MM=`echo $YYMMDD|cut -c 5-6`
num_memb=`echo $MEMB|cut -c2`
WK_EDA=$OIS2_work/ECMWF_FORCINGS/EDA/p${num_memb}_daily
ARCH_EDA=${OIS2_data}/ECMWF_FORCINGS/EDA/p${num_memb}_daily

mkdir -p ${ARCH_EDA}/ANOM
mkdir -p ${ARCH_EDA}/ARCHIVE

cd $OIS2_work_inpdir/ERA5_PERT/P${num_memb}
for var in "lwrd" "mslp" "precip" "q10m" "q2m" "snow" "sp" "sst" "swrd" "t10m" "t2m" "td2m" "wind10m";
do
   	echo $YY $MM $var $num_memb
    rsync -av $WK_EDA/ANOM/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}d??.nc  $ARCH_EDA/ANOM/.
   	ncrcat -O $ARCH_EDA/ANOM/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}d??.nc $ARCH_EDA/ARCHIVE/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}.nc
   	ln -sf $ARCH_EDA/ARCHIVE/ANOM_ECMWF_p${num_memb}_${var}_y${YY}m${MM}.nc .
done

