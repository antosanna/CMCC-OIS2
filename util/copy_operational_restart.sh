#!/bin/sh -l
#BSUB -P 0784
#BSUB -q s_long
#BSUB -J copy_operational_restart 
#BSUB -e /work/cmcc/cp1//CPS/CMCC-CPS1/logs/tests/copy_operational_restart_%J.err
#BSUB -o /work/cmcc/cp1//CPS/CMCC-CPS1/logs/tests/copy_operational_restart_%J.out
#BSUB -M 500M

. $HOME/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx


date_run_rest=2026041800
date_assim=2026042500


###to be modified conveniently: 
## if we want to run on Juno using restart from cassandra -> cassandra
## if we want to run on Cassandra using restart from juno -> juno
machine_from="juno"

for memb in `seq 0 8`
do
   data_dir_rest=/data/cmcc/cp1/CPS/CMCC-OIS2/restart4backup/produced_on_${machine_from}/OPSLAMB${memb}/${date_run_rest}
   data_dir_assim=/data/cmcc/cp1/CPS/CMCC-OIS2/restart4backup/produced_on_${machine_from}/OPSLAMB${memb}/${date_assim}
   data_sla=/data/cmcc/cp1/CPS/CMCC-OIS2/restart4backup/produced_on_${machine_from}/OPSLAMB${memb}/BIAS
   work_dir_rest=$OIS2_WORK/OPSLAMB${memb}/${date_run_rest}/
   work_dir_assim=$OIS2_WORK/OPSLAMB${memb}/${date_assim}/
   mkdir -p ${work_dir_rest}
   mkdir -p ${work_dir_assim}
   rsync -auv ${data_dir_rest}/run ${work_dir_rest}/.
   rsync -auv $data_dir_assim/assim_phy ${work_dir_assim}/.
   rsync -auv $data_dir_assim/assim_ice ${work_dir_assim}/.
   rsync -auv ${data_sla} $OIS2_WORK/OPSLAMB${memb}/.
   if [[ -d  $DIR_CASES_OIS2/OPSLAMB${memb} ]]
   then
       cd $DIR_CASES_OIS2/OPSLAMB${memb}
       ./xmlchange CONTINUE_RUN=TRUE
   fi
done



