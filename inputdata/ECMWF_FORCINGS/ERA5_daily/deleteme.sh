#!/usr/bin/sh -l
#BSUB -e ../../../logs/preproc_ERA5_%J.err
#BSUB -o ../../../logs/preproc_ERA5_%J.out
#BSUB -J preproc_ERA5
#BSUB -q s_long
#BSUB -M 30G
#BSUB -P 0490
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -euvx


ini=20240901
end=20240930
WK_ERA5=$OIS2_work/ECMWF_FORCINGS/ERA5_daily
lsm_mask=$OIS2_work_inpdir/ERA5_mask_01.nc
cd $WK_ERA5 

mkdir -p $WK_ERA5/logs
#here the scripts will be prepared for the any member (em p1 p4 p6 p8)
sed -e "s@dummy_dir@${WK_ERA5}@g;s@dummy_f@ERA5@g" $OIS2_input/ECMWF_FORCINGS/ERA5_daily/chname_ERA5.sh > $WK_ERA5/chname_ERA5.sh; chmod u+x $WK_ERA5/chname_ERA5.sh
sed -e "s@dummy_dir@${WK_ERA5}@g;s@dummy_f@ERA5@g" $OIS2_input/ECMWF_FORCINGS/ERA5_daily/run_sst.sh > $WK_ERA5/run_sst.sh; chmod u+x $WK_ERA5/run_sst.sh

for script in rad_prec.sh dewT_to_q.sh td2m.sh lwrd.sh mslp.sh sp.sh snow.sh t2m.sh q2m.sh swrd.sh precip.sh sst.sh u10m_v10m.sh
do 
   sed -e "s@dummy_dir@${WK_ERA5}@g;s@dummy_f@ERA5@g" $OIS2_input/ECMWF_FORCINGS/templates/$script > $WK_ERA5/$script;chmod u+x $WK_ERA5/$script
done
sed -e "s@dummy_dir@${WK_ERA5}@g" $OIS2_input/ECMWF_FORCINGS/ERA5_daily/generate_closure_ERA5.sh > $WK_ERA5/generate_closure_ERA5.sh;chmod u+x $WK_ERA5/generate_closure_ERA5.sh

rsync -av $OIS2_input/ECMWF_FORCINGS/ERA5_daily/mv_to_input_dir_ERA5.sh $WK_ERA5/
YYMMDD=${ini}
while [ $YYMMDD -le $end ];
do
   ./chname_ERA5.sh $YYMMDD 
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
#   ./generate_closure_ERA5.sh 
   ./mv_to_input_dir_ERA5.sh $end
   YYMMDD=$(date +%Y%m%d -d "${YYMMDD} +1 day")
done

