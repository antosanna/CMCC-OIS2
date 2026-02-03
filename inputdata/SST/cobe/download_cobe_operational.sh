#!/bin/sh -l
#BSUB -P 0490
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

if [[ $# -eq 0 ]]
then
   YY=`date +%Y`
   MM=`date +%m`
else
   YY=$1
   MM=$2
fi

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
wget ftp://ftp2.psl.noaa.gov/Datasets/COBE2/sst.mon.mean.nc
last_timestamp=`cdo showtimestamp sst.mon.mean.nc|rev|cut -d ' ' -f1|rev |tail -n1`
mon_last_timestamp=`echo $last_timestamp|cut -d '-' -f2`
year_last_timestamp=`echo $last_timestamp|cut -d '-' -f1`

today=`date +%Y%m`
lastmon=`date +%m -d "${today}15 -1 month"`

if [[ $mon_last_timestamp == $lastmon ]]
then

   climfile=${OIS2_work_inpdir}/SST/cobe/static/climatologycobe.nc
   YY=$year_last_timestamp
   MM=$mon_last_timestamp
 
   cdo seldate,${last_timestamp} sst.mon.mean.nc cobe_sst_y${YY}${MM}.nc

   ./flandR.exe  cobe_sst_y${YY}${MM}.nc sst 360 180 1 MISSING_VALUE || exit 1
   ncatted -h -a ,global,d,, cobe_sst_y${YY}${MM}.nc

   cdo remapbil,${OIS2_work_inpdir}/SST/cobe/static/cobe_sst_template.nc cobe_sst_y${YY}${MM}.nc ${OIS2_work_inpdir}/SST/cobe/MONTHLY/cobesst_y${YY}${MM}.nc  && rm -f cobe_sst_y${YY}${MM}.nc

   yp1=`date -d "$YY${MM}15 + 1 month" +%Y`
   mp1=`date -d "$YY${MM}15 + 1 month" +%m`
   mm=${MM}
   yy=${YY}
   ncks -F -d time,$mp1 $climfile -O h_${mp1}.nc
   ncks -F -d time,$mm  $climfile -O h_${mm}.nc
   ncdiff -v sst h_${mp1}.nc h_${mm}.nc -O anom_${mp1}_${mm}.nc
   ncbo -h --op_typ add   ${OIS2_work_inpdir}/SST/cobe/MONTHLY/cobesst_y${yy}${mm}.nc anom_${mp1}_${mm}.nc -O cobe_sst_y${yp1}${mp1}.nc
   ncap2 -s "where(sst < -2. ) sst = -2." cobe_sst_y${yp1}${mp1}.nc -O ${OIS2_work_inpdir}/SST/cobe/MONTHLY/cobesst_y${yp1}${mp1}.nc 
   ncrcat  ${OIS2_work_inpdir}/SST/cobe/MONTHLY/cobesst_y${yy}??.nc -O ${OIS2_work_inpdir}/SST/cobe/ARCHIVE/cobesst_y${yy}.nc
   cd $OTHER_STATIC_dir/cobesst
   ln -sf ${OIS2_work_inpdir}/SST/cobe/ARCHIVE/cobesst_y${yy}.nc ./sst_y${yy}.nc
   cd $OIS2_work_inpdir/SST/cobe/TEMPORARY
   if [[ $yy -ne $yp1 ]]
   then
      ncrcat  ${OIS2_work_inpdir}/SST/cobe/MONTHLY/cobesst_y${yp1}??.nc -O ${OIS2_work_inpdir}/SST/cobe/ARCHIVE/cobesst_y${yp1}.nc
      cd $OTHER_STATIC_dir/cobesst
      ln -sf ${OIS2_work_inpdir}/SST/cobe/ARCHIVE/cobesst_y${yp1}.nc ./sst_y${yy}.nc
      cd $OIS2_work_inpdir/SST/cobe/TEMPORARY
   fi
fi
