#!/bin/sh -l
#BSUB -J pdd
#BSUB -e Err3
#BSUB -o Out3
#BSUB -q s_long
#BSUB -P 0784

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_cdo
set -euvx

input_dir_out=dummy_dir/TEMPORARY
f_root=dummy_f

#list_params="169.128 175.128"
tmp="swrd lwrd"
dim=`echo $tmp|wc -w`
dim_m1=$(($dim - 1))
vfinal=(`echo $tmp|tr ' ' '\n'`)

cd $input_dir_out

YYMMDDini=$1
YYMMDD=${YYMMDDini}
for par in  `seq 0 $dim_m1`; do
    vname=${vfinal[$par]}
    echo $par | cut -d. -f1
    echo "decumulating 1-hour $vname dividing by 3600s (J->W)"

        yy_st=$(echo $YYMMDD | cut -c 1-4)
        mm_st=$(echo $YYMMDD | cut -c 5-6)
        dd_st=$(echo $YYMMDD | cut -c 7-8)
        f=${f_root}_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
        mv $f ${f}_cum && cdo divc,3600. ${f}_cum $f && rm -f ${f}_cum
done

#list_params_n="228.128 144.128"
tmp2="precip snow" 
dim2=`echo $tmp2|wc -w`
dim2_m1=$(($dim2 - 1))
vfinal2=(`echo $tmp2|tr ' ' '\n'`)

for par in `seq 0 $dim2_m1` ; do
    vname=${vfinal2[$par]}
    echo $par | cut -d. -f1
    echo "decumulating 1-hour $vname dividing by 3.6 (m->kg/m^2/s)"

        yy_st=$(echo $YYMMDD | cut -c 1-4)
        mm_st=$(echo $YYMMDD | cut -c 5-6)
        dd_st=$(echo $YYMMDD | cut -c 7-8)
        f=${f_root}_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
        mv $f ${f}_cum && cdo divc,3.6 ${f}_cum $f && rm -f ${f}_cum
done

