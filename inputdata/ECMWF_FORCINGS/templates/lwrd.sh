#!/bin/sh -l
###BSUB -n 35
##BSUB -e Err2
##BSUB -o Out2
##BSUB -P 0784
##BSUB -q s_long

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
set -euvx

input_dir_out=dummy_dir/TEMPORARY/
f_root=dummy_f
lsm=$2
exe=$FLANDREXE

vname="lwrd"
nx=1440
ny=721

cd  $input_dir_out

cp $exe flandR.x2
ln -sf $lsm lsm.nc
YYMMDDini=$1
YYMMDD=${YYMMDDini}
    yy_st=$(echo $YYMMDD | cut -c 1-4)
    mm_st=$(echo $YYMMDD | cut -c 5-6)
    dd_st=$(echo $YYMMDD | cut -c 7-8)
	
    ff=${f_root}_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
    nt=`cdo -ntime $ff`
    ./flandR.x2 ${ff} $vname $nx $ny $nt lsm >out_flr_1 2>>out_flr_1 || exit -1
