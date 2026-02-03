!/bin/ksh
set -x


#NCDF=/home/ans012/local/netcdf
COMP=ifort

str=""
for f in Read_Dimensions.F90 read_field2st.F90 read_field1st.F90 write_q10m_t10m.F90 tq210m.F90 handlerr.F90 read_field1st_time.F90 ; do
   $COMP -c -O2 -heap-arrays -I $NETCDF/include $f || exit -1
   str="$str `echo $f | cut -d. -f1`.o"
done

$COMP -g $str -L$NETCDF/lib -lnetcdf -lnetcdff -o TQ210M.x
cp TQ210M.x ../

#./TQ210M.x ../data/ECMWF_t2m_y2021m01.nc ../data/ECMWF_q2m_y2021m01.nc ../data/ECMWF_u10m_y2021m01.nc ../data/ECMWF_v10m_y2021m01.nc ../data/ECMWF_sst_y2021m01.nc
