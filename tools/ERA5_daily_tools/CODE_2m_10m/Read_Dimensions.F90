subroutine Read_Dimensions(cfile,nx,ny,nt)

Use netcdf

implicit none

integer, intent(inout) :: nx,ny,nt
character(len=*), intent(in)  :: cfile
integer :: ncid, stat 
integer :: lat_dimid, lon_dimid, time_dimid
character(len=31) :: nlon,nlat,ntime

  stat = nf90_open(Cfile,NF90_NOWRITE,ncid)        !OPENING NC FILE
  if (stat /= nf90_noerr) call handleerr(stat)

  stat = nf90_inq_dimid(ncid,"lon",lon_dimid)    !GETTING VARIABLE NAME FOR LONGITUDE
  if (stat /= nf90_noerr) call handleerr(stat)
  stat = nf90_inq_dimid(ncid,"lat",lat_dimid)    !GETTING VARIABLE NAME FOR LATITUDE
  if (stat /= nf90_noerr) call handleerr(stat)
  stat = nf90_inq_dimid(ncid,"time",time_dimid)  !GETTING VARIABLE NAME FOR TIME
  if (stat /= nf90_noerr) call handleerr(stat)

  stat = nf90_inquire_dimension(ncid, lon_dimid, nlon, nx)         !GETTING X VALUE
  if (stat /= nf90_noerr) call handleerr(stat)
  stat = nf90_inquire_dimension(ncid, lat_dimid, nlat, ny)         !GETTING Y VALUE
  if (stat /= nf90_noerr) call handleerr(stat)
  stat = nf90_inquire_dimension(ncid, time_dimid, ntime, nt)        !GETTING TIME VALUE
  if (stat /= nf90_noerr) call handleerr(stat)

  stat = nf90_close(ncid)
  if (stat /= nf90_noerr) call handleerr(stat)

  return 

End subroutine Read_Dimensions
