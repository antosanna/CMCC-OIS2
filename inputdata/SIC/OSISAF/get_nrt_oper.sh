#!/bin/sh -l
#BSUB -o out
#BSUB -e err
#BSUB -q s_long
#BSUB -P R000
#BSUB  -M 3G

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -euvx
wget="/usr/bin/wget --inet4-only"

if [[ $# -eq 0 ]]
then
   yy=`date +%Y`
   mm=$(date +%m)
else
   yy=$1
   mm=$2
fi

m1=`date -d "$yy${mm}15 - 1 month" +%m`
y1=`date -d "$yy${mm}15 - 1 month" +%Y`

mkdir -p $OIS2_work_inpdir/SIC/OSISAF/TEMPORARY 
mkdir -p $OIS2_work_inpdir/SIC/OSISAF/$y1
mkdir -p $OIS2_work_inpdir/SIC/OSISAF/$yy

repo=conc-cont-reproc-amsr   #conc-cont-reproc #update oct 2025

#    ftd="ftp://osisaf.met.no/reprocessed/ice/conc-cont-reproc/v1p2/$y/$mm"
#    $wget $ftd/*ease-125* || exit -2
cd $OIS2_work_inpdir/SIC/OSISAF/TEMPORARY

rm -f *ease2-250*_icdr*-*

ftd="ftp://osisaf.met.no/reprocessed/ice/${repo}/v3p0/$y1/$m1"
$wget $ftd/*ease2-250*_icdr*-*

for f in ice*.nc; do
      hh=`echo $f | cut -d_ -f3`
      dd=`echo $f | rev | cut -d_ -f1 | cut -d. -f2 | rev | cut -c 1-8`
      gzip $f
      rm -f ../$y1/ice2_${hh}_${dd}.nc.gz
      mv $f.gz ../$y1/ice2_${hh}_${dd}.nc.gz || exit 3
done



ftd="ftp://osisaf.met.no/reprocessed/ice/${repo}/v3p0/$yy/$mm"
$wget $ftd/*ease2-250*_icdr*-*

for f in ice*.nc; do
      hh=`echo $f | cut -d_ -f3`
      dd=`echo $f | rev | cut -d_ -f1 | cut -d. -f2 | rev | cut -c 1-8`
      gzip $f
      rm -f ../$yy/ice2_${hh}_${dd}.nc.gz
      mv $f.gz ../$yy/ice2_${hh}_${dd}.nc.gz || exit 3
done


