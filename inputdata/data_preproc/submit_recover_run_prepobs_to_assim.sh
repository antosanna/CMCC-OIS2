#!/bin/sh -l
#-----------------------------------------------------------------------
# submit_run_prepobs.sh - 3DVAR+NEMO in Configuration ORCA0.25
#-----------------------------------------------------------------------
#
# Andrea.Storto, *CMCC*, 2010-03
#


. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
. ${DIR_PREPOBS}/include

set -euvx

#--- 1. Initialize main variables


END_DATE="$(date +%Y%m%d)00"
#END_DATE=$(date -d "yesterday" +%Y%m%d)00

# We use this mighty idea of grouping 3DVAR+NEMO runs
# in each job, in order to decrease the waiting time
# assigned by the scheduler, which dramatically
# affects the execution time on the SX-9.
# To do this, for the time being, one should be
# aware of different MPI/OpenMP combinations for
# the two steps: 3DVAR shall run in 1 process
# and XX threads, while NEMO in XX processes and 1 thread
# configuration, where XX is at maximum (and currently) 16.
# The number of slots (set in the include file) should
# account for the maximum execution time allowed on
# the SX-9 (currently 60 hours) and the time spent
# for a 3DVAR+NEMO run. It is now set to 40.

# The date refers to the end of the assimilation week and corresponding date will contain the week before.

for data in 2025051000 
do


	export OMP_NUM_THREADS=1
	export KMP_STACKSIZE="200M"
	export MPIMULTITASKMIX="ON"
	echo "prepobs" 
	echo "prepobs `head -1 ${DIR_PREPOBS}/enddate_to_assim` `date +%Y%m%d%H%M`" 
 $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $parallelq_s -j data_to_assim -l ${OIS2_logdir}/data_preproc -d $DIR_PREPOBS -M 50GB -s run_weekly_prepobs_to_assim.sh -i "$data"

done
