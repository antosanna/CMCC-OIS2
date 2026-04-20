#!/bin/sh -l
#BSUB -P 0784
#BSUB -q s_long
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ESACCI_SST/esacci_sst_download_offline_%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/ESACCI_SST/esacci_sst_download_offline_%J.err
#BSUB -J esacci_sst_download_offline
#BSUB -M 10G

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. ~/load_miniconda
conda activate copern_marine

#PARTIRE DA OTTOBRE

set -xeuv

archdir=$OIS2_work/inputdata/SST/ESACCI/ARCHIVE
mkdir -p $archdir
startdate=20240215
for nmonth in `seq 0 5` ; do

  YY=$(date +%Y -d "$startdate +${nmonth} month ")
  MM=$(date +%m -d "$startdate +${nmonth} month ")
#dou=$(date +%d -d "$today -1 day ")

#tmp for download
   mkdir -p $OIS2_work/inputdata/SST/ESACCI/$YY

   cd $OIS2_work/inputdata/SST/ESACCI
   rm -f $OIS2_work/inputdata/SST/ESACCI/$YY/${YY}${MM}*
   
   export COPERNICUSMARINE_SERVICE_USERNAME=aborrelli
   export COPERNICUSMARINE_SERVICE_PASSWORD="A17b#D086x$"

   sed -e "s/_MM_/$MM/g;s/_YY_/$YY/g" $OIS2_home/inputdata/SST/ESACCI/download_sst_template.py > download_sst.py
   python download_sst.py

   set +euvx
   . $DIR_UTIL_OIS2/load_nco
   set -euvx

   dini=01
   dlast=`${DIR_UTIL_OIS2}/days_in_month.sh $MM $YY`
   cp $FLANDREXE flandR.x
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
      ncap2 -s 'sst_deg=float(analysed_sst-273.15);where(sst_deg < -10.) sst_deg=0. ' sst_esa_${YY}${MM}${dd}_temp1.nc -O sst_esa_${YY}${MM}${dd}.nc && rm -f sst_esa_${YY}${MM}${dd}_temp1.nc
      ./flandR.x sst_esa_${YY}${MM}${dd}.nc sst_deg 7200 3600 1 MISSING_VALUE || exit 1
      ncks --mk_rec_dmn time sst_esa_${YY}${MM}${dd}.nc -O $archdir/sst_esa_y${YY}m${MM}d${dd}.nc 
      rm -f sst_esa_${YY}${MM}${dd}.nc
      cd $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4
      ln -sf $archdir/sst_esa_y${YY}m${MM}d${dd}.nc .
      cd $OIS2_work/inputdata/SST/ESACCI

  
  done
done

exit




#if [ $MM -ne 01 ]; then
#        Y1=$YY
#        M1=$(( $MM -1 ))
#        M1=$( printf "%02d" $M1 )
#else
#        Y1=$(( $YY -1 ))
#        M1=12
#fi


#sed -e "s/_MM_/$M1/g" \
#     -e "s/_YY_/$Y1/g" \
#down_py_tmp.py > down_py.py
#python down_py.py >out.py

