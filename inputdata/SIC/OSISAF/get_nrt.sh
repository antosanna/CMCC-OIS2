#!/bin/sh -l
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/download_SIC_%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/download_SIC_%J.err
#BSUB -J dowonload_SIC
#BSUB -q s_long
#BSUB -P 0490
#BSUB  -M 3G
#https://thredds.met.no/thredds/catalog/osisaf/met.no/reprocessed/ice/conc_cra_files/2025/05/catalog.html

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
wget="/usr/bin/wget --inet4-only"

ys=2025
ye=2025
mm_min=3
mm_max=5

y=$ys
mkdir -p $OIS2_work/inputdata/SIC/OSISAF/TEMPORARY
cd $OIS2_work/inputdata/SIC/OSISAF/TEMPORARY
while [ $y -le $ye ]; do
  mkdir -p $OIS2_work/inputdata/SIC/OSISAF/$y
  for m in $(eval echo {$((${mm_min}))..${mm_max}}); do
    mm=`printf "%02d" $m`
#    ftd="ftp://osisaf.met.no/reprocessed/ice/conc-cont-reproc/v1p2/$y/$mm"
#    $wget $ftd/*ease-125* || exit -2
    ftd="ftp://osisaf.met.no/reprocessed/ice/conc-cont-reproc/v3p0/$y/$mm"
	   $wget $ftd/*ease2-250*
    for f in ice*.nc; do
      hh=`echo $f | cut -d_ -f3`
      dd=`echo $f | cut -d_ -f6 | cut -c 1-8`
      gzip $f
      mv $f.gz $OIS2_work/inputdata/SIC/OSISAF/$y/ice2_${hh}_${dd}.nc.gz || exit 3
    done
  done
  y=$(( $y + 1 ))
done
