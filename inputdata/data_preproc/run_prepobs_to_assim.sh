#!/bin/sh -l 
#. $MODULESHOME/init/ksh
#-----------------------------------------------------------------------
# Run_3Dvar - Running 3D-Var Assimilation System
#-----------------------------------------------------------------------
#
#   This script runs 3D-Var and it is formed
#     by the following parts:
#
#     - 0. : Define parameters for the Job scheduler
#     - 1. : Read-in configuration file and init main variables
#     - 2. : Manipulate dates and prepare other variables
#     - 3. : Fetch auxiliary files
#     - 4. : Fetch observations and first-guess file
#     - 5. : Prepare namelist
#     - 6. : Run the model
#     - 7. : Submit next step
#
# N.B.: Current implementation requires the Restart file from
#       from previous forecast model run to update the analysed 
#       fields. This clearly differs from the MFS implementation.
#       Likewise, first guess fields are read in from the
#       previous forecast *_grid_T.nc output file, as at this
#       time only salinity and temperature fields are analysed.
#
#-----------------------------------------------------------------------
#
# A.S., *ingv*, 2009-04
#
. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
. ${DIR_UTIL_OIS2}/load_nco
. ${DIR_UTIL_OIS2}/load_libs_prepobs
. ${STATIC_Tools}/myfunctions
. ${DIR_PREPOBS}/include

set -euvx

#--- 1. Initialize main variables
cd ${DIR_PREPOBS}

EXPNAME=data_preproc
MYCONF=102

[[ -s ${DIR_PREPOBS}/enddate_to_assim ]] || \
  { echo "No enddate_to_assim file, exiting!" ; exit 2 ; }

DTG=`cat ${DIR_PREPOBS}/enddate_to_assim`
# end of present prepobs

# today
END_DATE=$(date +%Y%m%d)00

# Go one step ahead
# one week advancement $DTG + 7
#DTG=`eval $ADDDTG $DTG +$VAR_LENGTH`
md1VAR_LENGTH=$(( $VAR_LENGTH -1 ))
# 6 days advancement $DTG + 7 - 1
DTGmd1=`eval $ADDDTG $DTG -24`  #later added +23 in oder to have a timewindow of 6days and 23 hours

WORKDIR=${OIS2_work_inpdir}/$EXPNAME/$DTG/assim

