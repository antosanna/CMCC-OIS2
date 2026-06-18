#!/bin/bash -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/condaactivation.sh
condafunction activate $envcondacm3
set -euvx
mkdir -p $OIS2_work        #/work/cmcc/$USER/CPS/CMCC-OIS2"
mkdir -p $OIS2_WORK        #####$OIS2_work/run_oce_assim
mkdir -p $DIR_CASES_OIS2   #####$OIS2_work/cases

YY=2026
MM=03
DD=28
data=$YY$MM${DD}00
data_format_cesm=$YY-$MM-$DD


#for index in {0..8}
for index in 1
do
   if [[ $index -eq 0 ]] ; then
       cesmdir=$HOME/CMCC-CM_OIS2/CMCC-CM//cime/scripts	   
   else
       cesmdir=$HOME/CMCC-CM_OIS2/CMCC-CM-PERT//cime/scripts
   fi	   
   cd $cesmdir

   caso=OPSLAMB${index}
   if [ -d $DIR_CASES_OIS2/$caso ]
   then
      rm -rf $DIR_CASES_OIS2/$caso
   fi
   if [ -d $OIS2_WORK/$caso ]
   then
      rm -rf $OIS2_WORK/$caso
   fi

   $cesmdir/create_newcase --case "$DIR_CASES_OIS2/$caso" --compset HIST_DATM%ERA5_SLND_CICE_NEMO_DROF%DAICLIM025_SGLC_SWAV --res TL639_n0253_n0253 --mach cassandra --run-unsupported

   cd $DIR_CASES_OIS2/$caso
   mkdir -p $DIR_CASES_OIS2/$caso/logs

#from replay.sh in original aspect dirs
   ./xmlchange PROJECT=0784
   ./xmlchange CHARGE_ACCOUNT=0784
   ./xmlchange RUN_REFCASE=OPSLAMB${index}
  

   ./xmlchange RUN_STARTDATE=$data_format_cesm
   ./xmlchange RUN_REFDATE=$data_format_cesm
   ./xmlchange CALENDAR=GREGORIAN

   ./xmlchange DOUT_S=FALSE
   ./xmlchange STOP_OPTION=ndays
   ./xmlchange STOP_N=7
   ./xmlchange REST_N=7

  ./xmlchange DATM_YR_START=$YY
  ./xmlchange DATM_YR_END=$YY

  ./xmlchange OCN_NCPL=24
  ./xmlchange ROF_NCPL=24
  ./xmlchange ATM_NCPL=24

  ./xmlchange NTASKS=330
  ./xmlchange MAX_MPITASKS_PER_NODE=110

  ./xmlchange RUN_TYPE=hybrid
  ./xmlchange CONTINUE_RUN=FALSE

  ./xmlchange CIME_OUTPUT_ROOT=$OIS2_WORK

  rsync -av $OIS2_scripts/env_batch.xml $DIR_CASES_OIS2/$caso/.
  rsync -av $OIS2_scripts/env_workflow.xml $DIR_CASES_OIS2/$caso/.

  ./case.setup --reset
  ./case.setup

  rsync -av $OIS2_input/SourceMods/OPSLAMB${index}/* $DIR_CASES_OIS2/$caso/SourceMods/.
  
  ./case.build

done
