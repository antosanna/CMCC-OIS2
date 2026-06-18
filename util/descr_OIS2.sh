#!/bin/bash -l
#set -eux

set -a
if [[ -n `echo $PS1|grep leonardo` ]]
then
   machine="leonardo"
elif [[ -n `echo $PS1|grep juno` ]]
then
   machine="juno"
   alias rm="rm -f"
   alias cp="/bin/cp -f"
   alias mv="mv -f"
   envcondacm3=cmcc-cm_py39
   DIR_NEMO_REBUILD=/work/cmcc/aspect/GIT/py_nemo_rebuild/src/py_nemo_rebuild
   mpirun4py_nemo_rebuild=mpirun
   mpicmd=mpirun
   envcondanemo=/work/cmcc/aspect/.nemo_rebuild
elif [[ -n `echo $PS1|grep cassandra` ]]
then
   machine="cassandra"
   alias rm="rm -f"
   alias cp="/bin/cp -f"
   alias mv="mv -f"
   envcondacm3=$HOME/.conda/envs/cmcc-cm_sps4
   DIR_NEMO_REBUILD=$HOME/CMCC-CM//components/nemo/source/utils/py_nemo_rebuild/src/py_nemo_rebuild/
   mpirun4py_nemo_rebuild=mpiexec.hydra
   mpicmd=mpiexec.hydra
   envcondanemo=$envcondacm3

elif [[ -n `echo $PS1|grep zeus` ]]
then
   machine="zeus"
else
   echo "MACHINE UNKNOWN!! EXITING NOW!!"
   exit -1
fi

#############################################################################
# USER DEFINED PARAMETERS
#############################################################################

# Directories
OIS2_home="$HOME/CPS/CMCC-OIS2"
#WORK="/work/cmcc/`whoami`"
WORK="/work/cmcc/cp1"
DATA="/data/delivery/csp/cp1/in/"
PERT_NEMO_DATA=$DATA/EDA/pert_nemo/
ERA5_DATA=$DATA/ERA5/input/oper_daily/ecm_mars
OIS2_data="/data/cmcc/cp1/CPS/CMCC-OIS2/"
OIS2_work="${WORK}/CPS/CMCC-OIS2"
OIS2_WORK="$OIS2_work/run_oce_assim"
DIR_CASES_OIS2="$OIS2_work/cases"
nx=1440
ny=721
VAR_LENGTH=168
OIS2_input=${OIS2_home}/inputdata
OIS2_scripts=${OIS2_home}/scripts_oper
DIR_PREPOBS=${OIS2_input}/data_preproc
EDA_dir=${OIS2_input}/ECMWF_FORCINGS/EDA
ERA5_dir=${OIS2_input}/ECMWF_FORCINGS/ERA5_daily
SST_dir=${OIS2_input}/SST
SIT_dir=${OIS2_input}/SIT
SIC_dir=${OIS2_input}/SIC
SLA_dir=${OIS2_input}/SLA
OIS2_work_inpdir="${OIS2_work}/inputdata"
PREPOBS_wdir=${OIS2_work_inpdir}/data_preproc/
PREPOBS_config=${OIS2_work_inpdir}/data_preproc/run_assim_configfile
EN4_STATIC_dir=${OIS2_work_inpdir}/STATIC_DA_NEMO42/SST_EN4
OTHER_STATIC_dir=${OIS2_work_inpdir}/STATIC_DA_NEMO42/OTHER_FORCINGS/
OIS2_exe=$OIS2_home/executables
OIS2_logdir="${OIS2_work}/logs"
#OIS2_util="${OIS2_home}/util"
OIS2_bigfiles="${OIS2_home}/static"
#OIS2_archive="${DATA}/archive/OIS"
OIS2_archive="$OIS2_work/rea_archive"
STATIC_Tools=$DIR_UTIL_OIS2/STATIC_Tools
DIR_HIST_SLA="/data/inputs/METOCEAN/historical/obs/ocean/satellite/CMS/GlobOce/altimetry/L3_EIS_202311/day/"
DIR_ROLL_SLA="/data/inputs/METOCEAN/rolling/obs/ocean/satellite/CMS/GlobOce/altimetry/L3_EIS_202311/day/"
sosie_exe=$OIS2_exe/sosie.x
qs_exe=$OIS2_exe/td2qs.x
FLANDREXE=$OIS2_exe/flandR.x
FLANDREXESST=$OIS2_exe/flandR_sst_fill.x
#envcondaOIS2=/work/cmcc/ac28919/.coper


serialq_s=s_short
serialq_m=s_medium
serialq_l=s_long
parallelq_s=p_short
parallelq_m=p_medium
parallelq_l=p_long
operational_user="cp1"
pID="0784"
sla_serialID="SC_SERIAL_sps35"
S_apprun="SERIAL_sps35"
#slaID="SC_sps35"
#apprun="sps35"
# For serial queues there are no service classes
#sla_serialID=" "
#S_apprun=" "
slaID="SC_sps35"
apprun="sps35"
mymail=sp1@cmcc.it

set +a
