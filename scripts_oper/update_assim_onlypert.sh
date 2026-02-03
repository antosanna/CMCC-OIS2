#!/bin/sh -l

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -euvx
typeofrun="RESUME"   #otherwise 1Start
STARTDATE=20240914
ENDDATE=`date +%Y%m%d`
for member in {1..8}
do 
   namelist=${OIS2_input}/STATIC_user_nl/NEMO42CICE6/ref/user_nl_nemo_sto${member}
   assim_script=run_assim$member.sh
   sed -e "s/dummy_member/$member/g;s/dummy_expname/OPSLAMB$member/g;s/dummy_startdate/$STARTDATE/g;s/dummy_enddate/$ENDDATE/g;s@dummy_namelist@$namelist@g" $OIS2_scripts/run_assim_pert.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_assim$member.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_assim$member.sh
   echo $typeofrun > $DIR_CASES_OIS2/OPSLAMB$member/runstatcycle

   sed -e "s/dummy_expname/OPSLAMB$member/g;s/dummy_assim_script/$assim_script/g;s/dummy_enddate/$ENDDATE/g" $OIS2_scripts/run_solo_icevar.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_solo_icevar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_solo_icevar.sh
   rsync -av  $OIS2_scripts/solo_icevar.sh  $DIR_CASES_OIS2/OPSLAMB$member;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/solo_icevar.sh
   sed -e "s/dummy_expname/OPSLAMB$member/g;s/dummy_assim_script/$assim_script/g;s/dummy_enddate/$ENDDATE/g" $OIS2_scripts/run_solo_phyvar.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_solo_phyvar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_solo_phyvar.sh
   sed -e "s/dummy_seed/$member/g"  $OIS2_scripts/solo_phyvar.sh > $DIR_CASES_OIS2/OPSLAMB$member/solo_phyvar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/solo_phyvar.sh
   rsync -av  $OIS2_scripts/env_batch.xml $DIR_CASES_OIS2/OPSLAMB$member
   rsync -av  $OIS2_scripts/env_batch.xml $DIR_CASES_OIS2/OPSLAMB$member/LockedFiles
   rsync -av  $OIS2_scripts/env_workflow.xml $DIR_CASES_OIS2/OPSLAMB$member
   rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm$member $DIR_CASES_OIS2/OPSLAMB$member/user_nl_datm
   rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm_streams$member $DIR_CASES_OIS2/OPSLAMB$member/
#   rsync -av $OIS2_input/STATIC_user_nl/datm/datm.streams.xml $DIR_CASES_OIS2/OPSLAMB$member/CaseDocs

done
