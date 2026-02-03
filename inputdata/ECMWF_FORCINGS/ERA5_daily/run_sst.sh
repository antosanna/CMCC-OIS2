#!/bin/sh -l

#BSUB -J ERA5tq10m
#BSUB -o ERA5tq10m_%J.out
#BSUB -e ERA5tq10m_%J.err
#BSUB -q s_long
#BSUB -P 0490

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo

set -euvx


input_dir_out=dummy_dir/TEMPORARY
input_dir_arch=dummy_dir/ARCHIVE
f_root=dummy_f
lsm=$2

nx=1440
ny=721

cd ${input_dir_out}
cp $OIS2_exe/TQ210M.x TQ210M.x
ln -fs $lsm mask.nc
YYMMDDini=$1
YYMMDD=${YYMMDDini}
   yy_st=$(echo $YYMMDD | cut -c 1-4)
   mm_st=$(echo $YYMMDD | cut -c 5-6)
   dd_st=$(echo $YYMMDD | cut -c 7-8)
   rest=y${yy_st}m${mm_st}d${dd_st}
   echo $rest
   ./TQ210M.x ${f_root}_t2m_${rest}.nc ${f_root}_q2m_${rest}.nc ${f_root}_wind10m_${rest}.nc ${f_root}_wind10m_${rest}.nc ${f_root}_sst_${rest}.nc > out.out
   mv ${f_root}_qq10m${rest}.nc ${f_root}_q10m_${rest}.nc 
   mv ${f_root}_tt10m${rest}.nc  ${f_root}_t10m_${rest}.nc
#   mv ${input_dir_out}/${f_root}_*_${rest}.nc ${input_dir_arch}/
