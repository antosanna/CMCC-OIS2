#!/bin/sh -l
set -x

#!/bin/sh -l

module load oneapi-2025.0.4/2025.0.4-bwtfc oneapi-2025.0.4/cdo-threadsafe  oneapi-2025.0.4/impi-2021.14.2 oneapi-2025.0.4/impi-2021.14.2/netcdf-fortran-threadsafe oneapi-2025.0.4/impi-2021.14.2/netcdf-c-threadsafe oneapi-2025.0.4/impi-2021.14.2/netcdf-cxx-threadsafe oneapi-2025.0.4/impi-2021.14.2/ncview oneapi-2025.0.4/impi-2021.14.2/nco oneapi-2025.0.4/impi-2021.14.2/parallel-netcdf oneapi-2025.0.4/curl oneapi-2025.0.4/impi-2021.14.2/hdf5-threadsafe oneapi-2025.0.4/magics-threadsafe oneapi-2025.0.4/eccodes-threadsafe oneapi-2025.0.4/gmake  oneapi-2025.0.4/impi-2021.14.2/ncview/2.1.9-47rr4 oneapi-2025.0.4/impi-2021.14.2/netcdf-c-threadsafe/4.9.2-wbdmu oneapi-2025.0.4/openssl/3.4.0-m3wyk

COMP=mpiifx

str=""
for f in Read_Dimensions.F90 read_field2st.F90 read_field1st.F90 write_q10m_t10m.F90 tq210m.F90 handlerr.F90 read_field1st_time.F90 ; do
   $COMP -c -O2 -heap-arrays -I $NETCDF/include $f || exit -1
   str="$str `echo $f | cut -d. -f1`.o"
done
exedir=cassandra
mkdir -p $exedir
$COMP -g $str -L$NETCDF/lib -lnetcdf -lnetcdff -o $exedir/TQ210M.x
mv $str $exedir
