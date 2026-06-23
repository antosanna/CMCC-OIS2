#!/bin/sh -l
#BSUB -e Err_anom
#BSUB -o Out_anom
#BSUB -q s_long
#BSUB -P 0784

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo

set -xuve

MEMB=member
input_dir_em_temp=$OIS2_work/ECMWF_FORCINGS/EDA/em_daily/TEMPORARY/
input_dir_em=$OIS2_work/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/
mkdir -p $input_dir_em
input_dir_out=$OIS2_work/ECMWF_FORCINGS/EDA/${MEMB}_daily/ARCHIVE/

em_arch_dir=$OIS2_data/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE

tmp="q2m t2m td2m sp mslp sst wind10m precip snow swrd lwrd t10m q10m"
dim=`echo $tmp|wc -w`
dim_m1=$(($dim - 1))
vfinal=(`echo $tmp|tr ' ' '\n'`)

cd $input_dir_out

mkdir -p $OIS2_work/ECMWF_FORCINGS/EDA/${MEMB}_daily/ANOM

YYMMDDini=$1
YYMMDD=${YYMMDDini}
yy_st=$(echo $YYMMDD | cut -c 1-4)
mm_st=$(echo $YYMMDD | cut -c 5-6)
dd_st=$(echo $YYMMDD | cut -c 7-8)
for par in `seq 0 $dim_m1` ; do
       vname=${vfinal[$par]}
       f=ECMWF_${MEMB}_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
       fem=$(echo $f | sed "s/_${MEMB}_/_em_/g")
       if [[ -f ${input_dir_em_temp}/$fem ]] ; then
          mv ${input_dir_em_temp}/$fem ${input_dir_em}/
       fi

       rsync -auv ${input_dir_em}/$fem $em_arch_dir
   	   cdo sub $f ${em_arch_dir}/$fem $OIS2_work/ECMWF_FORCINGS/EDA/${MEMB}_daily/ANOM/ANOM_$f 
       rm -f $f
done

