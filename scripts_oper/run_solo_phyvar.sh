#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
SCRFILE=dummy_assim_script

EXPNAME=dummy_expname
EXPDIR=$DIR_CASES_OIS2/${EXPNAME}
WORKDIR=$OIS2_WORK/${EXPNAME}
ENDDATE=dummy_enddate

asm=`grep "asm" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 |sed 's/ *$//g'`
VAR_LENGTH=$(( asm*24 ))        #in hours
STATIC_DA=`grep "STATIC_DA" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
MISFIT_DIR=${WORKDIR}
#=`grep "MISFIT_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'  | sed 's/${EXPNAME}/'${EXPNAME}'/g'`
RFC_DIR=`grep "RFC_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
IB_DIR=`grep "IB_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
EOF_DIR=`grep "EOF_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
VAR_EXEDIR=`grep "VAR_EXEDIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
NPROC_VAR=`grep "NPROC_VAR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
NPROC_FRC=`grep "NPROC_FRC" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
MERGED_EXE=$STATIC_DA/bin/merge.x


tmp=`cat config`
array_tmp=($(echo $tmp|tr ' ' '\n'))
EADTG=${array_tmp[0]}
DTG=${array_tmp[1]}

#EADTG="$(/work/cmcc/aspect/CESM2/inputdata/STATIC_Tools/dateincr $(echo ${EADTG} | cut -c 1-8) +7)00"
#DTG="$(/work/cmcc/aspect/CESM2/inputdata/STATIC_Tools/dateincr $(echo  ${DTG} | cut -c 1-8) +7)00"



#EADTG=2000022700 #last NEMO run timestamp in working directory + 7 days (assim cycle)
#DTG=2000022000

#EADTG=2001100700
#DTG=2001100000

echo $EXPNAME
echo $EXPDIR
echo $WORKDIR
echo $ENDDATE
echo $asm
echo $VAR_LENGTH
echo $STATIC_DA
echo ${MISFIT_DIR}
echo $RFC_DIR
echo $IB_DIR
echo $EOF_DIR
echo $VAR_EXEDIR
echo $NPROC_VAR
echo $NPROC_FRC
echo $MERGED_EXE
echo ${EADTG} ${DTG}


#bsub -q p_short -x -n 72  -P 0574 -o VAR3D_${EADTG}_%J.out -e VAR3D_${EADTG}_%J.err "${EXPDIR}/solo_phyvar.ksh ${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA} ${MISFIT_DIR} ${RFC_DIR} ${IB_DIR} ${EOF_DIR} ${VAR_EXEDIR} ${NPROC_VAR} ${NPROC_FRC} ${EADTG} ${DTG}"
mkdir -p ${OIS2_logdir}/CASES/$EXPNAME
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -N 5 -E yes -q $parallelq_s -j solo_phyvar_${EXPNAME} -l logs -d ${DIR_CASES_OIS2}/$EXPNAME -s solo_phyvar.sh -i "${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA} ${MISFIT_DIR} ${RFC_DIR} ${IB_DIR} ${EOF_DIR} ${VAR_EXEDIR} ${NPROC_VAR} ${NPROC_FRC} ${EADTG} ${DTG}"
