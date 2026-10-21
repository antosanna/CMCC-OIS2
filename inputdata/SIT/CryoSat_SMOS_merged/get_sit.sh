#!/bin/sh -l
#BSUB -P 0784
#BSUB -M 1000
#BSUB -q s_download
#BSUB -J download_cryosat2_SIT_test
#BSUB -e /work/cmcc/cp1/CPS/CMCC-OIS2/logs/CRYOSAT_SIT/download_cryosat2_SIT_%J.err
#BSUB -o /work/cmcc/cp1/CPS/CMCC-OIS2/logs/CRYOSAT_SIT/download_cryosat2_SIT_%J.out

. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
. ${DIR_UTIL_OIS2}/load_nco
wget="/usr/bin/wget --inet4-only"
set -euvx

YY=${1:-`date +%Y`}
MM=${2:-`date +%m`}
YYm1=`date -d "${YY}${MM}15 -1 month" +%Y`
MMm1=`date -d "${YY}${MM}15 -1 month" +%m`
nrt=1 #near-realtime flag--> if 1 retrieve also from LATEST directory on remote repo
CRYODIR=$OIS2_work//inputdata/SIT/CryoSat_SMOS_merged/
mkdir -p $CRYODIR
mkdir -p $CRYODIR/TEMPORARY
mkdir -p $CRYODIR/$YY
mkdir -p $CRYODIR/$YYm1
mkdir -p $CRYODIR/old

data_arch=$OIS2_data/inputdata/SIT/CryoSat_SMOS_merged/
mkdir -p ${data_arch}

####EVERYTHING IN TEMPORARY DIR
cd $CRYODIR/TEMPORARY

