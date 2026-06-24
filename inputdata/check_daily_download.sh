#!/bin/sh -l
. $HOME/.bashrc
. ${DIR_UTIL}/load_cdo
#-------------------------------------------------------------------------------
# Chech if the raw data of ocean observations for the specified date were 
# correclty downloaded. If any of the required files is missing, send an e-mail
# to sp1@cmcc.it
# Designed to run every day in the early morning (before 5AM), to assess the 
# presence of input files for operational analysis.
#
#                                                              Enrico 30/06/2019
#                                                         Modified Maria 03/2021
#
# Update for OIS2 inputdata and setup, running every day at 9AM
#                                                      Modified Marianna 06/2026
#-------------------------------------------------------------------------------

function write_help {
set +x
echo ""
echo "Usage: check_daily_download.sh [yyyymmdd] "
echo ""
echo "Check the existence of ocean observations that should be available at the date specified"
echo "(If no date is specified, check for today)"
echo ""
}

#-------------------------------------------------------------------------------
# 0) Preliminary
# 0.1) Check if the script can be run
if [[ $# -gt 0 ]] ; then
   if [[ $1 == "-h" || $1 == "--help" || $# -gt 1 ]] ; then
     write_help
     exit
   fi
fi

# 0.2) Setup the environment
# oparch = ${OIS_work}/input/oper_daily (set by include.daily)
# ecmarch = $oparch/ecm_mars (set by include.daily)
# stadir = ${OIS_home}/logs/oper_daily (set by include.daily)

. ${DIR_UTIL_OIS2}/descr_OIS2.sh
set -eux
DIFFDATE="$STATIC_Tools/datediff"
echo "### check.sh" >&2

# Mail subject
mail_lbl="OIS2-${machine}"

scrdir=${OIS2_home}/inputdata
export scrdir
cd $scrdir

# 0.3) Command line parameters
if [[ $# -eq 0 ]] ; then
  base_date=$(date +%Y%m%d)
else
  base_date=$1
fi

# 0.4) Logfile
logfile=${OIS2_logdir}/daily_input_check/check.log.${base_date}
mkdir -p ${OIS2_logdir}/daily_input_check
rm -f $logfile

# 0.5) Find exterme dates
# - if the required date ($base_date) is between Sun and Tue, date1 = "2 weeks before LastSat"
# - if the required date ($base_date) is between Wed and Sat, date1 = "1 week  before LastSat"

dow=$(date -d ${base_date} +%w)   # dow=0-6, 0=Sunday
lastSat=$(date -d "${base_date} - $((${dow} + 1))day" +%Y%m%d)
#for the long analysis on the 18th is better to check from some months before

#if [ $dow -le 2 ] ; then
#  date1=$(date -d "${lastSun} - 14day" +%Y%m%d)
#else
#  date1=$(date -d "${lastSun} - 7day" +%Y%m%d)
#fi

yy_rean=`date -d "$base_date -1 month" +%Y`
mm_rean=`date -d "$base_date -1 month" +%m`

if [[ ! -f ${OIS2_logdir}/MONTHLY_SUBMISSION/reanalyses_${yy_rean}${mm_rean}_submitted ]]
then
   date1=$(date -d "${base_date} - 2month" +%Y%m%d)
else
  date1=$(date -d "${base_date} - 10days" +%Y%m%d)
#   date1=$(date -d "${base_date} - 3days" +%Y%m%d)
fi
date2=$(date -d "${base_date}" +%Y%m%d)


mdate1=$(date -d "$(date +%Y%m)01 - 2month" +%Y%m%d)
mdate2=$(date -d "$(date +%Y%m)01" +%Y%m%d)

dd_base=$(echo ${base_date} | cut -c 7-8)
nextSat=$(date -d "${lastSat} + 7day" +%Y%m%d)
mm_lastSat=$(echo ${lastSat} | cut -c 5-6)
mm_nextSat=$(echo ${nextSat} | cut -c 5-6)

# 0.6) Initialize variables for reporting
nmiss1=0
nmiss2=0
nmiss3=0
str1=""
str2=""
str3=""
src1=""
src2=""
src3=""

#-------------------------------------------------------------------------------
# 1) Check daily files
# 1.1) List of daily files to be checked
# Priority codes:
# 1: data used by operational analysis (mail: error/warning)
# 2: data not used by operational analysis (mail: info)
# 3: data not used and usually delayed (mail: no message)

# ERA5 (available up to d-3+midnight d-2)
path[1]=$OIS2_data/ECMWF_FORCINGS/ERA5_daily/ARCHIVE/
priority[1]=1
src[1]="itv@ecaccess.ecmwf.int"
user[1]="itv"
pass[1]="2fa"
latency[1]=3
flagdir[1]=$DATA_ECACCESS//ERA5/input/oper_daily/ecm_mars

# EDA1
path[2]=$OIS2_data/ECMWF_FORCINGS/EDA/p1_daily/ARCHIVE/
priority[2]=1
src[2]="itv@ecaccess.ecmwf.int"
user[2]="itv"
pass[2]="2fa"
latency[2]=3
flagdir[2]=$DATA_ECACCESS//ERA5/input/oper_daily/ecm_mars

# EDA4
path[3]=$OIS2_data/ECMWF_FORCINGS/EDA/p4_daily/ARCHIVE/
priority[3]=1
src[3]="itv@ecaccess.ecmwf.int"
user[3]="itv"
pass[3]="2fa"
latency[3]=3

# EDA6
path[4]=$OIS2_data/ECMWF_FORCINGS/EDA/p6_daily/ARCHIVE/
priority[4]=1
src[4]="itv@ecaccess.ecmwf.int"
user[4]="itv"
pass[4]="2fa"
latency[4]=3

# EDA8
path[5]=$OIS2_data/ECMWF_FORCINGS/EDA/p8_daily/ARCHIVE/
priority[5]=1
src[5]="itv@ecaccess.ecmwf.int"
user[5]="itv"
pass[5]="2fa"
latency[5]=3
################_________________________

# ESA/OSTIA sst (available up to d-1)
path[6]=$OIS2_data/inputdata/SST/ESACCI
priority[6]=1
src[6]="copernicus_marine_service (conda copern_marine)"
user[6]="aborrelli"
pass[6]="A17b#D086x$"
latency[6]=2

# OSISAF sic (available up to d-3)
path[7]=$OIS2_data/inputdata/SIC/OSISAF
priority[7]=1
src[7]="ftp://osisaf.met.no/reprocessed/ice/conc-cont-reproc/v3p0/"
user[7]=""
pass[7]=""
latency[7]=3

# COPERNIC sla grid (available up to d)
path[8]=$OIS2_data/inputdata/SLA/INTERP_SLA_eORCA025/
priority[8]=1
src[8]="copernicus_marine_service (conda copern_marine)"
user[8]="aborrelli"
pass[8]="A17b#D086x$"
latency[8]=0

# sit (available up to d-3 (update at 10am, too late ?))
path[9]=$OIS2_data/inputdata/SIT/CryoSat_SMOS_merged
priority[9]=1
src[9]="ftp://ftp.awi.de/sea_ice/product/cryosat2_smos/v300/nh/"
user[9]=""
pass[9]=""
latency[9]=3

# COPERNIC sla obs and insitu (both using internal data in /data/inputs/METOCEAN/) - checking prepobs procedure
#nrt_global_al_phy_l3_1hz_20260124_20260128.nc   nrt_global_s3a_phy_l3_1hz_20260124_20260128.nc  nrt_global_swon_phy_l3_1hz_20260124_20260128.nc
#nrt_global_c2n_phy_l3_1hz_20260124_20260128.nc  nrt_global_s3b_phy_l3_1hz_20260124_20260128.nc
#path[6]=${DIR_PREPOBS}/2025121300/assim
#priority[6]=1
#src[6]="$copd"
#user[6]="$copu"
#pass[6]="$copp"
#latency[6]=0

#EN4 salinity and veritcal profiles
#path[7]=${EN4_static_dir}
#priority[7]=1
#src[7]="$copd"
#user[7]="$copu"
#pass[7]="$copp"

ymd=$date1
while [ $ymd -le $date2 ] ; do
  yy=$(echo $ymd | cut -c 1-4)
  mm=$(echo $ymd | cut -c 5-6)
  dd=$(echo $ymd | cut -c 7-8)
  ym=${yy}${mm}                 
  YMD=y${yy}m${mm}d${dd}
  diff_days=`$DIFFDATE ${date2} ${ymd}`
  echo "Check files for date "$ymd >> $logfile

# ERA5 (available up to d-3+midnight d-2)
  names[1]="Era5_lwrd.${yy}-${mm}.nc Era5_q10m.${yy}-${mm}.nc Era5_sp.${yy}-${mm}.nc Era5_t10m.${yy}-${mm}.nc Era5_uv10m.${yy}-${mm}.nc Era5_mslp.${yy}-${mm}.nc Era5_q2m.${yy}-${mm}.nc Era5_sst.${yy}-${mm}.nc Era5_t2m.${yy}-${mm}.nc Era5_precip.${yy}-${mm}.nc Era5_snow.${yy}-${mm}.nc Era5_swrd.${yy}-${mm}.nc Era5_td2m.${yy}-${mm}.nc"

# EDA1
  names[2]="ANOM_ECMWF_p1_lwrd_y${yy}m${mm}.nc ANOM_ECMWF_p1_q2m_y${yy}m${mm}.nc ANOM_ECMWF_p1_swrd_y${yy}m${mm}.nc ANOM_ECMWF_p1_wind10m_y${yy}m${mm}.nc ANOM_ECMWF_p1_mslp_y${yy}m${mm}.nc ANOM_ECMWF_p1_snow_y${yy}m${mm}.nc ANOM_ECMWF_p1_t10m_y${yy}m${mm}.nc ANOM_ECMWF_p1_precip_y${yy}m${mm}.nc ANOM_ECMWF_p1_sp_y${yy}m${mm}.nc ANOM_ECMWF_p1_t2m_y${yy}m${mm}.nc ANOM_ECMWF_p1_q10m_y${yy}m${mm}.nc ANOM_ECMWF_p1_sst_y${yy}m${mm}.nc ANOM_ECMWF_p1_td2m_y${yy}m${mm}.nc"

# EDA4
  names[3]="ANOM_ECMWF_p4_lwrd_y${yy}m${mm}.nc ANOM_ECMWF_p4_q2m_y${yy}m${mm}.nc ANOM_ECMWF_p4_swrd_y${yy}m${mm}.nc ANOM_ECMWF_p4_wind10m_y${yy}m${mm}.nc ANOM_ECMWF_p4_mslp_y${yy}m${mm}.nc ANOM_ECMWF_p4_snow_y${yy}m${mm}.nc ANOM_ECMWF_p4_t10m_y${yy}m${mm}.nc ANOM_ECMWF_p4_precip_y${yy}m${mm}.nc ANOM_ECMWF_p4_sp_y${yy}m${mm}.nc ANOM_ECMWF_p4_t2m_y${yy}m${mm}.nc ANOM_ECMWF_p4_q10m_y${yy}m${mm}.nc ANOM_ECMWF_p4_sst_y${yy}m${mm}.nc ANOM_ECMWF_p4_td2m_y${yy}m${mm}.nc"

# EDA6
  names[4]="ANOM_ECMWF_p6_lwrd_y${yy}m${mm}.nc ANOM_ECMWF_p6_q2m_y${yy}m${mm}.nc ANOM_ECMWF_p6_swrd_y${yy}m${mm}.nc ANOM_ECMWF_p6_wind10m_y${yy}m${mm}.nc ANOM_ECMWF_p6_mslp_y${yy}m${mm}.nc ANOM_ECMWF_p6_snow_y${yy}m${mm}.nc ANOM_ECMWF_p6_t10m_y${yy}m${mm}.nc ANOM_ECMWF_p6_precip_y${yy}m${mm}.nc ANOM_ECMWF_p6_sp_y${yy}m${mm}.nc ANOM_ECMWF_p6_t2m_y${yy}m${mm}.nc ANOM_ECMWF_p6_q10m_y${yy}m${mm}.nc ANOM_ECMWF_p6_sst_y${yy}m${mm}.nc ANOM_ECMWF_p6_td2m_y${yy}m${mm}.nc"

# EDA8
  names[5]="ANOM_ECMWF_p8_lwrd_y${yy}m${mm}.nc ANOM_ECMWF_p8_q2m_y${yy}m${mm}.nc ANOM_ECMWF_p8_swrd_y${yy}m${mm}.nc ANOM_ECMWF_p8_wind10m_y${yy}m${mm}.nc ANOM_ECMWF_p8_mslp_y${yy}m${mm}.nc ANOM_ECMWF_p8_snow_y${yy}m${mm}.nc ANOM_ECMWF_p8_t10m_y${yy}m${mm}.nc ANOM_ECMWF_p8_precip_y${yy}m${mm}.nc ANOM_ECMWF_p8_sp_y${yy}m${mm}.nc ANOM_ECMWF_p8_t2m_y${yy}m${mm}.nc ANOM_ECMWF_p8_q10m_y${yy}m${mm}.nc ANOM_ECMWF_p8_sst_y${yy}m${mm}.nc ANOM_ECMWF_p8_td2m_y${yy}m${mm}.nc"


# ESA/OSTIA sst (available up to d-1)
  names[6]=ARCHIVE/sst_esa_${YMD}.nc

# OSISAF sic (available up to d-2)
  names[7]="${yy}/ice2_nh_${ymd}.nc.gz ${yy}/ice2_sh_${ymd}.nc.gz"

# SLA-gridded (available up to d)
  names[8]="cesm_sla/${yy}/sla_reg-eORCA25_${ymd}.nc cesm_err_sla/${yy}/err_reg-eORCA25_$ymd.nc"

# Cryosat SIT (available up to d-3)
  names[9]="${yy}/W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_*_${ymd}_r_v300_01_l4sit.nc"




# 1.2 Check individual files
   for id in $(seq ${#path[*]}) ; do
      src1_first=True
      src2_first=True
      src3_first=True
      if [[ ${latency[$id]} -gt ${diff_days} ]] ; then
         continue
      fi 
      if [[ $id -eq 9 ]] 
      then
         continue
      fi
      if [[ $id -le 5 ]] 
      then
         if [[ $id -eq 1 ]]; then
            flagdir=${DATA_ECACCESS}/ERA5/input/oper_daily/ecm_mars/
         else
            flagdir=${DATA_ECACCESS}/EDA/pert_nemo/
         fi
         flagitv=${flagdir}/done_${yy}${mm}${dd}
         ecmflag=0
         
         for name in ${names[$id]} ; do
            cdo showdate ${path[$id]}/${name} | grep -q "${yy}-${mm}-${dd}" && ecmflag=1 || ecmflag=0
            if [[ $ecmflag -eq 1 ]] && [[ -f $flag_itv ]]
            then
                 echo "OK ${path[$id]}/${name} for date $YMD" >> $logfile
            else
                 echo "Not found (required) for date ${YMD} ${path[$id]}/${name}" >> $logfile
                 if [ ${src1_first} == True ]; then 
                    str1="$str1 \n SOURCE: ${src[$id]} USER: ${user[$id]} PASS: ${pass[$id]} \n"
                    src1_first=False
                 fi  
                 str1="$str1 ${path[$id]}/${name} (missing ${YMD})\n"
                 ((nmiss1+=1))
            fi
         done
      else
        for name in ${names[$id]} ; do
           if [[ `ls ${path[$id]}/${name} |wc -l` -ne 0 ]] ; then
              echo "OK "${path[$id]}/${name} >> $logfile
           else
              if [[ ${priority[$id]} -eq 1 ]] ; then
                 echo "Not found (required) "${path[$id]}/${name} >> $logfile
                 if [[ ${src1_first} == True ]]; then 
                    str1="$str1 \n SOURCE: ${src[$id]} USER: ${user[$id]} PASS: ${pass[$id]} \n"
                    src1_first=False
                 fi
                 str1="$str1 ${path[$id]}/${name}\n"
                 ((nmiss1+=1))
              fi
           fi
        done
      fi  #if ERA5/EDA vs other fields
   done
# 1.3 Process next date
  ymd=$(date -d "$ymd + 1day" +%Y%m%d)
done

#-------------------------------------------------------------------------------
# 2.1) List of monthly files to be checked


# ts3 [used for: sal, tem, sss]: up to d-1 (current month)
mpath[1]="$OIS2_data/inputdata/EN4/"
mpriority[1]=1
msrc[1]="http://hadobs.metoffice.com/en4/data/en4-2-1/"
muser[1]=""
mpass[1]=""
mlatency[1]=1


ymd=$mdate1
while [ $ymd -le $mdate2 ] ; do
  yy=$(echo $ymd | cut -c 1-4)
  mm=$(echo $ymd | cut -c 5-6)
  ym=${yy}${mm}                 
  YM=y${yy}m${mm}
  echo "Check files for month "$ym >> $logfile

  #mnames[1]=EN.4.2.2.f.analysis.c14.${ym}.nc
  mnames[1]=sss_EN4-ORCA025_${YM}.nc

  for id in $(seq ${#mpath[*]}) ; do
     # skip check on the same month (latency=1 month)
     if [[ ${yy}${mm} -eq `date -d "$base_date" +%Y%m` ]] && [[ ${mlatency[$id]} -eq 1 ]] 
     then
        continue
     fi
     # skip check on the previous month before the 15th - not expected 
     day_today=${dd_base} 
     if [[ ${yy}${mm} -eq `date -d "${base_date}-1 month" +%Y%m` ]] && [[ $((10#${day_today})) -le 18 ]] && [[ $id -eq 1 ]] ; then
        continue
     fi 
     src1_first=True
     for mname in ${mnames[$id]} ; do
       if [ -s ${mpath[$id]}/${mname} ] ; then
         echo "OK "${mpath[$id]}/${mname} >> $logfile
       else
         if [ ${mpriority[$id]} -eq 1 ] ; then
           echo "Not found (required) "${mpath[$id]}/${mname} >> $logfile
           if [ ${src1_first} == True ]; then 
               str1="$str1 \n SOURCE: ${msrc[$id]} USER: ${muser[$id]} PASS: ${mpass[$id]} \n"
               src1_first=False
           fi
           str1="$str1 ${mpath[$id]}/${mname} (usually available between 12th and 23th) \n"
           ((nmiss1+=1))
         fi
       fi
     done
  done
   
 # 2.3 Process next date
 ymd=$(date -d "$ymd + 1month" +%Y%m%d)
   
done

#-------------------------------------------------------------------------------
# 3) Send mail

if [ $nmiss1 -gt 0 ] ; then
  mail_obj="[$mail_lbl] analysis/forecast warning"
  if [ $dow -eq 2 ] && [ $dd_base -ge 18 ] ; then
    mail_str="Daily download. Today OIS2 analysis could fail."
  elif [ $dd_base -eq 1 ] ; then
    mail_str="Daily download. Today OIS2 analysis for SPS4 ICs could fail."
  else
    mail_str="Daily download: WARNING, files not found (${OIS2_home}/inputdata/check_daily_download.sh). The next OIS2 analysis could fail.\n"
#  if [ $mm_lastSat -ne $mm_nextSat ] ; then
#    mail_str="Daily download: OIS2 analysis for next SPS4 ICs could fail.\n"
#  fi
  fi

# List of missing files
  mail_str=${mail_str}" \n Files missing for ${base_date}, USED by operational OIS2 runs: \n ${str1}"
  echo $mail_str
  mymail=marianna.benassi@cmcc.it
  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "$mail_str" -t "$mail_obj"
  #echo -e $mail_str | mail -s "$mail_obj" $mymail
fi

exit 0
