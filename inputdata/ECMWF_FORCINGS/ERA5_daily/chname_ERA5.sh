#!/usr/bin/sh -l
#BSUB -e err_ch
#BSUB -o out_ch
#BSUB -q s_long
#BSUB -M 80G
#BSUB -P 0784

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. $DIR_UTIL_OIS2/load_nco
. $DIR_UTIL_OIS2/load_cdo
set -euvx

list_params_1="167 168 134 151 34"
dim1=`echo $list_params_1|wc -w`
dim1_m1=$(($dim1 - 1))
tmp="t2m d2m ps mslp sst"
vin=( $(echo $tmp | tr ' ' '\n') )
tmp1="t2m td2m sp mslp sst"
vfinal=( $(echo $tmp1 | tr ' ' '\n') )
params_1=( $(echo $list_params_1 | tr ' ' '\n') )
namev="2m_temperature 2m_dewpoint_temperature surface_pressure mean_sea_level_pressure sea_surface_temperature"


uv_params="165 166"
tmp2="u10m v10m"
dim2=`echo $tmp2|wc -w`
dim2_m1=$(($dim2 - 1))
vouuv=( $(echo $tmp2 | tr ' ' '\n') )
namevuv="10m_u 10m_v"

list_params_2="228 144 169 175"
tmp3="precip snow swrd lwrd"
dim3=`echo $tmp3|wc -w`
dim3_m1=$(($dim3 - 1))
vfinal3=(`echo $tmp3|tr ' ' '\n'`)
params_2=(`echo $list_params_2|tr ' ' '\n'`)
namedec="total_precipitation snowfall surface_solar_radiation_downwards surface_thermal_radiation_downwards"

YYMMDDini=$1


YYini=$(echo $YYMMDDini | cut -c 1-4)
Mini=$(echo $YYMMDDini | cut -c 5-6)
Dini=$(echo $YYMMDDini | cut -c 7-8)


YYMMDDini=$1

input_dir_in=/data/delivery/csp/cp1/in/ERA5/input/oper_daily/ecm_mars
input_dir_out=dummy_dir/TEMPORARY/
mkdir -p $input_dir_out

cd ${input_dir_out} || exit -1

