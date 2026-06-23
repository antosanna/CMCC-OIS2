#!/bin/sh -l
#BSUB -P 0784
#BSUB -q s_medium
#BSUB -J input2work_operational
#BSUB -e /work/cmcc/cp1//CPS/CMCC-CPS1/logs/tests/input2work_operational_%J.err
#BSUB -o /work/cmcc/cp1//CPS/CMCC-CPS1/logs/tests/input2work_operational_%J.out
#BSUB -M 500M

. $HOME/.bashrc
. $DIR_UTIL/descr_CPS.sh
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
yyyy=`date +%Y`
mm=`date +%m`
if [[ $mm == "01" ]] || [[ $mm == "02" ]]
then
  yym1=$((${yyyy}-1))
else
  yym1=$yyyy
fi

data_era5=$OIS2_data/ECMWF_FORCINGS/ERA5_daily/ARCHIVE
mkdir -p $OIS2_work_inpdir/ERA5/
cd ${data_era5}

listaf=`ls Era5_*.{${yym1},${yyyy}}-??.nc|uniq`
for f in $listaf 
do  
   if [[ -f  $OIS2_work_inpdir/ERA5/$f ]] ; then
       rm $OIS2_work_inpdir/ERA5/$f
   fi
   if  [[ -L $OIS2_work_inpdir/ERA5/$f ]] ; then
           continue
   else
         ln -sf $OIS2_data/ECMWF_FORCINGS/ERA5_daily/ARCHIVE/$f $OIS2_work_inpdir/ERA5/$f
   fi
done

data_eda=$OIS2_data/ECMWF_FORCINGS/EDA/     
mkdir -p $OIS2_work_inpdir/ERA5_PERT

for pert in 1 4 6 8
do
   mkdir -p $OIS2_work_inpdir/ERA5_PERT/P${pert}

   cd ${data_eda}/p${pert}_daily/ARCHIVE
   listaf=`ls ANOM_ECMWF_p${pert}_*_y{${yym1},${yyyy}}m??.nc|uniq`
   for f in $listaf
   do
       if [[ -f $OIS2_work_inpdir/ERA5_PERT/P${pert}/$f ]] ; then
          rm $OIS2_work_inpdir/ERA5_PERT/P${pert}/$f
       fi
       if [[ -L $OIS2_work_inpdir/ERA5_PERT//P${pert}/$f ]] ; then
            continue
       else
          ln -sf ${data_eda}/p${pert}_daily/ARCHIVE/$f $OIS2_work_inpdir/ERA5_PERT/P${pert}/$f
         
       fi
   done 
done


###ESACCI SST
mkdir -p $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4
cd ${OIS2_data}/inputdata/SST/ESACCI/ARCHIVE/
listaf=`ls sst_esa_y{${yym1},${yyyy}}*.nc|uniq`
for f in $listaf 
do
  if [[ -f $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f ]] ; then
     rm  $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f
  fi
  if  [[ -L $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f ]] ; then
      continue
  else
     ln -sf ${OIS2_data}/inputdata/SST/ESACCI/ARCHIVE/$f  $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f
  fi
done

###EN4
mkdir -p $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4 
cd ${OIS2_data}/inputdata/EN4/
listaf=`ls *EN4-ORCA025_y{${yym1},${yyyy}}*.nc |uniq`
for f in $listaf
do
   if [[ -f  $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f ]] 
   then
       rm $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f
   fi
   if [[ -L $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f ]]
   then 
      continue
   else 
      ln -sf ${OIS2_data}/inputdata/EN4/$f  $OIS2_work_inpdir/STATIC_DA_NEMO42/SST_EN4/$f
   fi
   if [[ -f $OIS2_work_inpdir/STATIC_DA_NEMO42/OTHER_FORCINGS/T3D/$f ]] 
   then
     rm $OIS2_work_inpdir/STATIC_DA_NEMO42/OTHER_FORCINGS/T3D/$f
   fi
   if [[ -L $OIS2_work_inpdir/STATIC_DA_NEMO42/OTHER_FORCINGS/T3D/$f ]]
   then
       continue
   else
      ln -sf ${OIS2_data}/inputdata/EN4/$f $OIS2_work_inpdir/STATIC_DA_NEMO42/OTHER_FORCINGS/T3D/$f
   fi
done 

###INSITU/SLAOBS
mkdir -p $OIS2_work_inpdir/data_preproc
cd ${OIS2_data}/inputdata/data_preproc
listad=`ls -d {${yym1},${yyyy}}????00`
for dd in $listad
do 
  rsync -auv  ${OIS2_data}/inputdata/data_preproc/$dd $OIS2_work_inpdir/data_preproc/.
done

###SIC
mkdir -p $OIS2_work_inpdir/SIC/OSISAF
rsync -auv ${OIS2_data}/inputdata/SIC/OSISAF/${yyyy} $OIS2_work_inpdir/SIC/OSISAF/.
if [[ ${yym1} != ${yyyy} ]] 
then
  rsync -auv ${OIS2_data}/inputdata/SIC/OSISAF/${yym1} $OIS2_work_inpdir/SIC/OSISAF/.
fi

###SLA-GRID
mkdir -p $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_err_sla
mkdir -p $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_sla
rsync -auv ${OIS2_data}/inputdata/SLA/INTERP_SLA_eORCA025/cesm_err_sla/${yyyy} $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_err_sla/.
rsync -auv ${OIS2_data}/inputdata/SLA/INTERP_SLA_eORCA025/cesm_sla/${yyyy} $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_sla/.
if [[ ${yym1} != ${yyyy} ]]
then
   rsync -auv ${OIS2_data}/inputdata/SLA/INTERP_SLA_eORCA025/cesm_err_sla/${yym1} $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_err_sla/.
   rsync -auv ${OIS2_data}/inputdata/SLA/INTERP_SLA_eORCA025/cesm_sla/${yym1} $OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_sla/.
fi

###SIT
mkdir -p $OIS2_work_inpdir/SIT/CryoSat_SMOS_merged
rsync -auv ${OIS2_data}/inputdata/SIT/CryoSat_SMOS_merged/${yyyy} $OIS2_work_inpdir/SIT/CryoSat_SMOS_merged/.
if [[ ${yym1} != ${yyyy} ]]
then
   rsync -auv ${OIS2_data}/inputdata/SIT/CryoSat_SMOS_merged/${yym1} $OIS2_work_inpdir/SIT/CryoSat_SMOS_merged/.
fi

