#!/bin/ksh
#BSUB -e Err12
#BSUB -o Out12
#BSUB -q s_long
#BSUB -M 80G
#BSUB -P 0574


set -x

MEMB=p1
input_dir_em=/work/cmcc/aspect/ECMWF_FORCINGS/EDA/em_daily/ARCHIVE/
input_dir_out=/work/cmcc/aspect/ECMWF_FORCINGS/EDA/${MEMB}_daily/TEMPORARY/


set -A vfinal q10m t10m

cd $input_dir_out

mkdir -p ../ANOM

id=0
for par in {0..1} ; do
        vname=${vfinal[$id]}
        for f in ECMWF_${MEMB}_${vname}_*.nc ; do 
           fem=$(echo $f | sed "s/_${MEMB}_/_em_/g")
           ncdiff $f ${input_dir_em}/$fem -O ../ANOM/ANOM_$f
        done
        id=$(( $id + 1 ))
done


