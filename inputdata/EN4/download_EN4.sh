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
ytod=`date +%Y`
mtod=`date +%m`
dtod=`date +%d`
if [[ ${ytod}${mtod} -eq ${y}${m} && $((10#$dtod)) -lt 16 ]]
then
   echo "today is ${ytod}${mtod}${dtod} and EN4 data are not reliable even if available! Exiting now"
   exit 0
fi  

dwn=1
nrt=1 

cd $OIS2_work_inpdir/EN4
cp $sosie_exe .
cp ${OIS2_work_inpdir}/EN4/static/mesh_mask.nc .

EN4_archdir=${OIS2_data}/inputdata/EN4
mkdir -p ${EN4_archdir}

current_yyyymm=$y${m}15
current_yyyymm_m1=$(date +%Y%m%d -d "$current_yyyymm -1 month" )
#dd=$(date +%Y%m%d -d "$current_yyyymm -1 month" | cut -c 1-6 )
#dd_m1=$(date +%Y%m%d -d "$current_yyyymm_m1 -1 month" | cut -c 1-6 )
#dd_m2=$(date +%Y%m%d -d "$current_yyyymm_m1 -2 month" | cut -c 1-6 )
dd=$(date +%Y%m%d -d "$current_yyyymm" | cut -c 1-6 )
dd_m1=$(date +%Y%m%d -d "$current_yyyymm -1 month" | cut -c 1-6 )
dd_m2=$(date +%Y%m%d -d "$current_yyyymm -2 month" | cut -c 1-6 )

url_en4="https://www.metoffice.gov.uk/hadobs/en4/data/en4-2-1"
if [ $dwn -eq 1 ]; then
     wget --inet4-only ${url_en4}/EN.4.2.2.p.analysis.c14.${dd_m2}.nc.gz -O EN.4.2.2.p.analysis.c14.${dd_m2}.nc.gz
     [[ -f "EN.4.2.2.p.analysis.c14.${dd_m2}.nc.gz" ]] &&  gunzip EN.4.2.2.p.analysis.c14.${dd_m2}.nc.gz && mv EN.4.2.2.p.analysis.c14.${dd_m2}.nc EN.4.2.2.f.analysis.c14.${dd_m2}.nc
     wget --inet4-only ${url_en4}/EN.4.2.2.p.analysis.c14.${dd_m1}.nc.gz -O EN.4.2.2.p.analysis.c14.${dd_m1}.nc.gz
     [[ -f "EN.4.2.2.p.analysis.c14.${dd_m1}.nc.gz" ]] &&  gunzip EN.4.2.2.p.analysis.c14.${dd_m1}.nc.gz && mv EN.4.2.2.p.analysis.c14.${dd_m1}.nc EN.4.2.2.f.analysis.c14.${dd_m1}.nc	
fi


for yymm in ${dd_m1} ${dd_m2}; do
    y=$(echo $yymm | cut -c 1-4 )
    mm=$(echo $yymm | cut -c 5-6 )
    if [ -f "EN.4.2.2.f.analysis.c14.${yymm}.nc" ]; then
       cd $OIS2_work_inpdir/EN4   
       fin=EN.4.2.2.f.analysis.c14.${yymm}.nc
       sed -e "s#_FIN_#$fin#g" -e "s#_TS_#${yymm}#g" ${OIS2_input}/EN4/nams_1-475 > nam.tmp
       ./sosie.x -f nam.tmp || exit 1
       sed -e "s#_FIN_#$fin#g" -e "s#_TS_#${yymm}#g" ${OIS2_input}/EN4/namt_1-475 > nam.tmp
       ./sosie.x -f nam.tmp || exit 1
       mv -f vosaline_EN4-ORCA025_${yymm}.nc vosaline_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncrename -h -d z,dep -v gdept_1d,dep vosaline_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncwa -h -d dep,0 -a dep vosaline_EN4-ORCA025_y${y}m${mm}.nc -O sss_EN4-ORCA025_y${y}m${mm}.nc || exit
       
       rsync -auv $OIS2_work_inpdir/EN4/sss_EN4-ORCA025_y${y}m${mm}.nc ${EN4_archdir}
       rsync -auv $OIS2_work_inpdir/EN4/vosaline_EN4-ORCA025_y${y}m${mm}.nc ${EN4_archdir}
       cd  ${EN4_STATIC_dir}
       ln -sf $EN4_archdir/sss_EN4-ORCA025_y${y}m${mm}.nc  .
       ln -sf $EN4_archdir/vosaline_EN4-ORCA025_y${y}m${mm}.nc .
       cd  ${OTHER_STATIC_dir}/T3D
       ln -sf $EN4_archdir/sss_EN4-ORCA025_y${y}m${mm}.nc  .
       ln -sf $EN4_archdir/vosaline_EN4-ORCA025_y${y}m${mm}.nc .
       cd $OIS2_work_inpdir/EN4
       mv -f votemper_EN4-ORCA025_${y}${mm}.nc votemper_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncrename -h -d z,dep -v gdept_1d,dep votemper_EN4-ORCA025_y${y}m${mm}.nc || exit
       ncap2 -h -s "votemper=float(votemper-273.15);" votemper_EN4-ORCA025_y${y}m${mm}.nc -O votemper_EN4-ORCA025_y${y}m${mm}.nc || exit 5
       rsync -auv $OIS2_work_inpdir/EN4/votemper_EN4-ORCA025_y${y}m${mm}.nc ${EN4_archdir}
       cd  ${EN4_STATIC_dir}
       ln -sf $EN4_archdir/votemper_EN4-ORCA025_y${y}m${mm}.nc   .
       cd  ${OTHER_STATIC_dir}/T3D
       ln -sf $EN4_archdir/votemper_EN4-ORCA025_y${y}m${mm}.nc   .
       touch $OIS2_logdir/EN4/donwload_${yymm}_ok
   fi
done
#climatology anomaly is added to the previous month
yy=$(date +%Y%m%d -d "${dd}15" | cut -c 1-4 )
mm=$(date +%Y%m%d -d "${dd}15" | cut -c 5-6 )
m1=$(date +%Y%m%d -d "${dd}15 -1 month" | cut -c 5-6 )
y1=$(date +%Y%m%d -d "${dd}15 -1 month" | cut -c 1-4 )
cd $OIS2_work_inpdir/EN4   

ncks -F -d time_counter,$mm ${OIS2_work_inpdir}/EN4/static/EN4-ORCA025n42_clim.nc -O h1.nc
ncks -F -d time_counter,$m1 ${OIS2_work_inpdir}/EN4/static/EN4-ORCA025n42_clim.nc -O h2.nc
ncdiff -v votemper h1.nc h2.nc -O anom.nc
ncbo -h --op_typ add  votemper_EN4-ORCA025_y${y1}m${m1}.nc anom.nc -O votemper_EN4-ORCA025_y${yy}m${mm}.nc
ncap2 -s "where(votemper < -2. ) votemper = -2." votemper_EN4-ORCA025_y${yy}m${mm}.nc -O votemper_EN4-ORCA025_y${yy}m${mm}.nc

ncdiff -v vosaline h1.nc h2.nc -O anom.nc
ncbo -h --op_typ add  vosaline_EN4-ORCA025_y${y1}m${m1}.nc anom.nc -O vosaline_EN4-ORCA025_y${yy}m${mm}.nc

ncap2 -s "where(vosaline < 0.01 ) vosaline = 0.01" vosaline_EN4-ORCA025_y${yy}m${mm}.nc -O vosaline_EN4-ORCA025_y${yy}m${mm}.nc || exit
ncwa -h -d dep,0 -a dep vosaline_EN4-ORCA025_y${yy}m${mm}.nc -O sss_EN4-ORCA025_y${yy}m${mm}.nc || exit

rsync -auv $OIS2_work_inpdir/EN4/sss_EN4-ORCA025_y${yy}m${mm}.nc ${EN4_archdir}
rsync -auv $OIS2_work_inpdir/EN4/vosaline_EN4-ORCA025_y${yy}m${mm}.nc ${EN4_archdir}
rsync -auv $OIS2_work_inpdir/EN4/votemper_EN4-ORCA025_y${yy}m${mm}.nc ${EN4_archdir}
 
cd  ${EN4_STATIC_dir}
ln -sf ${EN4_archdir}/sss_EN4-ORCA025_y${yy}m${mm}.nc  .
ln -sf ${EN4_archdir}/vosaline_EN4-ORCA025_y${yy}m${mm}.nc .
ln -sf ${EN4_archdir}/votemper_EN4-ORCA025_y${yy}m${mm}.nc .

cd  ${OTHER_STATIC_dir}/T3D
ln -sf ${EN4_archdir}/sss_EN4-ORCA025_y${yy}m${mm}.nc  .
ln -sf ${EN4_archdir}/vosaline_EN4-ORCA025_y${yy}m${mm}.nc .
ln -sf ${EN4_archdir}/votemper_EN4-ORCA025_y${yy}m${mm}.nc .
