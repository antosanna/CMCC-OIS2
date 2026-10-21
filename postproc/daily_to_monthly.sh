#!/bin/sh -l

#BSUB -q s_medium 
#BSUB -J daily_to_monthly
#BSUB -e ../logs/daily_to_monthly/daily_to_monthly%J.err 
#BSUB -o ../logs/daily_to_monthly/daily_to_monthly%J.out 
#BSUB -P 0784 
#BSUB -M 30000

. ~/.bashrc
. $DIR_UTIL/load_cdo
. $DIR_UTIL_OIS2/descr_OIS2.sh

set -exvu

export HDF5_USE_FILE_LOCKING=FALSE
# get input args
year=`date +%Y`
mon=07
today_yymmm1=$year$mon

grids="grid_T grid_U grid_V"

WKDIR=$SCRATCHDIR/OIS2/DAILY_MONTHLY
OUTDIR_DAILY=$OIS2_work/rea_archive/OPSLAMB0/DAILY/$year
OUTDIR_MONTHLY=$OIS2_work/rea_archive/OPSLAMB0/MONTHLY/$year
mkdir -p $OUTDIR_DAILY $OUTDIR_MONTHLY


echo "Processing year ${year} for month ${mon}"
dsrc=$WKDIR/$year$mon
wrkdir=${dsrc}/tmp
mkdir -p $wrkdir $dsrc 

ASPECT_ARCH=/work/cmcc/aspect/CESM2/OPSLAMB0/
NEMO_ARCH1=$OIS2_work/run_oce_assim/OPSLAMB0/

yearm1=$(date -d "${year}${mon}15 -1 month" +%Y)
monm1=$(date -d "${year}${mon}15 -1 month" +%m)
monp1=$(date -d "${year}${mon}15 +1 month" +%m)
yearp1=$(date -d "${year}${mon}15 +1 month" +%Y)
mkdir -p $WKDIR/$year$mon
list_of_startdate=`ls $NEMO_ARCH1/| grep $year${mon}`
list_of_startdate+=" `ls $NEMO_ARCH1/| grep $yearm1${monm1}`"
for startdate in $list_of_startdate
do
        if [[ `ls $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${yearm1}${monm1}??_${year}${mon}??_grid_T_${year}${mon}??-${year}${mon}??.nc|wc -l` -ne 0 ]]
        then
           rsync -auv $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${yearm1}${monm1}??_${year}${mon}??_grid_T_${year}${mon}??-${year}${mon}??.nc $WKDIR/$year$mon
        fi
        if [[ `ls $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${year}${mon}??_${year}${mon}??_grid_T_${year}${mon}??-${year}${mon}??.nc|wc -l` -ne 0 ]]
        then
           rsync -auv $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${year}${mon}??_${year}${mon}??_grid_T_${year}${mon}??-${year}${mon}??.nc $WKDIR/$year$mon
        fi
        if [[ `ls  $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${year}${mon}??_${yearp1}${monp1}??_grid_T_${year}${mon}??-${year}${mon}??.nc|wc -l` -ne 0 ]]
        then
           rsync -auv $NEMO_ARCH1/$startdate/run/OPSLAMB0_1d_${year}${mon}??_${yearp1}${monp1}??_grid_T_${year}${mon}??-${year}${mon}??.nc $WKDIR/$year$mon
        fi
done
#just for September 2024, copy from aspect dir the first week
if [[ $year$mon -eq 202409 ]]
then
        rsync -auv $ASPECT_ARCH/2024083100/run/OPSLAMB0_1d_20240831_20240906_grid_T_202409??-202409??.nc $WKDIR/$year$mon
fi

mondays=`$DIR_UTIL/days_in_month.sh $mon $year`
cd $wrkdir
# split grid suffix
grids=`echo ${grids} | tr "-" "\n"`

for grid in ${grids} ; do
   # split iteratively to daily files (needed to keep only good data)
   # merge into single monthly file
   thefiles=`ls ${dsrc}/OPSLAMB0_1d_????????_????????_grid_T_${year}${mon}??-${year}${mon}??.nc`
   if [[ `ls ${dsrc}/OPSLAMB0_1d_????????_????????_grid_T_${year}${mon}??-${year}${mon}??.nc|wc -l` -ne $mondays ]]
   then
      exit
   fi
#   tmp1="merged_${year}${mon}_${grid}.nc"
#   cdo -O -mergetime ${thefiles} ${tmp1} #&& rm ${thefiles}

   # compress NetCDF
   if [[ -f $OIS2_logdir/MONTHLY_SUBMISSION/reanalyses_${today_yymmm1}_submitted ]]
   then
      outfile="NEMO_1d_y${year}m${mon}_${grid}.nc"
      if [[ ! -f $outfile ]]
      then
         cdo -O -mergetime ${thefiles} ${outfile} #&& rm ${thefiles}
      fi
      outfile_monmean="NEMO_1m_y${year}m${mon}_${grid}.nc"
      if [[ ! -f $outfile_monmean ]]
      then
         cdo -O -monmean ${outfile} ${outfile_monmean} #&& rm ${thefiles}
      fi
      outfile="NEMO_1d_y${year}m${mon}_${grid}.nc"
   else
      outfile="NEMO_1d_y${year}m${mon}_${grid}.tmp.nc"
      if [[ ! -f $outfile ]]
      then
         cdo -O -mergetime ${thefiles} ${outfile} #&& rm ${thefiles}
      fi
      outfile_monmean="NEMO_1m_y${year}m${mon}_${grid}.tmp.nc"
      if [[ ! -f $outfile_monmean ]]
      then
         cdo -O -monmean ${outfile} ${outfile_monmean} #&& rm ${thefiles}
      fi
   fi

   # clean up
   mv ${outfile} $OUTDIR_DAILY
   mv ${outfile_monmean} $OUTDIR_MONTHLY
done


echo "done"