oldf=`ls *.nc |wc -l`
if [[ $oldf -ne 0 ]] ; then
  rm $CRYODIR/TEMPORARY/*.nc
fi

#possible previous download attempt
#wget adding .[1,2...] tag
oldf=`ls *.nc.? |wc -l`
if [[ $oldf -ne 0 ]] ; then
   rm $oldf
fi

version="v300"
set +e
#ftp://ftp.awi.de/sea_ice/product/cryosat2_smos//
####date_tag=20241228_20250103
$wget ftp://ftp.awi.de/sea_ice/product/cryosat2_smos/${version}/nh/${YYm1}/${MMm1}/W_XX*${version}*.nc 
$wget ftp://ftp.awi.de/sea_ice/product/cryosat2_smos/${version}/nh/${YY}/${MM}/W_XX*${version}*.nc 
if [[ $nrt -eq 1 ]] ; then
   $wget ftp://ftp.awi.de/sea_ice/product/cryosat2_smos/${version}/nh/LATEST/W_XX*${version}*.nc 
fi
set -e
#for version v300
if [[ $version == "v300" ]] 
then
  var_orig="analysis_sea_ice_thickness"
  var_new="sea_ice_thickness"
  unc_orig="analysis_sea_ice_thickness_unc"
  unc_new="sea_ice_thickness_uncertainty"
  listaobs=`ls W_XX*_o_${version}*l4sit.nc`

  #near-real-time obs tagged as _o_ (in LATEST directory)
  #reprocessed data (3/4 weeks delay) tagged as _r_ (in $YYYY}/${MM} directory)

  #if both of them available we keep the _r_ one

  for f in $listaobs ; do


     rfile="${f/_o_/_r_}"
     if [[ -f $rfile ]]; then
        rm $f
     fi

  done 


  listaf=`ls W_XX*${version}*l4sit.nc` 
  for ff in $listaf 
  do
    
    #degradation of the observation is needed in to have a number of grid point compliant to the v206 version on which the data assimilation has been tuned
    #AndreaC suggests to avoid regridding (i.e. averaging obs to reduce the obs dimensionality) and to keep one point yes and one no to reduce the number of obs

    mode_tag=`echo $ff|rev|cut -d '_' -f4|rev` ##it could be o - operational, r -reprocessed
    rootname=`echo $ff|rev|cut -d '.' -f2|rev`
    date_tag=`echo $ff|rev|cut -d '_' -f5,6|rev`

    #example: date_tag=20241228_20250103
    year1tag=`echo ${date_tag}|cut -c1-4`
    year2tag=`echo ${date_tag}|cut -d '_' -f2|cut -c1-4`

    finalname=W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_${date_tag}_${mode_tag}_${version}_01_l4sit.nc
    finalname_r=W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_${date_tag}_r_${version}_01_l4sit.nc
    if [[ -f $CRYODIR/${year1tag}/${finalname_r} ]] ; then
        echo "already present in its final version in $CRYODIR/${year1tag}/"
        rm ${ff}
        continue
    fi

    ncks -O -d xc,0,,2 -d yc,0,,2 "$ff" ${rootname}_sub.nc
    #ncap2 -O -s "${var_orig} = float(${var_new}); ${var_orig}@_FillValue =float(NaN); ${unc_orig} = float(${unc_new}); ${unc_orig}@_FillValue = float(NaN); xc = float(xc); yc = float(yc); lat = float(lat); lon = float(lon);" ${rootname}_sub.nc ${rootname}_float.nc
    ncap2 -O -s "${var_orig} = float(${var_new}); ${unc_orig} = float(${unc_new}); xc = float(xc); yc = float(yc); lat = float(lat); lon = float(lon);" ${rootname}_sub.nc ${rootname}_float.nc
    ncks -O -C -x -v ${var_new},${unc_new} ${rootname}_float.nc ${rootname}_def.nc
    
    #example: date_tag=20241228_20250103
    year1tag=`echo ${date_tag}|cut -c1-4`
    year2tag=`echo ${date_tag}|cut -d '_' -f2|cut -c1-4`

    #data across two years to be copied on both directories
    #data copied on both work and data to ensure portability on Juno

    if [[ ${year1tag} -eq ${year2tag} ]] ; then
          finalpath=$CRYODIR/${year1tag}
       	  mkdir -p $finalpath
          finaldata=${data_arch}/${year1tag}
          mkdir -p  ${finaldata}
          if [[ ${mode_tag} == "r" ]]
          then
             ofile="${finalname/_r_/_o_}"
             if [[ -f ${finalpath}/${ofile} ]] ; then
                mv ${finalpath}/${ofile} $CRYODIR/old/
             fi
             if [[ -f ${finaldata}/${ofile} ]] ; then
                rm ${finaldata}/${ofile}
             fi
          fi
          rsync -auv ${rootname}_def.nc ${finalpath}/${finalname}
          rsync -auv ${rootname}_def.nc ${finaldata}/${finalname}
    else
       finalpath1=$CRYODIR/${year1tag}
       finaldata1=${data_arch}/${year1tag}
       mkdir -p $finalpath1
       mkdir -p ${finaldata1}
       finalpath2=$CRYODIR/${year2tag}
       finaldata2=${data_arch}/${year2tag}
       mkdir -p $finalpath2
       mkdir -p ${finaldata2}
       if [[ ${mode_tag} == "r" ]]
       then
           ofile="${finalname/_r_/_o_}"
           if [[ -f ${finalpath1}/${ofile} ]] ; then
                mv ${finalpath1}/${ofile}  $CRYODIR/old/
           fi  
           if [[ -f ${finalpath2}/${ofile} ]] ; then
              rm ${finalpath2}/${ofile}
           fi
           if [[ -f ${finaldata1}/${ofile} ]] ; then
              rm ${finaldata1}/${ofile}
           fi  
           if [[ -f ${finaldata2}/${ofile} ]] ; then
              rm ${finaldata2}/${ofile}
           fi
       fi  

       rsync -auv ${rootname}_def.nc ${finalpath1}/${finalname}
       rsync -auv ${rootname}_def.nc ${finalpath2}/${finalname}
       
       rsync -auv ${rootname}_def.nc ${finaldata1}/${finalname}
       rsync -auv ${rootname}_def.nc ${finaldata2}/${finalname}
    fi  

    rm $ff

  done
fi



