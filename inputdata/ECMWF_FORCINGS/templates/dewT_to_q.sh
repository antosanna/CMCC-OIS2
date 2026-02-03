#!/usr/bin/sh -l
#BSUB -e Err2
#BSUB -o Out2
#BSUB -q s_long
#BSUB -P 0490

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
. $DIR_UTIL_OIS2/load_nco
set -euvx


MEMB=member

input_dir_out=dummy_dir/TEMPORARY/
f_root=dummy_f


nx=1440
ny=721

cd $input_dir_out

YYMMDDini=$1
YYMMDD=${YYMMDDini}
yy_st=$(echo $YYMMDD | cut -c 1-4)
mm_st=$(echo $YYMMDD | cut -c 5-6)
dd_st=$(echo $YYMMDD | cut -c 7-8)
f1="${f_root}_td2m_y${yy_st}m${mm_st}d${dd_st}.nc"
nt=`cdo -ntime $f1`
f2="${f_root}_sp_y${yy_st}m${mm_st}d${dd_st}.nc"
fo="${f_root}_q2m_y${yy_st}m${mm_st}d${dd_st}.nc"

cp "$f1" "$fo" && ncrename -h -v td2m,q2m "$fo"
"$qs_exe" "$f1" td2m "$f2" sp "$fo" q2m "$nx" "$ny" "$nt" f f || exit 2
