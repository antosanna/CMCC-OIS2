#!/bin/sh -l

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
. $DIR_UTIL_OIS2/load_flandR
set -euvx

input_dir_out=dummy_dir/TEMPORARY/
f_root=dummy_f
lsm=$2
exe=$FLANDREXE


vname="u10m"

nx=1440
ny=721


cd  $input_dir_out
cp  $exe flandR.x9

ln -sf $lsm lsm.nc
YYMMDDini=$1
YYMMDD=${YYMMDDini}
    yy_st=$(echo $YYMMDD | cut -c 1-4)
    mm_st=$(echo $YYMMDD | cut -c 5-6)
    dd_st=$(echo $YYMMDD | cut -c 7-8)
    f=${f_root}_wind10m_y${yy_st}m${mm_st}d${dd_st}.nc
    nt=`cdo -ntime $f`
    vv=u10m
    echo "${vv} ${nt}"
    ./flandR.x9 ${f} $vv $nx $ny $nt lsm > out_flr_1 2>> out_flr_1 || exit -1

    vv=v10m
    echo "${vv} ${nt}"
    ./flandR.x9 ${f} $vv $nx $ny $nt lsm > out_flr_1 2>> out_flr_1 || exit -1

