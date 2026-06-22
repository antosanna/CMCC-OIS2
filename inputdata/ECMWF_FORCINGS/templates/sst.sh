#!/bin/sh -l
###BSUB -n 35
##BSUB -e Err2a
##BSUB -o Out2a

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
. $DIR_UTIL_OIS2/load_flandR
set -euvx

input_dir_out=dummy_dir/TEMPORARY/
f_root=dummy_f
lsm=$2



vname="sst"


nx=1440
ny=721

exe=$FLANDREXESST

cd  $input_dir_out
cp $exe flandR.x8

ln -sf $lsm lsm.nc
YYMMDD=$1
yy_st=$(echo $YYMMDD | cut -c 1-4)
mm_st=$(echo $YYMMDD | cut -c 5-6)
dd_st=$(echo $YYMMDD | cut -c 7-8)

f=${f_root}_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
nt=`cdo -ntime $f`
echo "${vname} ${nt}"

./flandR.x8 ${f} $vname $nx $ny $nt MISSING_VALUE >out_flr_1 2>>out_flr_1 || exit -1
