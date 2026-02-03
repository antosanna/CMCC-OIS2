#!/bin/bash -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx

mkdir -p $OIS2_work/cases
YY=2024
MM=09
DD=14
data=$YY$MM${DD}00
data_format_cesm=$YY-$MM-$DD
for index in {0..8}
do
   cd /work/cmcc/aspect/GIT/CMCC-CM-PERT//cime/scripts
   if [[ $index -eq 0 ]]
   then
      cd /work/cmcc/aspect/GIT/CMCC-CM//cime/scripts
   fi
   refcase=~aspect/CMCC-CM/Exps/OPSLAMB$index
   caso=OPSLAMB$index
   if [ -d $DIR_CASES_OIS2/$caso ]
   then
      rm -rf $DIR_CASES_OIS2/$caso
   fi
   mkdir -p $OIS2_work/run_oce_assim/$caso 
   if [ -d $OIS2_work/run_oce_assim/$caso ]
   then
      rm -rf $OIS2_work/run_oce_assim/$caso
   fi
   ./create_clone --case $DIR_CASES_OIS2/$caso --clone $refcase --cime-output-root $OIS2_work/run_oce_assim/
   cp /work/cmcc/aspect/CESM2/$caso/bld/cesm.exe $OIS2_cases/$caso/bld
   cd $DIR_CASES_OIS2/$caso
   mkdir -p $DIR_CASES_OIS2/$caso/logs
   ./case.setup --reset
   ./case.setup
   ./xmlchange BUILD_COMPLETE=TRUE
   ./xmlchange RUN_REFDIR=/work/cmcc/aspect/CESM2/$caso/$data/run
   ./xmlchange RUN_REFCASE=$caso
   ./xmlchange RUN_REFDATE=$data_format_cesm
   ./xmlchange RUN_STARTDATE=$data_format_cesm
   ./xmlchange GET_REFCASE=TRUE
   ./xmlchange CONTINUE_RUN=TRUE
done
