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
STATIC_DA_ICE=`grep "STATIC_DA_ICE" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
MISFIT_DIR=`grep "MISFIT_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g' | sed 's/${EXPNAME}/'${EXPNAME}'/g'`
RFC_DIR=`grep "RFC_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
IB_DIR=`grep "IB_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
EOFICE_DIR=`grep "EOFICE_DIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
VAR_EXEDIR=`grep "VAR_EXEDIR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
NPROC_ICEVAR=`grep "NPROC_ICEVAR" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
NPROC_FRC=`grep "NPROC_FRC" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
SIC_ARC=`grep "SIC_ARC" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
SIT_ARC=`grep "SIT_ARC" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
#CRYOSMOSARCHIV=`grep "CRYOSMOSARCHIV" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
#CRYO2ARCHIV=`grep "CRYO2ARCHIV" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
#SMOSARCHIV=`grep "SMOSARCHIV" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`
#CONTINUE_RUN=`grep "CONTINUE_RUN" $SCRFILE |head -1 | cut -d "#" -f1 | cut -d "=" -f2 | sed 's/ *$//g'`

tmp=`cat config`
array_tmp=($(echo $tmp|tr ' ' '\n'))
EADTG=${array_tmp[0]}
DTG=${array_tmp[1]}

#DTG=2000020600
#PREV_DTG=2000013000



echo $EXPNAME
echo $EXPDIR
echo $WORKDIR
echo $ENDDATE
echo $VAR_LENGTH
echo $STATIC_DA_ICE
echo $IB_DIR
echo $EOFICE_DIR
echo $VAR_EXEDIR
echo $NPROC_ICEVAR
echo $NPROC_FRC
echo $SIC_ARC
echo $SIT_ARC
echo ${EADTG}
echo ${DTG}


#bsub  -q p_short -x  -R "span[ptile=1]" -n 1 -P 0574  -o ICEVAR3D_${EADTG}_%J.out -e ICEVAR3D_${EADTG}_%J.err "${EXPDIR}/solo_icevar.ksh ${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA_ICE} ${IB_DIR} ${EOFICE_DIR} ${VAR_EXEDIR} ${NPROC_ICEVAR} ${NPROC_FRC} ${SIC_ARC} ${SIT_ARC} ${EADTG} ${DTG} "
mkdir -p ${OIS2_logdir}/CASES/$EXPNAME
$DIR_UTIL_OIS2/submitcommand.sh -m $machine -E yes -N 5 -q $parallelq_s -j solo_icevar_${EXPNAME} -l logs -d ${DIR_CASES_OIS2}/$EXPNAME -s solo_icevar.sh -i "${EXPDIR} ${EXPNAME} ${WORKDIR} ${ENDDATE} ${VAR_LENGTH} ${STATIC_DA_ICE} ${IB_DIR} ${EOFICE_DIR} ${VAR_EXEDIR} ${NPROC_ICEVAR} ${NPROC_FRC} ${SIC_ARC} ${SIT_ARC} ${EADTG} ${DTG} "
