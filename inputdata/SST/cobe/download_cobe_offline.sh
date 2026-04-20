#!/bin/sh -l
#BSUB -P 0784
#BSUB -q s_long
#BSUB -M 1G
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/cobe_SST/download_cobesst_offline.%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/cobe_SST/download_cobesst_offline.%J.err
#BSUB -J download_cobesst_offline

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
. $DIR_UTIL_OIS2/load_nco
set -xuev

climfile=${OIS2_work_inpdir}/SST/cobe/static/climatologycobe.nc
mkdir -p $OIS2_work_inpdir/SST/cobe/TEMPORARY
mkdir -p $OIS2_work_inpdir/SST/cobe/ARCHIVE
cd $OIS2_work_inpdir/SST/cobe/TEMPORARY
rm -f $OIS2_work_inpdir/SST/cobe/TEMPORARY/*
cp $FLANDREXE ./flandR.exe

#
#
# NOTE must be interpolated since this is cobe2
#
#cdir=https://ds.data.jma.go.jp/tcc/tcc/products/elnino/cobesst/gpvdata

rm -f sst.mon.mean.nc*
wget ftp://ftp2.psl.noaa.gov/Datasets/COBE2/sst.mon.mean.nc  #&& rm -f sst.mon.mean.nc && mv sst.mon.mean.nc.1 sst.mon.mean.nc

startdate="2024-01-01"
nmax=15
for nmonth in `seq 0 $nmax` 
do
  YY=$(date +%Y -d "$startdate +${nmonth} month ")
  MM=$(date +%m -d "$startdate +${nmonth} month ")

  ymd_in="$YY-$MM-01"
  ymdhms_st="${ymd_in}T00:00:00"
  cdo seldate,${ymdhms_st} sst.mon.mean.nc cobe_sst_y${YY}${MM}.nc

        # Adjust netcdf
#        ncrename -h -v var80,sst cobe_sst_y${YY}${MM}.nc || exit 1
#        ncwa -h -a depth cobe_sst_y${YY}${MM}.nc -O cobe_sst_y${YY}${MM}.nc || exit 2

  ./flandR.exe  cobe_sst_y${YY}${MM}.nc sst 360 180 1 MISSING_VALUE || exit 1
  ncatted -h -a ,global,d,, cobe_sst_y${YY}${MM}.nc

  cdo remapbil,${OIS2_work_inpdir}/SST/cobe/static/cobe_sst_template.nc cobe_sst_y${YY}${MM}.nc ${OIS2_work_inpdir}/SST/cobe/cobesst_y${YY}${MM}.nc  && rm -f cobe_sst_y${YY}${MM}.nc

  if [[ $nmonth == $nmax ]] ; then
      yp1=`date -d "$YY${MM}15 + 1 month" +%Y`
      mp1=`date -d "$YY${MM}15 + 1 month" +%m`
      mm=${MM}
      yy=${YY}
      ncks -F -d time,$mp1 $climfile -O h_${mp1}.nc
      ncks -F -d time,$mm  $climfile -O h_${mm}.nc
      ncdiff -v sst h_${mp1}.nc h_${mm}.nc -O anom_${mp1}_${mm}.nc
      ncbo -h --op_typ add   ${OIS2_work_inpdir}/SST/cobe/cobesst_y${yy}${mm}.nc anom_${mp1}_${mm}.nc -O cobesst_y${yp1}${mp1}.nc
      ncap2 -s "where(sst < -2. ) sst = -2." cobesst_y${yp1}${mp1}.nc -O ${OIS2_work_inpdir}/SST/cobe/cobesst_y${yp1}${mp1}.nc 
  fi
  ncrcat  ${OIS2_work_inpdir}/SST/cobe/cobesst_y${YY}??.nc -O ${OIS2_work_inpdir}/SST/cobe/ARCHIVE/cobesst_y${YY}.nc
done
