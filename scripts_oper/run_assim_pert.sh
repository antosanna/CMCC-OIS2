#!/bin/sh -l
#BSUB -J run_assim_dummy_expname
#BSUB -e logs/run_assim_dummy_expname_%J.err
#BSUB -o logs/run_assim_dummy_expname_%J.out
#BSUB -P 0490
#BSUB -M 1000
#BSUB -sla SC_SERIAL_sps35
#BSUB -app SERIAL_sps35
#BSUB -q s_long
#----------------------------------------------------------------------------|
# This script is the submission command for nemo-cice with OceanVar setup    |
# under CESM framework.                                                      |
# It is better to run in background with the following command on login node |
# nohup ./run_cycle.sh > log.out&                                            |
# For a fresh run make sure ./xmlchange CONTINUE_RUN=FALSE                   |
#                                                                            |
# Deep S. Banerjee, CMCC, 2022                                               |
#----------------------------------------------------------------------------|

. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
. ${DIR_UTIL_OIS2}/load_nco
set +euvx
    . $DIR_UTIL_OIS2/condaactivation.sh
    condafunction activate $envcondacm3
set -euvx

#module load oneapi-2022.1.0/compiler-rt/2022.1.0
#module load intel-2021.6.0
#module load intel-2021.6.0/nco

#------------- YOU MIGHT NEED TO CHANGE THINGS BELOW --------------------------

MEMBER=dummy_member
EXPNAME=dummy_expname     #Experiment name
ORIGINDATE=19600101             #For 1start origin and startdate should be the same
STARTDATE=dummy_startdate              #Experiment start date
ENDDATE=dummy_enddate #20240610   #20000306                #Experiment end date
FRC_LENGTHD=168 #264 #192 #264                 #forecast length(in hours) (typically 11 days) !!ATTENTION --> sync_freq(in days) inside Buildconf/nemoconf/file_def_nemo-oce.xml should be the same.
WRITEOUT=7                      #frequency (in days) of writing output fields in one output file
asm=7                           #in days (typically 7 days) Assimilation window
OBSM_FREQ=3600                  # Obsmisfits computation frequency (in seconds)
VAR_LENGTH=$(( asm*24 ))        #in hour
IAUDDAYS=4 #IAU increments over days
CPL_FREQ=3600 #must be similar to the coupler definition
EXPDIR="${DIR_CASES_OIS2}/${EXPNAME}"
WORKDIR="${OIS2_WORK}/${EXPNAME}"
RUNDIR="${WORKDIR}/run"
ASSIMDIR_PHY="${WORKDIR}/assim_phy"
ASSIMDIR_ICE="${WORKDIR}/assim_ice"

LL_MONTHREST=1 #written restart every day in the overlapping week

SSRTF=TRUE  #NUDGING
TRADMPTF=TRUE
SPINUPHCORR=0 #remove ammount of SIT in the case it exceeds 6m
LLPOSTPROC=0
OBSMIS=TRUE

SIC_ARC=${OIS2_work_inpdir}/SIC/
SIT_ARC=${OIS2_work_inpdir}/SIT/

#original tstep
TSTEP_ORIG=1200                                                                #unit=sec
#TSTEP=${TSTEP_ORIG} #could change during the run
NDTDICE_ORIG=2
#NDTDICE=${NDTDICE_ORIG}
NAMELIST_OCN=dummy_namelist
NAMELIST_ICE=${OIS2_work_inpdir}/STATIC_user_nl/NEMO42CICE6/ref/user_nl_cice_assi
NAMELIST_XIOS=${OIS2_work_inpdir}/STATIC_user_nl/NEMO42CICE6/ref/file_def_nemo-oce.xml
FIELD_XIOS=${OIS2_work_inpdir}/STATIC_user_nl/NEMO42CICE6/ref/field_def_nemo-oce.xml
#DIRECTORIES RELATED TO INPUT FILES FOR THE RUN--
MISFIT_DIR="${OIS2_WORK}/${EXPNAME}/"
STATIC_DA="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim/"
STATIC_DA_ICE="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim_ice/CICE"
RFC_DIR="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim/CORRAD/"
IB_DIR="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim/IB_ERROR/"
EOF_DIR="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim/EOFS/"
EOFICE_DIR="${OIS2_work_inpdir}/STATIC_DA_NEMO42/assim_ice/CICE/"
VAR_EXEDIR="${OIS2_work_inpdir}/STATIC_DA_NEMO42/bin"
PO_WORKDIRBASE="${OIS2_work_inpdir}/data_preproc/"
NPROC_VAR=12
NPROC_ICEVAR=24
NPROC_FRC=330 #HARDCODED SOMEWHERE  #should be same as the processor numbers alloted for NEMO/CICE prescribed in env_mach_pes.xml

