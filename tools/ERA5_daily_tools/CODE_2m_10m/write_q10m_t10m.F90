      subroutine write_q10m(FILE_NAME,NLONS,NLATS,NTIME,NDIMS,hum,lons,lats,time,TIM_UNITS,TIM_CAL)
        use netcdf
        implicit none
      
        ! This is the name of the data file we will create.
        character (len = *),intent(in) :: FILE_NAME
        integer :: ncid, i
      
        ! We are writing 2D data, a 6 x 12 lat-lon grid. We will need two
        ! netCDF dimensions.
        integer,intent(in) :: NDIMS
        integer,intent(in) :: NLATS, NLONS, NTIME
        character (len = *), parameter :: LAT_NAME = "lat"
        character (len = *), parameter :: LON_NAME = "lon"
        character (len = *), parameter :: TIM_NAME = "time"
        integer :: lat_dimid, lon_dimid, tim_dimid
      
        ! In addition to the latitude and longitude dimensions, we will also
        ! create latitude and longitude netCDF variables which will hold the
        ! actual latitudes and longitudes. Since they hold data about the
        ! coordinate system, the netCDF term for these is: "coordinate
        ! variables."
        real*8,intent(in )   :: hum(NLONS,NLATS,NTIME)
        real*8,intent(in)    :: lons(NLONS)
        real*8,intent(in)    :: lats(NLATS)
        real*8,intent(in)  :: time(NTIME)
        character (len = 200),intent(inout) :: TIM_UNITS
        character (len = 200),intent(inout) :: TIM_CAL
        
        integer :: lat_varid, lon_varid, tim_varid
      
        ! We will write surface temperature and pressure fields. 
        character (len = *), parameter :: HUM_NAME="q10m"
        integer :: hum_varid
        integer :: dimids(NDIMS)
      
        ! It's good practice for each variable to carry a "units" attribute.
        character (len = *), parameter :: UNITS = "units"
        character (len = *), parameter :: HUM_UNITS = ""
        character (len = *), parameter :: LAT_UNITS = "degrees_north"
        character (len = *), parameter :: LON_UNITS = "degrees_east"
      
        ! Loop indices
        integer :: lat, lon
      

        ! Create the file. 
        call check( nf90_create(FILE_NAME, nf90_clobber, ncid) )
      
        ! Define the dimensions.
        call check( nf90_def_dim(ncid, LAT_NAME, NLATS, lat_dimid) )
        call check( nf90_def_dim(ncid, LON_NAME, NLONS, lon_dimid) )
        call check( nf90_def_dim(ncid, TIM_NAME, NF90_UNLIMITED, tim_dimid) )

        ! Define the coordinate variables. They will hold the coordinate
        ! information, that is, the latitudes and longitudes. A varid is
        ! returned for each.
        call check( nf90_def_var(ncid, LAT_NAME, NF90_REAL, lat_dimid, lat_varid) )
        call check( nf90_def_var(ncid, LON_NAME, NF90_REAL, lon_dimid, lon_varid) )
        call check( nf90_def_var(ncid, TIM_NAME, NF90_REAL, tim_dimid, tim_varid) )
      
        ! Assign units attributes to coordinate var data. This attaches a
        ! text attribute to each of the coordinate variables, containing the
        ! units.

        TIM_UNITS=trim(TIM_UNITS)
        TIM_CAL=trim(TIM_CAL)

        call check( nf90_put_att(ncid, lat_varid, UNITS, LAT_UNITS) )
        call check( nf90_put_att(ncid, lat_varid, "standard_name","latitude" ) )
        call check( nf90_put_att(ncid, lat_varid, "long_name", "latitude") )
        call check( nf90_put_att(ncid, lat_varid, "axis", "Y") )

        call check( nf90_put_att(ncid, lon_varid, UNITS, LON_UNITS) )
        call check( nf90_put_att(ncid, lon_varid, "standard_name","longitude" ) )
        call check( nf90_put_att(ncid, lon_varid, "long_name", "longitude") )
        call check( nf90_put_att(ncid, lon_varid, "axis", "X") )

        call check( nf90_put_att(ncid, tim_varid, "standard_name","time") )
        call check( nf90_put_att(ncid, tim_varid, UNITS, TIM_UNITS) )
        call check( nf90_put_att(ncid, tim_varid, "calendar", TIM_CAL) )
        call check( nf90_put_att(ncid, tim_varid, "axis", "T") )

        ! Define the netCDF variables. The dimids array is used to pass the
        ! dimids of the dimensions of the netCDF variables.
        dimids = (/ lon_dimid, lat_dimid, tim_dimid /)
        call check( nf90_def_var(ncid, HUM_NAME, NF90_REAL, dimids, hum_varid) )
      
        ! Assign units attributes to the pressure and temperature netCDF
        ! variables.
        call check( nf90_put_att(ncid, hum_varid, UNITS, HUM_UNITS) )
      
        ! End define mode.
        call check( nf90_enddef(ncid) )
      
        ! Write the coordinate variable data. This will put the latitudes
        ! and longitudes of our data grid into the netCDF file.
        call check( nf90_put_var(ncid, lat_varid, lats) )
        call check( nf90_put_var(ncid, lon_varid, lons) )
        !Do i=1,NTIME
        !    time(i)=i
        !Enddo
        call check( nf90_put_var(ncid, tim_varid, time) )
      
        ! Write the pretend data. This will write our surface pressure and
        ! surface temperature data. The arrays of data are the same size as
        ! the netCDF variables we have defined.
        call check( nf90_put_var(ncid, hum_varid, hum) )
      
        ! Close the file.
        call check( nf90_close(ncid) )
         
      end subroutine write_q10m 

      subroutine write_t10m(FILE_NAME,NLONS,NLATS,NTIME,NDIMS,tem,lons,lats,time,TIM_UNITS,TIM_CAL)
        use netcdf
        implicit none

        ! This is the name of the data file we will create.
        character (len = *),intent(in) :: FILE_NAME
        integer :: ncid, i

        ! We are writing 2D data, a 6 x 12 lat-lon grid. We will need
        ! two
        ! netCDF dimensions.
        integer,intent(in) :: NDIMS
        integer,intent(in) :: NLATS, NLONS, NTIME
        character (len = *), parameter :: LAT_NAME = "lat"
        character (len = *), parameter :: LON_NAME = "lon"
        character (len = *), parameter :: TIM_NAME = "time"
        integer :: lat_dimid, lon_dimid, tim_dimid

        ! In addition to the latitude and longitude dimensions, we will
        ! also
        ! create latitude and longitude netCDF variables which will hold
        ! the
        ! actual latitudes and longitudes. Since they hold data about
        ! the
        ! coordinate system, the netCDF term for these is: "coordinate
        ! variables."
        real*8,intent(in)    :: tem(NLONS,NLATS,NTIME)
        real*8,intent(in)    :: lons(NLONS)
        real*8,intent(in)    :: lats(NLATS)
        real*8, intent(in)  :: time(NTIME)
        character (len = 200),intent(inout) :: TIM_UNITS
        character (len = 200),intent(inout) :: TIM_CAL

        integer :: lat_varid, lon_varid, tim_varid

        ! We will write surface temperature and pressure fields.
        character (len = *), parameter :: TEM_NAME="t10m"
        integer :: tem_varid
        integer :: dimids(NDIMS)

        ! It's good practice for each variable to carry a "units"
        ! attribute.
        character (len = *), parameter :: UNITS = "units"
        character (len = *), parameter :: TEM_UNITS = "Kelvin"
        character (len = *), parameter :: LAT_UNITS = "degrees_north"
        character (len = *), parameter :: LON_UNITS = "degrees_east"

        ! Loop indices
        integer :: lat, lon


        ! Create the file.
        call check( nf90_create(FILE_NAME, nf90_clobber, ncid) )

        ! Define the dimensions.
        call check( nf90_def_dim(ncid, LAT_NAME, NLATS, lat_dimid) )
        call check( nf90_def_dim(ncid, LON_NAME, NLONS, lon_dimid) )
        call check( nf90_def_dim(ncid, TIM_NAME, NF90_UNLIMITED, tim_dimid) )

        ! Define the coordinate variables. They will hold the coordinate
        ! information, that is, the latitudes and longitudes. A varid is
        ! returned for each.
        call check( nf90_def_var(ncid, LAT_NAME, NF90_REAL, lat_dimid, lat_varid) )
        call check( nf90_def_var(ncid, LON_NAME, NF90_REAL, lon_dimid, lon_varid) )
        call check( nf90_def_var(ncid, TIM_NAME, NF90_REAL, tim_dimid, tim_varid) )

        ! Assign units attributes to coordinate var data. This attaches
        ! a
        ! text attribute to each of the coordinate variables, containing
        ! the
        ! units.

        TIM_UNITS=trim(TIM_UNITS)
        TIM_CAL=trim(TIM_CAL)

        call check( nf90_put_att(ncid, lat_varid, UNITS, LAT_UNITS) )
        call check( nf90_put_att(ncid, lat_varid, "standard_name","latitude" ) )
        call check( nf90_put_att(ncid, lat_varid, "long_name", "latitude") )
        call check( nf90_put_att(ncid, lat_varid, "axis", "Y") )

        call check( nf90_put_att(ncid, lon_varid, UNITS, LON_UNITS) )
        call check( nf90_put_att(ncid, lon_varid, "standard_name","longitude" ) )
        call check( nf90_put_att(ncid, lon_varid, "long_name", "longitude") )
        call check( nf90_put_att(ncid, lon_varid, "axis", "X") )

        call check( nf90_put_att(ncid, tim_varid, "standard_name","time") )
        call check( nf90_put_att(ncid, tim_varid, UNITS, TIM_UNITS) )
        call check( nf90_put_att(ncid, tim_varid, "calendar", TIM_CAL) )
        call check( nf90_put_att(ncid, tim_varid, "axis", "T") )

        ! Define the netCDF variables. The dimids array is used to pass
        ! the
        ! dimids of the dimensions of the netCDF variables.
        dimids = (/ lon_dimid, lat_dimid, tim_dimid /)
        call check( nf90_def_var(ncid, TEM_NAME, NF90_REAL, dimids, tem_varid) )

        ! Assign units attributes to the pressure and temperature netCDF
        ! variables.
        call check( nf90_put_att(ncid, tem_varid, UNITS, TEM_UNITS) )

        ! End define mode.
        call check( nf90_enddef(ncid) )

        ! Write the coordinate variable data. This will put the
        ! latitudes
        ! and longitudes of our data grid into the netCDF file.
        call check( nf90_put_var(ncid, lat_varid, lats) )
        call check( nf90_put_var(ncid, lon_varid, lons) )
        call check( nf90_put_var(ncid, tim_varid, time) )

        ! Write the pretend data. This will write our surface pressure
        ! and
        ! surface temperature data. The arrays of data are the same size
        ! as
        ! the netCDF variables we have defined.
        call check( nf90_put_var(ncid, tem_varid, tem) )

        ! Close the file.
        call check( nf90_close(ncid) )

      end subroutine write_t10m

      subroutine check(status)
        use netcdf
          integer, intent ( in) :: status
          
          if(status /= nf90_noerr) then 
            print *, trim(nf90_strerror(status))
            stop "Stopped"
          end if
      end subroutine check  
