#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
# download always the current and previous year to bridge the gap for year change
set -euvx

yyyy=$1

yyyym1=$(($yyyy - 1))
cd $OIS2_work_inpdir/SIT/PIOMAS

for iy in $yyyym1 $yyyy
do
#   set +euvx
#   sftp anonymous@pscfiles.apl.washington.edu
#   password : anonymous
#   cd /pscfiles/zhang/PIOMAS/data/v2.1/area/
#   get area.H${iy}
#   cd ../heff/
#   get heff.H${iy}
#   set -euvx
#=https://pscfiles.apl.uw.edu/zhang/PIOMAS/data/v2.1/heff
   
   url_piomas=https://pscfiles.apl.uw.edu/zhang/PIOMAS/data/v2.1/
   set +e
   curl  -k -L -n -f -O ${url_piomas}/area/area.H${iy}
   curl -k -L -n -f -O ${url_piomas}/heff/heff.H${iy}  
   curl  -k -L -n -f -O ${url_piomas}/area/area.H${iy}.gz
   curl -k -L -n -f -O ${url_piomas}/heff/heff.H${iy}.gz
   set -e
   if [[ -f area.H${iy}.gz ]] ; then
     gzip -fd area.H${iy}.gz
   fi
   if [[ -f heff.H${iy}.gz ]] ; then
     gzip -fd heff.H${iy}.gz
   fi

   dim_file=`du -sb heff.H${iy} | awk '{print $1};'` # get the dimension of the file downloaded 
   mtot=$(( ${dim_file} / 172800 ))  
   $OIS2_exe/conv_a.x $iy $mtot
   $OIS2_exe/conv.x $iy $mtot

   cdo chname,ice_thickness,area area.H$iy.nc area.tmp.H$iy.nc
   cdo setrtoc,0,0.85,0.85 area.tmp.H$iy.nc area.fix.H$iy.nc
   cdo div heff.H$iy.nc area.fix.H$iy.nc htot.H$iy.nc
   rm area.tmp.H$iy.nc area.fix.H$iy.nc heff.H$iy.nc
   rsync -auv $OIS2_work_inpdir/SIT/PIOMAS/htot.H$iy.nc $OIS2_work_inpdir/SIT/PIOMAS/ARCHIVE
done