REINIT_TIMSTEP=0 #restart from 1 timestep, only first run, to be noted that is autmotaivally set to FALSE once at the second run
  #if run twice with 1, on consecutive dates can generate bugs having a restart in input and output with the saame number of  steps


  #CICE NAMELIST PARAMETERS (FOR ASSIMILATION)--
#  AICE=true
#  BOTH=false
#  IAU=true
#  NDAYRES=$asm

AICE=false
BOTHORIG=true
IAU_ICE_ORIG=true
DAYIAUICE=30
#NEMO NAMELIST PARAMETERS (FOR ASSIMILATION)--
ANALYSIS=true
DIN=false
IAU_PHY=true

#---------------- DO NOT CHANGE ANYTHING BELOW ----------------------------

# MPI processes for 3DVAR
is_forecast=${1:-0}
forecast_day=${2:-"DUMMY"}
if [[ -d  $SCRATCHDIR/IC/restart_from_ois2_fore/$EXPNAME ]]
then
   rm -rf $SCRATCHDIR/IC/restart_from_ois2_fore/$EXPNAME
fi
NNMPI=6

ADDINCR="$STATIC_Tools/dateincr -h"
DIFFDATE="$STATIC_Tools/datediff"

. $STATIC_Tools/myfunctions 

runstatcycle=`cat ${EXPDIR}/runstatcycle`
cd ${EXPDIR}
CONTINUE_RUN=`./xmlquery CONTINUE_RUN | cut -d':' -f2 |sed 's/ *$//g'`
if [ ${CONTINUE_RUN} == "TRUE" ]; then
   if [[ -f config ]]; then      #If system resumes
      tmp=`cat ${EXPDIR}/config`
      array_tmp=($(echo $tmp|tr ' ' '\n'))
      DTG=${array_tmp[0]} ; PREV_DTG=${array_tmp[1]}
      STARTDATE=${DTG:0:8}
      echo "RESUME">runstatcycle
      runstatcycle=`cat ${EXPDIR}/runstatcycle`
      echo "CONTINUE RUN from Date $STARTDATE"
   else
      echo "No config file found -- Aborting"
   fi
fi

tmp=`splitdate $ORIGINDATE'00'`
array_tmp=($(echo $tmp|tr ' ' '\n'))
oYEAR=${array_tmp[0]} ; oMON=${array_tmp[1]} ; oDAY=${array_tmp[2]} ; oHR=${array_tmp[3]} ; oYMD=${array_tmp[4]}

tmp=`splitdate $STARTDATE'00'`
array_tmp=($(echo $tmp|tr ' ' '\n'))
sYEAR=${array_tmp[0]} ; sMON=${array_tmp[1]} ; sDAY=${array_tmp[2]} ; sHR=${array_tmp[3]} ; sYMD=${array_tmp[4]}

tmp=`splitdate $ENDDATE'00'`
array_tmp=($(echo $tmp|tr ' ' '\n'))
eYEAR=${array_tmp[0]} ; eMON=${array_tmp[1]} ; eDAY=${array_tmp[2]} ; eHR=${array_tmp[3]} ; eYMD=${array_tmp[4]}

origindate=${oYEAR}"-"${oMON}"-"${oDAY}
startdate=${sYEAR}"-"${sMON}"-"${sDAY}
enddate=${eYEAR}"-"${eMON}"-"${eDAY}

origindate1=$( date -d "$origindate" +%Y%m%d )  # rewrite in YYYYMMDD format
enddate1=$( date -d "$enddate" +%Y%m%d )        # rewrite in YYYYMMDD format
startdate1=$( date -d "$startdate" +%Y%m%d )    # rewrite in YYYYMMDD format

i=0
rundate1=$startdate1

if [ -d ${RUNDIR} ];then
     rm -rf ${RUNDIR}
     mkdir -p ${RUNDIR}
else
     mkdir -p ${RUNDIR}
