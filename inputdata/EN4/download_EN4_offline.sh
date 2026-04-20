#!/bin/sh -l
#BSUB -e Out
#BSUB -o Out
#BSUB -P 0784
#BSUB -q s_long
#BSUB -M 20G
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco
. $DIR_UTIL_OIS2/load_sosie
set -xeuv

if [[ $# -eq 0 ]]
then
   y=`date +%Y`
   m=`date +%m`
else
   y=$1
   m=$2
fi
#out=/archive/ans012/C-GLORSv7/EN4_ORCA025
dwn=1
nrt=1 
cd $OIS2_work_inpdir/EN4
cp $sosie_exe .
cp ${OIS2_work_inpdir}/EN4/static/mesh_mask.nc .
#mkdir -p $out


startdate=20240115
for nmonth in `seq 0 6` ; do

  y=$(date +%Y -d "$startdate +${nmonth} month ")
  mm=$(date +%m -d "$startdate +${nmonth} month ")
  yymm=${y}${mm}


  if [ $dwn -eq 1 ]; then
     wget --inet4-only http://hadobs.metoffice.com/en4/data/en4-2-1/EN.4.2.2.p.analysis.c14.${yymm}.nc.gz -O EN.4.2.2.p.analysis.c14.${yymm}.nc.gz
     [[ -f "EN.4.2.2.p.analysis.c14.${yymm}.nc.gz" ]] &&  gunzip EN.4.2.2.p.analysis.c14.${yymm}.nc.gz && mv EN.4.2.2.p.analysis.c14.${yymm}.nc EN.4.2.2.f.analysis.c14.${yymm}.nc	
  fi

  if [ -f "EN.4.2.2.f.analysis.c14.${yymm}.nc" ]; then

       fin=EN.4.2.2.f.analysis.c14.${yymm}.nc
       sed -e "s#_FIN_#$fin#g" -e "s#_TS_#${yymm}#g" ${OIS2_input}/EN4/nams_1-475 > nam.tmp
       ./sosie.x -f nam.tmp || exit 1
       sed -e "s#_FIN_#$fin#g" -e "s#_TS_#${yymm}#g" ${OIS2_input}/EN4/namt_1-475 > nam.tmp
       ./sosie.x -f nam.tmp || exit 1
       mv -f vosaline_EN4-ORCA025_${yymm}.nc vosaline_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncrename -h -d z,dep -v gdept_1d,dep vosaline_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncwa -h -d dep,0 -a dep vosaline_EN4-ORCA025_y${y}m${mm}.nc -O sss_EN4-ORCA025_y${y}m${mm}.nc || exit
       cd  ${EN4_STATIC_dir}
       ln -sf $OIS2_work_inpdir/EN4/sss_EN4-ORCA025_y${y}m${mm}.nc  .
       ln -sf $OIS2_work_inpdir/EN4/vosaline_EN4-ORCA025_y${y}m${mm}.nc .
       cd  ${OTHER_STATIC_dir}/T3D
       ln -sf $OIS2_work_inpdir/EN4/sss_EN4-ORCA025_y${y}m${mm}.nc  .
       ln -sf $OIS2_work_inpdir/EN4/vosaline_EN4-ORCA025_y${y}m${mm}.nc .
       cd $OIS2_work_inpdir/EN4
       mv -f votemper_EN4-ORCA025_${y}${mm}.nc votemper_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncrename -h -d z,dep -v gdept_1d,dep votemper_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncap2 -h -s "votemper=float(votemper-273.15);" votemper_EN4-ORCA025_y${y}m${mm}.nc -O votemper_EN4-ORCA025_y${y}m${mm}.nc || exit 5
       cd  ${EN4_STATIC_dir}
       ln -sf $OIS2_work_inpdir/EN4/votemper_EN4-ORCA025_y${y}m${mm}.nc   .
       cd  ${OTHER_STATIC_dir}/T3D
       ln -sf $OIS2_work_inpdir/EN4/votemper_EN4-ORCA025_y${y}m${mm}.nc   .
       cd $OIS2_work_inpdir/EN4   
   fi
done
