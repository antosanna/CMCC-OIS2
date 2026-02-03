#!/bin/sh -l
#BSUB -J copy_restart
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/copy_restart_%J.err
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/copy_restart_%J.out
#BSUB -P 0490
#BSUB -M 1000
#BSUB -q s_medium

. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
set -euvx

for i in `seq 3 4`
do
  inpdir=/work/cmcc/aspect/CESM2/OPSLAMB${i}/2024090700
  inpdir1=/work/cmcc/aspect/CESM2/OPSLAMB${i}/2024091400
   
  rsync -av $inpdir $OIS2_cases/OPSLAMB${i}/
  rsync -av $inpdir1 $OIS2_cases/OPSLAMB${i}/

done