fi 
while [ "${rundate1}" -lt "${enddate1}" ]; do

   rundate=$( date -d "$startdate + $i days" +%Y%m%d )       # get $i days forward
   rundate1=$( date -d "$rundate" +%Y%m%d )                  # rundate in YYYYMMDD format


   DTG=$rundate1'00'
   tmp=`splitdate $DTG`
   array_tmp=($(echo $tmp|tr ' ' '\n'))
   YYYY=${array_tmp[0]} ; MM=${array_tmp[1]} ; DD=${array_tmp[2]} ; HH=${array_tmp[3]} ; YMD=${array_tmp[4]}

   FRC_LENGTH=$(( FRC_LENGTHD*1  ))                          #Forecast length in hours
   echo $FRC_LENGTH
   EDTG=`$ADDINCR $DTG +$FRC_LENGTH`
   tmp=`splitdate $EDTG`
   array_tmp=($(echo $tmp|tr ' ' '\n'))
   EYYYY=${array_tmp[0]} ; EMM=${array_tmp[1]} ; EDD=${array_tmp[2]} ; EHH=${array_tmp[3]} ; EYMD=${array_tmp[4]}

   EADTG=`$ADDINCR $DTG +$VAR_LENGTH`
   tmp=`splitdate $EADTG`
   array_tmp=($(echo $tmp|tr ' ' '\n'))
   EAYYYY=${array_tmp[0]} ; EAMM=${array_tmp[1]} ; EADD=${array_tmp[2]} ; EAHH=${array_tmp[3]} ; EAYMD=${array_tmp[4]}

   PREV_DTG=`$ADDINCR $DTG -$VAR_LENGTH`
   tmp=`splitdate $PREV_DTG`
   array_tmp=($(echo $tmp|tr ' ' '\n'))
   PYYYY=${array_tmp[0]} ; PMM=${array_tmp[1]} ; PDD=${array_tmp[2]} ; PHH=${array_tmp[3]} ; PYMD=${array_tmp[4]}

   ENDATE=$enddate1'00'
   tmp=`splitdate ${ENDATE}`
   array_tmp=($(echo $tmp|tr ' ' '\n'))
   YYYYE=${array_tmp[0]} ; MME=${array_tmp[1]} ; DDE=${array_tmp[2]} ; HHE=${array_tmp[3]} ; YMDE=${array_tmp[4]}

#this syntax might cause an error while dealing with March (ex. 19930330 -1month gives 19930303)
#         rundatem1=$( date -d "$rundate -1 month" +%Y%m%d )
# instead evaluating on the mid of the month you always get the desired result
   tmpdate=$( date -d "$rundate " +%Y%m )15
   Ym1=$( date -d "$tmpdate -1 month" +%Y )
   Mm1=$( date -d "$tmpdate -1 month" +%m )

   Yy=$(echo ${rundate} | cut -c 1-4)
   Mm=$(echo ${rundate} | cut -c 5-6)
   Yp1=$(date -d "$tmpdate +1 month" +%Y)
   Mp1=$(date -d "$tmpdate +1 month" +%m)

   YYMMDDtoday=$(date  +%Y%m%d)
   MMtoday=$(echo $YYMMDDtoday | cut -c 5-6)
   YYtoday=$(echo $YYMMDDtoday | cut -c 1-4)

#   if [ "${YYYY}${MM}" -lt "${YYtoday}${MMtoday}" ];
#   then
      sed -e "s/_YYYY_/$YYYY/g" \
            -e "s/_YYYYp1_/$Yp1/g" \
            -e "s/_YYYYm1_/$Ym1/g" \
            -e "s/_MM_/$MM/g" \
            -e "s/_MMp1_/$Mp1/g"\
            -e "s/_MMm1_/$Mm1/g"\
              user_nl_datm_streams${MEMBER} > user_nl_datm_streams
