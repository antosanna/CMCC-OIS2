#!/bin/sh -l

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -euvx
typeofrun="RESUME"   #otherwise 1Start
if [[ $machine == "juno" ]]
then
   STARTDATE=20240914
elif [[ $machine == "cassandra" ]]
then
   STARTDATE=20260321
fi
ENDDATE=${1:-`date +%Y%m%d`}
namelist=${OIS2_input}/STATIC_user_nl/NEMO42CICE6/ref/user_nl_nemo_assisla
sed -e "s/dummy_startdate/$STARTDATE/g;s/dummy_enddate/$ENDDATE/g" $OIS2_scripts/run_assim_unperturbed.sh > $DIR_CASES_OIS2/OPSLAMB0/run_assim.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB0/run_assim.sh
echo $typeofrun > $DIR_CASES_OIS2/OPSLAMB0/runstatcycle
for member in {1..8}
do 
   namelist=${OIS2_input}/STATIC_user_nl/NEMO42CICE6/ref/user_nl_nemo_sto${member}
   assim_script=run_assim$member.sh
   sed -e "s/dummy_member/$member/g;s/dummy_expname/OPSLAMB$member/g;s/dummy_startdate/$STARTDATE/g;s/dummy_enddate/$ENDDATE/g;s@dummy_namelist@$namelist@g" $OIS2_scripts/run_assim_pert.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_assim$member.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_assim$member.sh
   echo $typeofrun > $DIR_CASES_OIS2/OPSLAMB$member/runstatcycle
done
for member in {0..8}
do 
   assim_script=run_assim$member.sh
   if [[ $member -eq 0 ]]
   then
      assim_script=run_assim.sh
   fi
   sed -e "s/dummy_expname/OPSLAMB$member/g;s/dummy_assim_script/$assim_script/g;s/dummy_enddate/$ENDDATE/g" $OIS2_scripts/run_solo_icevar.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_solo_icevar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_solo_icevar.sh
   rsync -av  $OIS2_scripts/solo_icevar.sh  $DIR_CASES_OIS2/OPSLAMB$member;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/solo_icevar.sh
   sed -e "s/dummy_expname/OPSLAMB$member/g;s/dummy_assim_script/$assim_script/g;s/dummy_enddate/$ENDDATE/g" $OIS2_scripts/run_solo_phyvar.sh > $DIR_CASES_OIS2/OPSLAMB$member/run_solo_phyvar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/run_solo_phyvar.sh
   sed -e "s/dummy_seed/$member/g"  $OIS2_scripts/solo_phyvar.sh > $DIR_CASES_OIS2/OPSLAMB$member/solo_phyvar.sh;chmod u+x $DIR_CASES_OIS2/OPSLAMB$member/solo_phyvar.sh
   rsync -av  $OIS2_scripts/env_batch.xml $DIR_CASES_OIS2/OPSLAMB$member
   rsync -av  $OIS2_scripts/env_batch.xml $DIR_CASES_OIS2/OPSLAMB$member/LockedFiles
   rsync -av  $OIS2_scripts/env_workflow.xml $DIR_CASES_OIS2/OPSLAMB$member
   rsync -av $OIS2_input/STATIC_user_nl/drof/user_nl_drof_streams $DIR_CASES_OIS2/OPSLAMB$member
   rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm$member $DIR_CASES_OIS2/OPSLAMB$member/user_nl_datm
   rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm$member $DIR_CASES_OIS2/OPSLAMB$member/user_nl_datm
   if [[ $member -eq 0 ]] ; then
      rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm_streams$member $DIR_CASES_OIS2/OPSLAMB$member/user_nl_datm_streams
   else
      rsync -av $OIS2_input/STATIC_user_nl/datm/user_nl_datm_streams$member $DIR_CASES_OIS2/OPSLAMB$member/user_nl_datm_streams$member
   fi
#   rsync -av $OIS2_input/STATIC_user_nl/datm/datm.streams.xml $DIR_CASES_OIS2/OPSLAMB$member/CaseDocs

done
