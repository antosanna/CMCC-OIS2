#!/usr/bin/sh -l
#BSUB -e preproc_EDA_%J.err
#BSUB -o preproc_EDA_%J.out
#BSUB -J preproc_EDA
#BSUB -q s_long
#BSUB -M 30G
#BSUB -P 0490
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -euvx


# this must be run first for em and then for the other members which are independent one from the other
MEMB=$1
ini=$2
end=$3
#MEMB=em
#ini=20241005
#end=20250501
WK_EDA=$OIS2_work/ECMWF_FORCINGS/EDA/${MEMB}_daily
lsm_mask=$OIS2_work_inpdir/ERA5_mask_01.nc
cd $WK_EDA 

mkdir -p $WK_EDA/logs
#here the scripts will be prepared for the any member (em p1 p4 p6 p8)
sed -e "s@member@$MEMB@g;s@dummy_dir@${WK_EDA}@g;s@dummy_f@ECMWF@g" $OIS2_input/ECMWF_FORCINGS/EDA/chname_EDA.sh > $WK_EDA/chname_EDA.sh; chmod u+x $WK_EDA/chname_EDA.sh
sed -e "s@member@$MEMB@g;s@dummy_dir@${WK_EDA}@g;s@dummy_f@ECMWF@g" $OIS2_input/ECMWF_FORCINGS/EDA/run_sst.sh > $WK_EDA/run_sst.sh; chmod u+x $WK_EDA/run_sst.sh

for script in dewT_to_q.sh td2m.sh lwrd.sh mslp.sh sp.sh snow.sh t2m.sh q2m.sh swrd.sh precip.sh sst.sh u10m_v10m.sh
do 
   sed -e "s@dummy_dir@${WK_EDA}@g;s@dummy_f@ECMWF_${MEMB}@g" $OIS2_input/ECMWF_FORCINGS/templates/$script > $WK_EDA/$script;chmod u+x $WK_EDA/$script
done
sed -e "s@dummy_dir@${WK_EDA}@g;s@dummy_f@ECMWF_${MEMB}@g" $OIS2_input/ECMWF_FORCINGS/EDA/rad_prec.sh > $WK_EDA/rad_prec.sh;chmod u+x $WK_EDA/rad_prec.sh
if [[ $MEMB != "em" ]]
then
   sed -e "s@member@$MEMB@g" $OIS2_input/ECMWF_FORCINGS/EDA/make_anomaly.sh > $WK_EDA/make_anomaly_${MEMB}.sh;chmod u+x $WK_EDA/make_anomaly_${MEMB}.sh 
   sed -e "s@member@$MEMB@g;s@dummy_dir@${WK_EDA}@g" $OIS2_input/ECMWF_FORCINGS/EDA/generate_closure_EDA.sh > $WK_EDA/generate_closure_${MEMB}.sh;chmod u+x $WK_EDA/generate_closure_${MEMB}.sh
fi
rsync -av $OIS2_input/ECMWF_FORCINGS/EDA/mv_to_input_dir_EDA.sh $WK_EDA/

YYMMDD=${ini}
while [ $YYMMDD -le $end ];
do
   ./chname_EDA.sh $YYMMDD 
   ./rad_prec.sh $YYMMDD #ppd
   ./dewT_to_q.sh $YYMMDD     #pp2
   ./td2m.sh $YYMMDD  $lsm_mask     #ppl2
   ./lwrd.sh $YYMMDD  $lsm_mask     #ppl3
   ./mslp.sh $YYMMDD  $lsm_mask     #ppl4
   ./sp.sh $YYMMDD  $lsm_mask     #ppl5
   ./snow.sh $YYMMDD  $lsm_mask     #ppl6
   ./t2m.sh $YYMMDD  $lsm_mask     #ppl8
   ./q2m.sh $YYMMDD  $lsm_mask     #ppl9
   ./swrd.sh $YYMMDD  $lsm_mask    #ppl7
   ./precip.sh $YYMMDD  $lsm_mask  #ppl10
   ./sst.sh $YYMMDD  $lsm_mask     #ppl1_sst
   ./u10m_v10m.sh $YYMMDD  $lsm_mask  #ppl1
   ./run_sst.sh $YYMMDD  $lsm_mask
   if [[ $MEMB != "em" ]]
   then
      ./make_anomaly_${MEMB}.sh  $YYMMDD
      ./mv_to_input_dir_EDA.sh $MEMB $YYMMDD
   fi
   YYMMDD=$(date +%Y%m%d -d "${YYMMDD} +1 day")
done