#   else
#      sed -e "s/_YYYY_/$YYYY/g" \
#            -e "s/_YYYYp1_/$Yp1/g" \
#            -e "s/_YYYYm1_/$Ym1/g" \
#            -e "s/_MM_/$MM/g" \
#            -e "s/_MMp1_/$Mp1/g"\
#            -e "s/_MMm1_/$Mm1/g"\
#              user_nl_datm_streams_tml_end_month > user_nl_datm_streams
#   fi


   rm -f config
   echo ${DTG} > config
   echo ${PREV_DTG} >> config
         
   if [ -d ${ASSIMDIR_PHY} ];then
      rm -rf ${ASSIMDIR_PHY}
      mkdir -p ${ASSIMDIR_PHY}
   else
      mkdir -p ${ASSIMDIR_PHY}
   fi 
   if [ -d ${ASSIMDIR_ICE} ];then
      rm -rf ${ASSIMDIR_ICE} 
      mkdir -p ${ASSIMDIR_ICE}
   else
      mkdir -p ${ASSIMDIR_ICE}
   fi 
   ASSIMDIRF_PHY=${ASSIMDIR_PHY}
   ASSIMDIRF_ICE=${ASSIMDIR_ICE}
   TORESTART=TRUE
   CONTINUE_RUN=`./xmlquery CONTINUE_RUN | cut -d':' -f2 |sed 's/ *$//g'`
   if [ ${YMD} == ${startdate1} ]; then
      if [ ${CONTINUE_RUN} == "FALSE" ] && [ ${runstatcycle} == "1START"  ]; then            #First run
         if [ ! -d "${WORKDIR}/BIAS" ]; then
            mkdir -p ${WORKDIR}/BIAS
            mkdir -p ${WORKDIR}/SSH
         fi
	     # TORESTART=FALSE

      fi
   fi

	  ./xmlchange DATM_YR_START=$PYYYY
   ./xmlchange DATM_YR_ALIGN=$PYYYY
   ./xmlchange DATM_YR_END=$EYYYY

   CONTINUE_RUN=`./xmlquery CONTINUE_RUN | cut -d':' -f2 |sed 's/ *$//g'`
   runstatcycle=`cat ${EXPDIR}/runstatcycle`
   echo $CONTINUE_RUN ${YMD} ${startdate1} ${runstatcycle}
   if [ ${YMD} == ${startdate1} ]; then
      if [ "${CONTINUE_RUN}" == "FALSE" ] && [ "${runstatcycle}" == "1START"  ]; then             #First run
         ./case.setup
         ./preview_namelists
         ./xmlchange CONTINUE_RUN=FALSE
         ./xmlchange CALENDAR=GREGORIAN
         ./xmlchange DOUT_S=FALSE
         ./xmlchange STOP_OPTION=ndays
         ./xmlchange STOP_N=$(( FRC_LENGTH/24 ))
         ./xmlchange REST_N=$asm
         ./xmlchange RUN_STARTDATE=$YYYY'-'$MM'-'$DD
         ./xmlchange DATM_YR_START=1960
         ./xmlchange DATM_YR_END=1960
       fi
   fi

   BLD_STAT=`./xmlquery BUILD_COMPLETE | cut -d':' -f2`
   if [ ${BLD_STAT} ==  'TRUE' ]; then
       echo "Case Already Built.. "
   else
       ./case.build --clean-all
       ./case.build
   fi

   if [ "$OBSMIS" == "TRUE" ]; then
      	PO_WORKDIR=$PO_WORKDIRBASE/$EADTG/assim/
      	echo "Copying .. "$PO_WORKDIR
      	cp -f $PO_WORKDIR/*OBS_*.NC ${RUNDIR}/. || exit 3                            #temporarily commented
      	cp -f $PO_WORKDIR/OBS_TAB.DAT ${RUNDIR}/. || exit 2                          #temporarily commented
   fi

         #mkdir -p $RUNDIR
   cp -f config ${RUNDIR}/

   if [ "${ANALYSIS}" == "true" ]; then
      ln -fs  ${WORKDIR}/${YMD}00/assim_phy/ANINCR.NC ${RUNDIR}/ANINCR.nc
      ln -fs ${WORKDIR}/${YMD}00/assim_ice/ANINCR.NC ${RUNDIR}/ANINCR_ICE.nc
   fi

   ln -fs ${STATIC_DA}/dist.coast.nc ${RUNDIR}/dist.coast.nc
   cp ${STATIC_DA}/MDT.nc ${RUNDIR}/
   ncks -v bias  ${WORKDIR}/BIAS/SLA_BIAS_OMG_${YMD}.nc -A ${RUNDIR}/MDT.nc ||  { echo "no SLA BIAS, aborting!" ; exit 12 ; }

          #NEMO namlist parameters:
   BOTH=${BOTHORIG}
   TSTEP=${TSTEP_ORIG}
   NDTDICE=${NDTDICE_ORIG}
   IAU_ICE=${IAU_ICE_ORIG}
   [[ -f assim_cice ]] && BOTH=$(cat assim_cice) && IAU_ICE=$(cat assim_cice) && rm -f assim_cice
   [[ -f timestep_nemo ]] && TSTEP=$(cat timestep_nemo) && rm -f timestep_nemo
   [[ -f timestep_cice ]] && NDTDICE=$(cat timestep_cice) && rm -f timestep_cice
   [[ -f ndayiau_cice ]] && DAYIAUICE=$(cat ndayiau_cice) && rm -f ndayiau_cice

   [[ "$TSTEP" -le "550" ]] && exit
          
   FTSTEP=$((  $FRC_LENGTH * 3600 / $TSTEP ))
   OBSM_FREQ_TS=$(( $OBSM_FREQ / $TSTEP ))
   MINIMUM_FRC_LENGTH=$(( ( $VAR_LENGTH * 3 ) / 2 ))
   CNRESTIN=$EXPNAME
   if [ ${CONTINUE_RUN} == "TRUE" ];then
      if [ ${REINIT_TIMSTEP} == 0 ]; then
        INI_STEP_PREV=$(grep -o '^[^!]*' ${WORKDIR}/${PREV_DTG}/run/namelist_cfg | grep "nn_it000" | cut -d= -f2 | cut -d! -f1)
        PREV_TSTEP=$(grep -o '^[^!]*' ${WORKDIR}/${PREV_DTG}/run/namelist_cfg | grep rn_Dt | cut -d= -f2 | cut -d. -f1)
        LAST_STEP_WEEKLY=$(( (${asm}*86400/${PREV_TSTEP}) + ${INI_STEP_PREV} -1 ))
        LASTSTEPWEEKFORMAT=$(printf "%08d" $LAST_STEP_WEEKLY)
        NNIT000=$(( ${LAST_STEP_WEEKLY} + 1 ))
      else
        NNIT000=1
        LASTSTEPWEEKFORMAT=$(ls -1rt ${WORKDIR}/${PREV_DTG}/run/*_restart_0000.nc | tail -1 | rev | cut -f3 -d_ | rev)
        REINIT_TIMSTEP=0
      fi
   else
      NNIT000=1
	     LASTSTEPWEEKFORMAT="01003464"
      CNRESTIN=dummy_expname
   fi
   NNITEND=$(( (NNIT000 - 1)+FTSTEP ))
   NNDATE0=$rundate1
   
   #to reset to default values if modified for forecast runs
   ./xmlchange STOP_N=$(( FRC_LENGTH/24 )) 
	  ./xmlchange REST_N=$asm
   NSTOCKS=$(( asm*86400/TSTEP ))
   if [ ${is_forecast} -eq 1 ] ; then
       NSTOCKS=$(( 86400/TSTEP ))
       ./xmlchange REST_N=1 
       ndays2run=`${DIR_UTIL}/datediff.sh ${forecast_day} $STARTDATE`
       ./xmlchange STOP_N=${ndays2run}
   elif [ "$MM" -ne "$EAMM" ] && [ ${LL_MONTHREST} -eq 1 ]; then
       NSTOCKS=$(( 86400/TSTEP ))
       ./xmlchange REST_N=1 
   fi
#   fi

	  IAUFINSTEP=$(( IAUDDAYS*(86400/TSTEP) ))
	  NNWRITE=$(( WRITEOUT*(86400/TSTEP) ))

   NNFSBC=$(( ${CPL_FREQ}/TSTEP )) #update of the shapiro application to the bias
   NNFTDM=$(( 86400/TSTEP )) #update of the shapiro application to the bias


   CONTINUE_RUN=`./xmlquery CONTINUE_RUN | cut -d':' -f2 |sed 's/ *$//g'`

   sed -e "s/_NSTOCKS_/$NSTOCKS/g" \
              -e "s/_NNWRITE_/$NNWRITE/g" \
              -e "s/_NNFSBC_/$NNFSBC/g" \
	             -e "s/_NNFTDM_/${NNFTDM}/g"\
              -e "s/_TORESTART_/$TORESTART/g" \
              -e "s/_NNIT000_/$NNIT000/g" \
              -e "s/_LASTEPWE_/${LASTSTEPWEEKFORMAT}/g" \
              -e "s/_NNITEND_/$NNITEND/g" \
              -e "s/_NNDATE0_/$NNDATE0/g" \
              -e "s/_CNRESTIN_/$CNRESTIN/g" \
              -e "s/_TSTEP_/$TSTEP/g" \
              -e "s/_ANALYSIS_/$ANALYSIS/g" \
              -e "s/_DIN_/$DIN/g" \
              -e "s/_IAU_/$IAU_PHY/g" \
	             -e "s/_FIN_STEP_/${IAUFINSTEP}/g" \
              -e "s/_OBSMIS_/$OBSMIS/g" \
	             -e "s/_SSRTF_/$SSRTF/g"\
              -e "s/_TRADMPTF_/$TRADMPTF/g"\
              $NAMELIST_OCN > user_nl_nemo

   cp -f user_nl_nemo Buildconf/nemoconf/namelist_cfg || exit 5


   sed -e "s/_AICE_/$AICE/g" \
               -e "s/_BOTH_/$BOTH/g" \
               -e "s/_IAU_/$IAU_ICE/g" \
               -e "s/_NDTDICE_/$NDTDICE/g" \
	              -e "s/_DAYIAUICE_/$DAYIAUICE/g" \
    	          $NAMELIST_ICE > user_nl_cice

   cp -f ${NAMELIST_XIOS} Buildconf/nemoconf/
   cp -f ${FIELD_XIOS} Buildconf/nemoconf/

   CONTINUE_RUN=`./xmlquery CONTINUE_RUN | cut -d':' -f2`
 
   if [ ${YMD} == ${startdate1} ]; then
     if [ ${CONTINUE_RUN} == "TRUE" ] && [ ${runstatcycle} == "RESUME"  ]; then #Resume run
        echo "RESUMING .. "
        cd ${RUNDIR}/.

        rm -f ${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart*  ${EXPNAME}.cice.r.* ${EXPNAME}.cpl.r* ${EXPNAME}.datm.r* ${EXPNAME}.drof.r*

        ln -fs ${WORKDIR}/${PREV_DTG}/run//${EXPNAME}.cice.r.${YYYY}-${MM}-${DD}-00000.nc .
        ln -fs ${WORKDIR}/${PREV_DTG}/run/${EXPNAME}.cpl.r.${YYYY}-${MM}-${DD}-00000.nc .
               #ln -fs ${WORKDIR}/${PREV_DTG}/run/${EXPNAME}.datm.r.${YYYY}-${MM}-${DD}-00000.nc .
               #ln -fs ${WORKDIR}/${PREV_DTG}/run/${EXPNAME}.drof.r.${YYYY}-${MM}-${DD}-00000.nc .
        if [ -f ${WORKDIR}/${PREV_DTG}/run//${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart.nc ]; then
           ln -fs ${WORKDIR}/${PREV_DTG}/run//${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart.nc ${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart.nc
        else
           for n in $(eval echo {0..$((${NPROC_FRC} -1 ))});
           do
              num2=$(printf "%04d" $n)
              if [ ${REINIT_TIMSTEP} == 0 ]; then
                 ln -fs ${WORKDIR}/${PREV_DTG}/run//${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart_${num2}.nc ${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart_${num2}.nc
              else
                 rest_to_submit=$(ls -1rt ${WORKDIR}/${PREV_DTG}/run/*_restart_0000.nc | tail -1 | rev | cut -f3 -d_ | rev) 
                 ln -fs ${WORKDIR}/${PREV_DTG}/run//${EXPNAME}_${rest_to_submit}_restart_${num2}.nc ${EXPNAME}_${LASTSTEPWEEKFORMAT}_restart_${num2}.nc
              fi
           done
        fi
        echo "${EXPNAME}.datm.r.${YYYY}-${MM}-${DD}-00000.nc" > rpointer.atm
        echo "" >> rpointer.atm

        echo "${EXPNAME}.cpl.r.${YYYY}-${MM}-${DD}-00000.nc" > rpointer.cpl
        echo "" >> rpointer.cpl

        echo "${EXPNAME}.cice.r.${YYYY}-${MM}-${DD}-00000.nc" > rpointer.ice
        echo "" >> rpointer.ice

        echo "${EXPNAME}.drof.r.${YYYY}-${MM}-${DD}-00000.nc" > rpointer.rof
        echo "" >> rpointer.rof
        cd ${EXPDIR}
     fi
   fi

           ##Submitting MODEL RUN ->
   echo " "
   echo "Model Run submitted for date: ${YMD}"
   echo "NEMO RUN" >whichstep
   echo "NEMO RUN  :   `head -1 ${EXPDIR}/config` --> ${EDTG} on `date +%Y%m%d%H%M`" >>timestamp_run
   ./preview_namelists
   job_model=$( ./case.submit | tail -n1 | cut -d' ' -f6 )
   echo " "
   echo "Model Run submitted for date: ${YMD}"
   jobstat_model=`bjobs $job_model | grep DONE|wc -c`
   while [ ${jobstat_model} -eq 0  ]; do
      sleep 30
      jobstat_model=`bjobs $job_model | grep DONE|wc -c`
      jobstat_exit=`bjobs $job_model | grep EXIT|wc -c`
      if [ ${jobstat_exit} -ne 0  ]; then #crashed
         echo "Model/Archiving CRASHED!"
         if [[ $is_forecast -eq 1 ]]
         then
             lastrest=`ls -tr ${RUNDIR}/*restart_0000.nc |tail -1|rev|cut -d "_" -f3 |rev`
             mkdir -p $SCRATCHDIR/IC/restart_from_ois2_fore/$EXPNAME
             rsync -auv ${RUNDIR}/*${lastrest}_restart_0???.nc $SCRATCHDIR/IC/restart_from_ois2_fore/$EXPNAME
             rsync -auv ${RUNDIR}/*.cice.r.????-??-??-00000.nc $SCRATCHDIR/IC/restart_from_ois2_fore/$EXPNAME
             exit 0
         fi
         echo "reducing timestep!"

         echo 'false' >assim_cice	      
         [[ $BOTH == 'false' ]] && echo $(( ( TSTEP / 2 )  )) >timestep_nemo
         echo 6 > timestep_cice
         echo 30 > ndayiau_cice

         cp -pr ${RUNDIR} ${RUNDIR}_`date +%Y%m%d%H%M`
         bsub<run_assim${MEMBER}.sh 
         rm -r ${RUNDIR}/output.abort_*.nc
         rm -r ${RUNDIR}/core*.nc
         bkill $LSB_JOBID       
      fi
    done
    echo ${WORKDIR}/${YMD}00/

    rest_to_delete=$(basename $(ls -1rt ${RUNDIR}/${EXPNAME}_*_restart_0001.nc | tail -1) | cut -d_ -f 3)
    rm -f ${RUNDIR}/${EXPNAME}_${rest_to_delete}_restart_*.nc || exit -1
    if [ -d ${WORKDIR}/${YMD}00/run ];then
       rm -rf ${WORKDIR}/${YMD}00/run
   	   mv -f ${RUNDIR} ${WORKDIR}/${YMD}00/
    else
        mv -f ${RUNDIR} ${WORKDIR}/${YMD}00/
    fi
    mkdir -p ${ASSIMDIRF_PHY} && mkdir -p ${ASSIMDIRF_ICE}  &&  mkdir -p ${RUNDIR} && cd ${RUNDIR}/.

    cat > ${EXPDIR}/config <<EOF
${EADTG}
${DTG}
EOF


       #Preparing next model run beforehand within 'run' directory
    INI_PREV_temp=$(grep -o '^[^!]*' ${WORKDIR}/${YMD}00/run/namelist_cfg | grep "nn_it000" | cut -d= -f2 | cut -d! -f1)
    PR_TSTEP_temp=$(grep -o '^[^!]*' ${WORKDIR}/${YMD}00/run/namelist_cfg | grep rn_Dt | cut -d= -f2 | cut -d. -f1)
    LST_WEEKLY=$(( (${asm}*86400/${PR_TSTEP_temp}) + ${INI_PREV_temp} -1 ))
    LASTSTWEEKFORMAT_temp=$(printf "%08d" $LST_WEEKLY)

    for n in $(eval echo {0..$((${NPROC_FRC} -1 ))});
    do
        num2=$(printf "%04d" $n)
        ln -fs ${WORKDIR}/${YMD}00/run//${EXPNAME}_${LASTSTWEEKFORMAT_temp}_restart_${num2}.nc ${EXPNAME}_${LASTSTWEEKFORMAT_temp}_restart_${num2}.nc
    done

	   ln -fs ${WORKDIR}/${YMD}00/run/${EXPNAME}.cice.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc .
    ln -fs ${WORKDIR}/${YMD}00/run/${EXPNAME}.cpl.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc .
       #        ln -fs ${WORKDIR}/${YMD}00/run/${EXPNAME}.datm.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc .
       #        ln -fs ${WORKDIR}/${YMD}00/run/${EXPNAME}.drof.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc .


    echo "${EXPNAME}.datm.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc" > rpointer.atm
    echo "" >> rpointer.atm
        
    echo "${EXPNAME}.cpl.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc" > rpointer.cpl
    echo "" >> rpointer.cpl
   
    echo "${EXPNAME}.cice.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc" > rpointer.ice
    echo "" >> rpointer.ice
  
    echo "${EXPNAME}.drof.r.${EAYYYY}-${EAMM}-${EADD}-00000.nc" > rpointer.rof
    echo "" >> rpointer.rof

    cd ${EXPDIR}/.
    mkdir -p ${WORKDIR}/LOGCESM
   	mv cesm.std*.* ${WORKDIR}/LOGCESM/
                #mv VAR3D* ${WORKDIR}/LOGCESM/
                #mv ICEVAR3D* LOGCESM/

    if [ $LLPOSTPROC -eq 1 ] ; then
       echo "-----------------archiving submission ---------------"

       sed -e "s/_EXP_/$EXPNAME/g" \
           -e "s/_DTG_/`$ADDINCR $DTG -$(( $VAR_LENGTH * 3 ))`/g" \
           -e "s/_EDTG_/`$ADDINCR $DTG -$(( $VAR_LENGTH * 2 ))`/g" \
           ${OIS2_scripts}/postproc_template.sh >${EXPDIR}/postproc.sh
           bsub < ${EXPDIR}/postproc.sh
    fi

    echo "-----------------From Run script main ---------------"
    echo " EXPDIR     :: " ${EXPDIR}
    echo " EXPNAME    :: " ${EXPNAME}
    echo " WORKDIR    :: " ${WORKDIR}
    echo " ENDDATE    :: " ${ENDDATE}
    echo " VAR_LENGTH :: " ${VAR_LENGTH}
    echo " STATIC_DA  :: " ${STATIC_DA}
    echo " MISFIT_DIR :: " ${MISFIT_DIR}
    echo " RFC_DIR    :: " ${RFC_DIR}
    echo " IB_DIR     :: " ${IB_DIR}
    echo " EOF_DIR    :: " ${EOF_DIR}
    echo " VAR_EXEDIR :: " ${VAR_EXEDIR}
    echo "__________________________END________________________"
   
   
   
                ##Submitting OceanVar PHY ->
                ##_----------------------------------------------------------------------------------------------------
    echo "About to run 3DVar PHY .."
   
#                job_ov=$( bsub -q p_short -x   -n 72 -P 0490 -o ${WORKDIR}/LOGCESM/VAR3DPHY_${EADTG}_%J.out -e ${WORKDIR}/LOGCESM/VAR3DPHY_${EADTG}_%J.err "${EXPDIR}/solo_phyvar.sh ${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA} ${MISFIT_DIR} ${RFC_DIR} ${IB_DIR} ${EOF_DIR} ${VAR_EXEDIR} ${NPROC_VAR} ${NPROC_FRC} ${EADTG} ${DTG}")
    job_ov=$( $DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $parallelq_s -E yes -N 5 -j solo_phyvar_${EXPNAME} -l ${EXPDIR}/logs -d $EXPDIR -s solo_phyvar.sh -M 5000 -i "${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA} ${MISFIT_DIR} ${RFC_DIR} ${IB_DIR} ${EOF_DIR} ${VAR_EXEDIR} ${NPROC_VAR} ${NPROC_FRC} ${EADTG} ${DTG}")
   
    varjobid_phy=`echo $job_ov | cut -d "<" -f2 | cut -d ">" -f1`
    jobstat_done=`bjobs $varjobid_phy |grep DONE|wc -c`
    while [ "${jobstat_done}" -eq 0  ]; do
        jobstat_exit=`bjobs $varjobid_phy |grep EXIT|wc -c`
        if [ "${jobstat_exit}" -ne 0  ]; then
             echo "PHY-OceanVar CRASHED!"
#             bkill ${varjobid_phy}
             ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "job ${varjobid_phy} from solo_phyvar_${EXPNAME} EXITED" -t "run_assim_${EXPNAME} exited at solo_phyvar"
             exit
        fi

        sleep 30
        jobstat_done=`bjobs $varjobid_phy |grep DONE|wc -c`
    done

             ##Submitting OceanVar ICE ->
             ##_----------------------------------------------------------------------------------------------------

    echo "About to run 3DVar ICE .."
    mkdir -p ${EXPDIR}/logs
#                job_ov=$(bsub  -q p_short -x  -n ${NPROC_ICEVAR} -P 0490 -J solo_icevar_${EXPNAME} -o ${WORKDIR}/LOGCESM/ICEVAR3D_${EADTG}_%J.out -e ${WORKDIR}/LOGCESM/ICEVAR3D_${EADTG}_%J.err "${EXPDIR}/solo_icevar.sh ${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA_ICE} ${IB_DIR} ${EOFICE_DIR} ${VAR_EXEDIR} ${NPROC_ICEVAR} ${NPROC_FRC} ${SIC_ARC} ${SIT_ARC} ${EADTG} ${DTG}")
    job_ov=$($DIR_UTIL_OIS2/submitcommand.sh -m $machine -q $parallelq_s -E yes -N 5 -j solo_icevar_${EXPNAME} -l ${EXPDIR}/logs -d ${EXPDIR} -s solo_icevar.sh -i "${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA_ICE} ${IB_DIR} ${EOFICE_DIR} ${VAR_EXEDIR} ${NPROC_ICEVAR} ${NPROC_FRC} ${SIC_ARC} ${SIT_ARC} ${EADTG} ${DTG}")

    varjobid=`echo $job_ov | cut -d "<" -f2 | cut -d ">" -f1`
    jobstat_done=`bjobs $varjobid |grep DONE|wc -c`
    while [ "${jobstat_done}" -eq 0  ]; do
        jobstat_exit=`bjobs $varjobid |grep EXIT|wc -c`
        if [ "${jobstat_exit}" -ne 0  ]; then
             echo "ICE-OceanVar CRASHED!"
 #            bkill ${varjobid}
             ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "job ${varjobid} from solo_icevar_${EXPNAME} EXITED" -t "run_assim_${EXPNAME} exited at solo_icevar"
             exit
        fi

        sleep 30
        jobstat_done=`bjobs $varjobid |grep DONE|wc -c`
    done
    if [ -d ${WORKDIR}/${EADTG}/ ];then
       if [ -d ${WORKDIR}/${EADTG}/${ASSIMDIRF_PHY} ]
       then
          rm -rf ${WORKDIR}/${EADTG}/${ASSIMDIRF_PHY}
          mv -f ${ASSIMDIRF_PHY} ${WORKDIR}/${EADTG}/.
       fi
       if [ -d ${WORKDIR}/${EADTG}/${ASSIMDIRF_ICE} ]
       then
          rm -rf ${WORKDIR}/${EADTG}/${ASSIMDIRF_ICE}
          mv -f ${ASSIMDIRF_ICE} ${WORKDIR}/${EADTG}/.
       fi
    else
       mkdir -p ${WORKDIR}/${EADTG}/
       mv -f ${ASSIMDIRF_PHY} ${WORKDIR}/${EADTG}/.
       mv -f ${ASSIMDIRF_ICE} ${WORKDIR}/${EADTG}/.
    fi

    cd ${EXPDIR}/.
    ./xmlchange CONTINUE_RUN=TRUE
     echo "LOOP">runstatcycle
     runstatcycle=`cat ${EXPDIR}/runstatcycle`

     i=$(( i + $asm ))
done
