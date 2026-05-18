#! /bin/sh -l
. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh

set -euvx

[[ -s ${PREPOBS_config}/enddate_to_assim ]] || \
  { echo "No enddate_to_assim file, exiting!" ; exit 2 ; }

END_DATE=$(date +%Y%m%d)00
DTG=`cat ${PREPOBS_config}/enddate_to_assim`

if [ $END_DATE -gt $DTG ]; then
   dir2copy=$DTG
else
   #on saturday the preproc procedure update enddate_to_assim to be used starting from the following date
   file2read=`ls ${PREPOBS_config}/enddate_to_assim.* |tail -1`
   dir2copy=`cat $file2read` 
fi

WORKDIR=${PREPOBS_wdir}/$dir2copy/assim

ARCHDIR=${OIS2_data}/inputdata/data_preproc/$dir2copy/
[[ -d $ARCHDIR ]] && rm -rf $ARCHDIR/*
mkdir -p ${ARCHDIR}

rsync -auv $WORKDIR $ARCHDIR/.
