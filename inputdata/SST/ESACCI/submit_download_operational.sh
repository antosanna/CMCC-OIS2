#!/bin/sh -l
#BSUB -P 0490
#BSUB -q s_long
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ESACCI_SST/esacci_sst_download_offline_%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ESACCI_SST/esacci_sst_download_offline_%J.err
#BSUB -J esacci_sst_download_offline
#BSUB -M 10G

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
#. ~/load_conda
. ~/load_miniconda
conda activate copern_marine
#PARTIRE DA OTTOBRE
set -xeuv

if [[ $# -eq 0 ]]
then
   YY=`date +%Y`
   MM=`date +%m`
   DD=`date +%d`
   if [[ $DD -lt 3 ]] ; then
      today=`date +%Y%m%d`
      YY=`date -d "$today - 1 month" +%Y`
      MM=`date -d "$today - 1 month" +%m`
   fi
   recover=0
else
   YY=$1
   MM=$2
   recover=1
fi

archdir=$OIS2_work_inpdir/SST/ESACCI/ARCHIVE
mkdir -p $archdir

mkdir -p $OIS2_work/inputdata/SST/ESACCI/$YY

cd $OIS2_work/inputdata/SST/ESACCI
rm -f $OIS2_work/inputdata/SST/ESACCI/$YY/${YY}${MM}*
   
#set +euvx
#conda activate $envcondaOIS2
#set -euvx

export COPERNICUSMARINE_SERVICE_USERNAME=aborrelli
export COPERNICUSMARINE_SERVICE_PASSWORD="A17b#D086x$"
sed -e "s/_MM_/$MM/g;s/_YY_/$YY/g" $OIS2_home/inputdata/SST/ESACCI/download_sst_template.py > download_sst.py
python download_sst.py

set +euvx
. $DIR_UTIL_OIS2/load_nco
set -euvx

dini=01
if [[ $recover -eq 0 ]] ; then
  mlast=`ls -tr $OIS2_work/inputdata/SST/ESACCI/$YY|tail -1|cut -c 5-6`
else
  #the retrieve preserves the date of creation of the files on the remote repo, not using the date of download 
  #in case of recover we want the last retrieved, not the last produced
  mlast=$MM
fi
if [[ $mlast == $MM ]]
then
   cp $FLANDREXE flandR.x
   lastfile=`ls -tr $OIS2_work/inputdata/SST/ESACCI/${YY}/*${YY}${MM}*|tail -1 `
   dlast=`basename $lastfile |cut -c 7-8`
#   dlast=`ls -tr $OIS2_work/inputdata/SST/ESACCI/$YY|tail -1|cut -c 7-8`
   for dd in `seq -w $dini $dlast` ; do

      BB=$(ls -1 $YY/${YY}${MM}${dd}* )
      if [[ $BB == '' ]] 
      then
         echo "missing $BB"
         exit 1
      fi
      if [[ -f $archdir/sst_esa_y${YY}m${MM}d${dd}.nc ]] 
      then
         rm $BB
         continue
      fi
      ncpdq -U $BB -O sst_esa_${YY}${MM}${dd}_temp1.nc
      ncap2 -s 'sst_deg=float(analysed_sst-273.15);where(sst_deg < -10.) sst_deg=0. ' sst_esa_${YY}${MM}${dd}_temp1.nc -O sst_esa_${YY}${MM}${dd}.nc 
      rm -f sst_esa_${YY}${MM}${dd}_temp1.nc
      ./flandR.x sst_esa_${YY}${MM}${dd}.nc sst_deg 7200 3600 1 MISSING_VALUE || exit 1
      ncks --mk_rec_dmn time sst_esa_${YY}${MM}${dd}.nc -O $archdir/sst_esa_y${YY}m${MM}d${dd}.nc 
      rm -f sst_esa_${YY}${MM}${dd}.nc
      cd $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4
      ln -sf $archdir/sst_esa_y${YY}m${MM}d${dd}.nc .
      cd $OIS2_work/inputdata/SST/ESACCI
  done
fi