YYMMDD=$YYMMDDini
	YYMMDDnew=$(date +%Y%m%d -d "${YYMMDD} +1 day")
        yy_st=$(echo $YYMMDD | cut -c 1-4)
        mm_st=$(echo $YYMMDD | cut -c 5-6)
        dd_st=$(echo $YYMMDD | cut -c 7-8)


        yy_en=`echo ${YYMMDDnew} | cut -c 1-4`
        mm_en=`echo ${YYMMDDnew} | cut -c 5-6`
        dd_en=`echo ${YYMMDDnew} | cut -c 7-8`

        ymdhms_st="${yy_st}-${mm_st}-${dd_st}T01:00:00"
        ymdhms_en="${yy_en}-${mm_en}-${dd_en}T00:01:00"

        for par in  `seq 0 $dim1_m1`; do
            vout=${vfinal[$par]}
            vname=${vin[$par]}
            i1t=${input_dir_in}/ERA5_y${yy_st}m${mm_st}d${dd_st}_${vname}.nc
            i2t=${input_dir_in}/ERA5_y${yy_en}m${mm_en}d${dd_en}_${vname}.nc
            i1=$(basename $i1t)
	           i2=$(basename $i2t)
       	    if [[ -f ${input_dir_out}/$i1 ]] 
            then
               rm -f ${input_dir_out}/$i1
            fi
            if [[ -f ${input_dir_out}/$i2 ]] 
            then
               rm -f ${input_dir_out}/$i2
            fi
            if [[ -f ${i1t}.gz ]]
            then
               cp ${i1t}.gz . ; gunzip ${i1}.gz
            else
               if [[ ! -f ${i1t} ]]
               then
                  echo "${i1t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i1t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
               fi
              cp ${i1t} .
            fi
            if [[ -f ${i2t}.gz ]]
            then
               cp ${i2t}.gz . ; gunzip ${i2}.gz
            else
              if [[ ! -f ${i2t} ]]
              then
                  echo "${i2t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i2t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
              fi
              cp ${i2t} .
            fi
            target=ERA5_${vfinal[$par]}_y${yy_st}m${mm_st}d${dd_st}.nc
       	    if [[ -f ${input_dir_out}/$target ]] 
            then
               rm -f ${input_dir_out}/$target
            fi
            cdo -O mergetime -seldate,${ymdhms_st},${ymdhms_en} $i1 -seldate,${ymdhms_st},${ymdhms_en} $i2 $target 2>/dev/null || true

	           rm -f $i1 $i2
            ncrename -h -v var${params_1[$par]},${vfinal[$par]} $target
        done

        for par in `seq 0 $dim3_m1` ; do
	           vname=${vfinal3[$par]}
            i1t=${input_dir_in}/ERA5_y${yy_st}m${mm_st}d${dd_st}_${vname}.nc
            i2t=${input_dir_in}/ERA5_y${yy_en}m${mm_en}d${dd_en}_${vname}.nc
            i1=$(basename $i1t)
            i2=$(basename $i2t)
            if [[ -f ${input_dir_out}/$i1 ]] 
            then
                rm -f ${input_dir_out}/$i1
            fi
            if [[ -f ${input_dir_out}/$i2 ]] 
            then
               rm -f ${input_dir_out}/$i2
            fi
            if [[ -f ${i1t}.gz ]]
            then
               cp ${i1t}.gz . && gunzip ${i1}.gz 
            else
               if [[ ! -f ${i1t} ]]
               then
                  echo "${i1t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i1t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
               fi
               cp ${i1t} .
            fi
            if [[ -f ${i2t}.gz ]]
            then
               cp ${i2t}.gz . && gunzip ${i2}.gz
            else
               if [[ ! -f ${i2t} ]]
               then
                  echo "${i2t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i2t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
               fi
               cp ${i2t} .
            fi
       	    target=ERA5_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
            if [[ -f ${input_dir_out}/$target ]] 
            then
               rm -f ${input_dir_out}/$target
            fi
	           cdo -O mergetime -seldate,${ymdhms_st},${ymdhms_en} $i1 -seldate,${ymdhms_st},${ymdhms_en} $i2 $target 2>/dev/null || true
            rm -f $i1 $i2
            ncrename -h -v var${params_2[$par]},${vfinal3[$par]} $target
        done

        vname=wind10m
        i1t=${input_dir_in}/ERA5_y${yy_st}m${mm_st}d${dd_st}_${vname}.nc
        i2t=${input_dir_in}/ERA5_y${yy_en}m${mm_en}d${dd_en}_${vname}.nc
        i1=$(basename $i1t)
        i2=$(basename $i2t)
        if [[ -f ${input_dir_out}/$i1 ]] 
        then
           rm -f ${input_dir_out}/$i1
        fi
        if [[ -f ${input_dir_out}/$i2 ]] 
        then
           rm -f ${input_dir_out}/$i2
        fi
        if [[ -f  ${i1t}.gz ]]
        then
           cp ${i1t}.gz . && gunzip ${i1}.gz 
        else
          if [[ ! -f ${i1t} ]]
          then
                  echo "${i1t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i1t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
           fi
           cp ${i1t} .
        fi
        if [[ -f  ${i2t}.gz ]]
        then
           cp ${i2t}.gz . && gunzip ${i2}.gz
        else
           if [[ ! -f ${i2t} ]]
           then
                  echo "${i2t} not yet present! exit now"
                  ${DIR_UTIL_OIS2}/sendmail.sh -m $machine -e $mymail -M "${i2t} not yet present! exit now" -t "$OIS2_input/ECMWF_FORCINGS/chname_EDA.sh exited"
                  exit 1
           fi
           cp ${i2t} .
        fi
       	target=ERA5_${vname}_y${yy_st}m${mm_st}d${dd_st}.nc
        if [[ -f ${input_dir_out}/$target ]] 
        then
          rm -f ${input_dir_out}/$target
        fi
        cdo -O mergetime -seldate,${ymdhms_st},${ymdhms_en} $i1 -seldate,${ymdhms_st},${ymdhms_en} $i2 $target 2>/dev/null || true
        rm -f $i1 $i2
        ncrename -h -v var165,u10m $target
        ncrename -h -v var166,v10m $target