[[ -d $WORKDIR ]] && rm -rf $WORKDIR/*
mkdir -p $WORKDIR

cd $WORKDIR || \
  { echo "Working dir ($WORKDIR) not found, aborting" ; exit 5 ; }

#--- 2. Prepare variables

string_date=`splitdate $DTG`
array_date=(`echo $string_date|tr ' ' '\n'`)
YYYY=${array_date[0]} ; MM=${array_date[1]} ; DD=${array_date[2]} ; HH=${array_date[3]} ; YMD=${array_date[4]}

string_date_md1=`splitdate $DTGmd1`
array_date_md1=(`echo $string_date_md1|tr ' ' '\n'`)
YYYYmd1=${array_date_md1[0]} ; MMmd1=${array_date_md1[1]} ; DDmd1=${array_date_md1[2]} ; HHmd1=${array_date_md1[3]} ; YMDmd1=${array_date_md1[4]}

HALF_TW=` expr $VAR_LENGTH / 2 `

START=`eval $ADDDTG $DTG -${VAR_LENGTH}`
string_date_start=`splitdate $START`
array_date_start=(`echo $string_date_start|tr ' ' '\n'`)
SYYYY=${array_date_start[0]} ; SMM=${array_date_start[1]} ; SDD=${array_date_start[2]} ; SHH=${array_date_start[3]} ; SYMD=${array_date_start[4]}

END=$DTG
string_date_end=`splitdate $END`
array_date_end=(`echo $string_date_end|tr ' ' '\n'`)
EYYYY=${array_date_end[0]} ; EMM=${array_date_end[1]} ; EDD=${array_date_end[2]} ; EHH=${array_date_end[3]} ; EYMD=${array_date_end[4]}

#--- 3. Fetch ancillary files

SEASON=`whichseason $MM`

ln -sf $STATIC_DIR/GRID.nc GRID.nc

cp ${DIR_PREPOBS}/domains_${NPROC_FRC}.dat domains.dat || \
	{ echo "Layout file not found, aborting" ; exit 3 ; }
cp ${DIR_PREPOBS}/mppinit_${NPROC_FRC}.dat mppinit.dat || \
	{ echo "MPP file not found, aborting" ; exit 3 ; }

cp ${DIR_PREPOBS}/latint_tab.dat . || \
	{ echo "LATINT_TAB file not found, aborting" ; exit 3 ; }

ln -sf $STATIC_DIR/$MDTFILE MDT.nc || \
	{ echo "MDT File $MDTFILE not found, aborting" ; exit 3 ; }

ln -sf $STATIC_DIR/SLA_repres.nc SLA_repres.nc || \
       { echo "SLA_repres.nc not found, aborting" ; exit 3 ; }

cp $STATIC_DIR/lha_err.dat . || \
       { echo "lha_err.dat not found, aborting" ; exit 3 ; }

ln -sf $STATIC_DIR/insitu_errors.nc insitu_errors.nc || \
       { echo "insitu_errors.nc not found, aborting" ; exit 3 ; }

if [ $ARCHIVED_PREPOBS -eq 1 ]; then

  	cd ${DIR_PREPOBS}
  	exit 0

fi

#--- 4. Fetch 0bservations and background

# ENSEMBLES obs

if [ $LLUSEEN3 -eq 1 ]; then

	file1=$EN3_DIR/EN.4.2.1.f.profiles.c14.${SYYYY}${SMM}.nc
	if [ ! -f "${file1}" ]; then
		  file1=$EN3_DIR/EN.4.2.1.p.profiles.c14.${SYYYY}${SMM}.nc
	   if [ ! -f "${file1}" ];then
       file1=$EN3_DIR/EN.4.2.2.f.profiles.c14.${SYYYY}${SMM}.nc
       if [ ! -f "${file1}" ];then
          file1=$EN3_DIR/EN.4.2.2.p.profiles.c14.${SYYYY}${SMM}.nc
       fi
    fi
 fi

	cp ${file1} . || { echo "EN3 File not found, aborting" ; exit 3 ; }
	filename=$(basename ${file1})
	ln -sf ${filename} INS_01

	 if [ $SMM -ne $EMM ];then

		   file1=$EN3_DIR/EN.4.2.1.f.profiles.c14.${EYYYY}${EMM}.nc
		   if [ ! -f "${file1}" ]; then
		     	file1=$EN3_DIR/EN.4.2.1.p.profiles.c14.${EYYYY}${EMM}.nc
        if [ ! -f "${file1}" ]; then
           file1=$EN3_DIR/EN.4.2.2.f.profiles.c14.${EYYYY}${EMM}.nc
           if [ ! -f "${file1}" ]; then
              file1=$EN3_DIR/EN.4.2.2.p.profiles.c14.${EYYYY}${EMM}.nc
		         fi
        fi
     fi

     if [  -f ${file1} ]; then

		      cp ${file1} . || { echo "EN3 File not found, aborting" ; exit 3 ; }
		      filename=$(basename ${file1})	
 		     ln -sf ${filename} INS_02
		
		   fi
	 fi
else     #this is our condition

   mkdir -p $WORKDIR/INSITU

   TEMPDDD=${SYYYY}${SMM}${SDD}
   TEMPEDDD=${EYYYY}${EMM}${EDD}
   while [ $TEMPDDD -le $TEMPEDDD ] ;
   do
         if [ -d "${CORAINSITU}/${TEMPDDD}" ]; then
            cp -r ${CORAINSITU}/${TEMPDDD}  $WORKDIR/INSITU
         else
             echo "Directory ${CORAINSITU}/${TEMPDDD} not found, continuing..."
         fi
         TEMPDDD=`eval $ADDDDD $TEMPDDD +1`
   done

   COUNT=0;
#    for CC in "DB" "DC" "RF" "TS" "FB" "GL" "ML" "XB" "TG";
   for CC in  "ML" "XB" "TG";
   do 
	     for AA in $(ls -1 $WORKDIR/INSITU/????????/GL_*_${CC}_*);
	     do 
             COUNT=$(( COUNT + 1))
             mv ${AA} $WORKDIR/INSITU/PR_XB_`printf "%05d" $COUNT`
      done
   done

   for CC in "BA" "CT" "PF" "TE" "MO";
   do 
	  COUNT=0;
       for AA in $(ls -1 $WORKDIR/INSITU/????????/GL_*_${CC}_*);
       do
           COUNT=$(( COUNT + 1))
           mv ${AA} $WORKDIR/INSITU/PR_${CC}_`printf "%05d" $COUNT`
       done
   done


fi

# SLA obs, Roughly checking the date

SLA_FMT="NEW"

if [ $LLUSESLA -eq 1 ] && [ $YMD -gt 19920901 ];then      #this is our condition

  # set -A snam ALTIKA CRYOSAT2 HY2A JASON2 JASON3 S3a S3b S6a SWOTN
  # set -A snic     al       c2n   h2     j2     j3n    s3a  s3b s6a swon 
  # set -A cmem AltiKa Cryosat-2 HY-2B Jason-2 Jason-3 Sentinel-3A Sentinel-3B Sentinel-6A Swon
 #  set -A cnt 0 0 0 0 0 0 0 0 0
 #  set -A snam ALTIKA CRYOSAT2 JASON3 S3a S3b SWOTN
 #  set -A snic     al       c2n      j3n    s3a  s3b swon 
 #  set -A cmem AltiKa Cryosat-2 Jason-3 Sentinel-3A Sentinel-3B  Swon
 #  set -A cnt 0 0 0 0 0 0
# Define arrays
    snam=("ALTIKA" "CRYOSAT2" "JASON3" "S3a" "S3b" "SWOTN")
    snic=("al" "c2n" "j3n" "s3a" "s3b" "swon")
    cmem=("AltiKa" "Cryosat-2" "Jason-3" "Sentinel-3A" "Sentinel-3B" "Swon")
    cnt=(0 0 0 0 0 0)

   #nsat=9
   nsat=6
   d1=${SYYYY}${SMM}${SDD}
   d2=${EYYYY}${EMM}${EDD}

   id=$d1
   while [ $id -le $d2 ]; do
         ytem=$(echo $id | cut -c 1-4)
         mtem=$(echo $id | cut -c 5-6)
         is=0
         while [ $is -lt $nsat ]; do
          
               ff=${DIR_HIST_SLA}/${cmem[$is]}/${ytem}/${mtem}/nrt_global_${snic[$is]}_phy_l3_1hz_${id}_*.nc
#               set +e
               nf=$(ls ${ff} | wc -l)
#               set -e
               if [ $nf -ne 0 ]; then
                  cp $ff .   
                  ff_base=`basename $ff`
                  ncrename -v sla_filtered,SLA $ff_base && cnt[$is]=$(( ${cnt[$is]} + 1 )) && ln -sf $ff_base ${snam[$is]}`printf "%02d" ${cnt[$is]}`
               else
                  echo "File "$ff" is not available. Continue anyway!"
                  # Here possibility to put a sendmail to notify the unvailability of the file as in CMCC-OIS.
                  #continue
               fi

#               set +e
               nfroll=$(ls ${DIR_ROLL_SLA}/${cmem[$is]}/????????/nrt_global_${snic[$is]}_phy_l3_1hz_${id}_*.nc | wc -l)
#               set -e
               if [ $nfroll -ne 0 ]; then
                  ff=$( ls ${DIR_ROLL_SLA}/${cmem[$is]}/????????/nrt_global_${snic[$is]}_phy_l3_1hz_${id}_*.nc | tail -1 )
                  cp $ff .   
                  ff_base=`basename $ff`
                  ncrename -v sla_filtered,SLA $ff_base && cnt[$is]=$(( ${cnt[$is]} + 1 )) && ln -sf $ff_base ${snam[$is]}`printf "%02d" ${cnt[$is]}`
               else
                  echo "File "$ff" is not available. Continue anyway!"
                  # Here possibility to put a sendmail to notify the unvailability of the file as in CMCC-OIS.
                  #continue
               fi

               is=$(( $is + 1 ))
        done
        id=`date +%Y%m%d -d "$id +1 day"`
  done

fi

# AMSR-E SST from binary files

if [ $LLUSEAMSRE -eq 1 ]; then   # not our condition

   TEMPDDD=${SYYYY}${SMM}${SDD}
   TEMPEDDD=`eval $ADDDDD ${EYYYY}${EMM}${EDD} +1`

   while [ $TEMPDDD -le $TEMPEDDD ] ;do

        TEMPY=`echo $TEMPDDD | cut -c 1-4`
        TEMPM=`echo $TEMPDDD | cut -c 5-6`
        cp $AMSRE_DIR/y$TEMPY/m$TEMPM/amsre_${TEMPDDD}v5.gz . || \
        { echo "AMSRE file not found" ; exit 7 ; }
        $GUNZIP amsre_${TEMPDDD}v5.gz || \
        { echo "Cannot $GUNZIP AMSRE file" ; exit 7 ; }

        	TEMPDDD=`eval $ADDDDD $TEMPDDD +1`

   done

fi

# MWOI SST from binary files

if [ $LLUSEMWOI -eq 1 ]; then   #not our condition

   TEMPDDD=${SYYYY}${SMM}${SDD}
   TEMPEDDD=`eval $ADDDDD ${EYYYY}${EMM}${EDD} +1`

   while [ $TEMPDDD -le $TEMPEDDD ] ;do

        TEMPY=`echo $TEMPDDD | cut -c 1-4`
        TEMPFILE=${TEMPDDD}-REMSS-L4LRfnd-GLOB-v01-fv02-tmi_amsre_OI.nc.gz
        cp $MWOI_DIR/$TEMPY/$TEMPFILE . || \
        { echo "MWOI file not found" ; exit 7 ; }
        $GUNZIP $TEMPFILE || \
        { echo "Cannot $GUNZIP MWOI file" ; exit 7 ; }

        TEMPDDD=`eval $ADDDDD $TEMPDDD +1`

   done

fi

# SSS AQUARIUS

if [ $LLUSEAQSSS -eq 1 ]; then   #not our condition

   TEMPDDD=${SYYYY}${SMM}${SDD}
   TEMPEDDD=`eval $ADDDDD ${EYYYY}${EMM}${EDD} +1`

   while [ $TEMPDDD -le $TEMPEDDD ] ;do

        TEMPFILE=aquarius_sss_${TEMPDDD}.nc
        cp $AQSSS_DIR/$TEMPFILE . || \
        { echo "AQSSS file not found" ; exit 7 ; }

        TEMPDDD=`eval $ADDDDD $TEMPDDD +1`

   done

fi

#--- 5. Prepare namelist

if [ $LLUSEEN3 -eq 1 ]; then

   sed -e "s/_NSEED_/$MEMB/g" -e "s/_NCONF_/$MYCONF/g" \
       -e "s/_SLA_FMT_/$SLA_FMT/g" \
       -e "s/_TINS_/EN3/g" \
       -e "s/_NCPU_/$NPROC_FRC/g" $PREPOBS_NAMELIST > var_3d_nml || \
       { echo "No 3DVAR namelist, aborting!" ; exit 12 ; }

else   # this is our condition

   sed -e "s/_NSEED_/$MEMB/g" -e "s/_NCONF_/$MYCONF/g" \
       -e "s/_SLA_FMT_/$SLA_FMT/g" \
       -e "s/_TINS_/COR/g" \
       -e "s/_NCPU_/$NPROC_FRC/g" $PREPOBS_NAMELIST > var_3d_nml || \
       { echo "No 3DVAR namelist, aborting!" ; exit 12 ; }

fi


#--- 6. Run the model

cp $VAR_EXE ./MASTER || \
{ echo "No 3DVAR executable, aborting!" ; exit 12 ; }

chmod +x MASTER

time ./MASTER -d ${YMDmd1} -t 2300 -c 0 -w ${md1VAR_LENGTH} > \
     PREPOBS_${DTG}.out 2>&1 || \
     { echo "3DVAR returned non-zero status, aborting!" ; exit 12 ; }
  
mv LOG_3DVAR LOG_PREPOBS
mv var_3d_nml var_3d_nml.PREPOBS

rm -rf INSITU
#--- 7. Run Next step

cd ${DIR_PREPOBS}

#--- 7. Prepare Next step

if [ $DTG -gt $END_DATE ]; then
   exit 0
fi
NEWDTG=`eval $ADDDTG $DTG +$VAR_LENGTH`
mv enddate_to_assim enddate_to_assim.`date +%s`
cat > ${DIR_PREPOBS}/enddate_to_assim <<EOF
${NEWDTG}
EOF

exit 0

#--- End
#-----------------------------------------------------------------------
