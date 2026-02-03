#!/bin/sh -l
#BSUB -P 0490
#BSUB -q s_long
#BSUB -o /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/SLA/download_SLA_offline_%J.out
#BSUB -e /users_home/cmcc/cp1/CPS/CMCC-OIS2/logs/SLA/download_SLA_offline_%J.err
#BSUB -J sla_download_offline
#BSUB -M 1G

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
#. ~/load_conda
. $DIR_UTIL_OIS2/load_sosie

#conda activate /users_home/cmcc/sp1/.conda/envs/cmt_1.0
#conda activate $envcondaOIS2
. ~/load_miniconda
conda activate copern_marine
set -xeuv
export COPERNICUSMARINE_SERVICE_USERNAME=aborrelli
export COPERNICUSMARINE_SERVICE_PASSWORD=A17b#D086x$

INDIR=$OIS2_work_inpdir/SLA/
mkdir -p $INDIR

startdate=20240815
for nmonth in `seq 0 0` ; do

  YY=$(date +%Y -d "$startdate +${nmonth} month ")
  MM=$(date +%m -d "$startdate +${nmonth} month ")

  mkdir -p $OIS2_work_inpdir/SLA/$YY

  if [[ `ls $OIS2_work_inpdir/SLA/$YY/nrt_global_allsat_phy_l4_${YY}${MM}* |wc -l` -ne 0 ]]
  then
     rm -f $OIS2_work_inpdir/SLA/$YY/nrt_global_allsat_phy_l4_${YY}${MM}*
  fi

  if [[ -f $OIS2_work/inputdata/SLA/download_sla.py ]]
  then
     rm $OIS2_work_inpdir/SLA/download_sla.py
  fi
  if [[ -f $OIS2_work/inputdata/SLA/download_sla_${YY}${MM}.py ]]
  then
     rm $OIS2_work_inpdir/SLA/download_sla_${YY}${MM}.py
  fi
  #before 202411 using template_025
  sed -e "s/_MM_/$MM/g;s/_YY_/$YY/g" $OIS2_input/SLA/download_template_025.py > $OIS2_work_inpdir/SLA/download_sla_${YY}${MM}.py

  #after 202412 using template_0125
  #sed -e "s/_MM_/$MM/g;s/_YY_/$YY/g" $OIS2_input/SLA/download_template_0125.py > $OIS2_work_inpdir/SLA/download_sla_${YY}${MM}.py
  cd $OIS2_work_inpdir/SLA/
 
  python download_sla_${YY}${MM}.py
  if [[ `ls $OIS2_work_inpdir/SLA/${YY}/*_\(?\).nc |wc -l` -ne 0 ]]
  then
     rm $OIS2_work_inpdir/SLA/${YY}/*_\(?\).nc
  fi

  set +euvx
  . $DIR_UTIL_OIS2/load_nco
  set -euvx
  FINAL_DIR="$OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_sla/"
  FINAL_DIR_ERR="$OIS2_work_inpdir/SLA/INTERP_SLA_eORCA025/cesm_err_sla/"
  mkdir -p  ${FINAL_DIR}/${YY}
  mkdir -p  ${FINAL_DIR_ERR}/${YY}

  cp $OIS2_exe/sosie3.x ${FINAL_DIR}/
  cp $OIS2_exe/sosie3.x ${FINAL_DIR_ERR}/

  for listf in $(ls ${INDIR}/${YY}/nrt_global_allsat_phy_l4_${YY}${MM}*.nc);
  do   
     YYMMDD=$(ls ${listf} | rev | cut -d_ -f 2 | rev)
     if [[ ! -e ${FINAL_DIR}/${YY}/sla_reg-eORCA25_${YYMMDD}.nc ]] || [[ ! -e ${FINAL_DIR_ERR}/${YY}/err_reg-eORCA25_${YYMMDD}.nc ]] ; then
	      
       cd ${FINAL_DIR}/
       FIN=file_${YYMMDD}.nc      
       ncpdq -U  ${listf} -O ${FINAL_DIR}/$FIN 
       ncks --mk_rec_dmn time ${FINAL_DIR}/$FIN -O ${FINAL_DIR}/$FIN
       if [[ -f namelist ]]
       then
          rm namelist
       fi
       if [[ -f namelist_${YYMMDD} ]]
       then
         rm namelist_${YYMMDD}
       fi
       sed -e "s/_FILENAME_/$FIN/g;s/_DATEE_/${YYMMDD}/g"   $OIS2_home/inputdata/SLA/namelist_INTERP_2D_sla > namelist_${YYMMDD}
       ./sosie3.x -f namelist_${YYMMDD} 
       mv sla_reg-eORCA25_${YYMMDD}.nc ${YY}
       rm ${FIN}

       cd ${FINAL_DIR_ERR}/
       FIN_ERR=file_${YYMMDD}.nc
       ncpdq -U  ${listf} -O ${FINAL_DIR_ERR}/${FIN_ERR} 
       ncks --mk_rec_dmn time ${FINAL_DIR_ERR}/${FIN_ERR} -O ${FINAL_DIR_ERR}/${FIN_ERR}

       if [[ -f namelist_${YYMMDD} ]]
       then
          rm namelist_${YYMMDD}
       fi
       sed -e "s/_FILENAME_/$FIN/g;s/_DATEE_/${YYMMDD}/g"   $OIS2_home/inputdata/SLA/namelist_INTERP_2D_err_sla > namelist_${YYMMDD}
       ./sosie3.x -f namelist_${YYMMDD}
       mv err_reg-eORCA25_${YYMMDD}.nc ${FINAL_DIR_ERR}/${YY}
       rm ${FIN_ERR}

    fi
  done
done
