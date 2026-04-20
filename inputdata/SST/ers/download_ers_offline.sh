#!/bin/sh -l
#BSUB -P 0784
#BSUB -q s_long
#BSUB -M 1G
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ers_SST/download_erssst_offline.%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ers_SST/download_erssst_offline.%J.err
#BSUB -J download_erssst_offline

. ~/.bashrc 
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco
. $DIR_UTIL_OIS2/load_cdo
set -xeuv

# Files can be downloaded from
# https://www.ncei.noaa.gov/pub/data/cmb/ersst/v5/netcdf/
# OR
# https://downloads.psl.noaa.gov//Datasets/noaa.ersst.v5/sst.mnmean.nc


mkdir -p ${OIS2_work_inpdir}/SST/ers/ARCHIVE
mkdir -p ${OIS2_work_inpdir}/SST/ers/TEMPORARY

cd ${OIS2_work_inpdir}/SST/ers/TEMPORARY
rm -f ${OIS2_work_inpdir}/SST/ers/TEMPORARY/*

climfile=${OIS2_work_inpdir}/SST/ers/static/sst_ers_clim.nc
startdate=20240115
nmax=15

for nmonth in `seq 0 $nmax`
do
  YY=$(date +%Y -d "$startdate +${nmonth} month ")
  MM=$(date +%m -d "$startdate +${nmonth} month ")
  echo $YY$MM
  cp $FLANDREXE flandR.exe
  wget https://www.ncei.noaa.gov/pub/data/cmb/ersst/v5/netcdf/ersst.v5.${YY}${MM}.nc 
  mv ersst.v5.${YY}${MM}.nc ersst.${YY}${MM}.nc
  ncwa -a lev ersst.${YY}${MM}.nc -O ersst.${YY}${MM}.nc
  ncks  --mk_rec_dmn time ersst.${YY}${MM}.nc -O ersst.${YY}${MM}.nc
  ./flandR.exe ersst.${YY}${MM}.nc sst 180 89 1 MISSING_VALUE || exit -1
  ncatted -h -a ,global,d,, ersst.${YY}${MM}.nc

  #to be put on the cobe grid
  cdo remapbil,${OIS2_work_inpdir}/SST/cobe/static/cobe_sst_template.nc ersst.${YY}${MM}.nc ${OIS2_work_inpdir}/SST/ers/sst_y${YY}${MM}.nc && rm -f ersst.${YY}${MM}.nc
  if [[ $nmonth == $nmax ]] ; then

    yp1=`date -d "$YY${MM}15 + 1 month" +%Y`
    mp1=`date -d "$YY${MM}15 + 1 month" +%m`
    mm=${MM}
    yy=${YY}

    ncks -F -d time,$mm  $climfile -O h_${mm}.nc
    ncks -F -d time,$mp1  $climfile -O h_${mp1}.nc
    ncdiff -v sst h_${mp1}.nc h_${mm}.nc -O anom_${mp1}_${mm}.nc
    ncbo -h --op_typ add  ${OIS2_work_inpdir}/SST/ers/sst_y${yy}${mm}.nc  anom_${mp1}_${mm}.nc -O sst_y${yp1}${mp1}.nc
    ncap2 -s "where(sst < -2. ) sst = -2." sst_y${yp1}${mp1}.nc -O ${OIS2_work_inpdir}/SST/ers/sst_y${yp1}${mp1}.nc
  fi

 ncrcat -v sst ${OIS2_work_inpdir}/SST/ers/sst_y${YY}??.nc -O ${OIS2_work_inpdir}/SST/ers/ARCHIVE/sst_y${YY}.nc
done
