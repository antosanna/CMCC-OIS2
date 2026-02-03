subroutine Read_Field1st_time(cfile,cvar1,i,zff,nc,id,unitsname,calname)

Use netcdf

implicit none

integer,intent(in) :: i
integer,intent(inout) :: nc,id
character(len=*)  :: cfile
character(len=*)  :: cvar1
real*8,intent(out)   :: zff(i)
character(len=200),intent(inout) :: unitsname, calname

integer :: stat
if ( nc .eq. -999 .and. id .eq. -999) THEN
  stat = nf90_open(Cfile,NF90_NOWRITE,nc)
  if (stat /= nf90_noerr) call handleerr(stat)
  stat = nf90_inq_varid (nc, cvar1, id)
  if (stat /= nf90_noerr) call handleerr(stat)
endif
if ( nc .ne. -999 .and. id .eq. -999) THEN
  stat = nf90_close(nc)
  if (stat /= nf90_noerr) call handleerr(stat)
  return
endif

stat = nf90_get_var (nc, id, zff,start=(/1/),&
& count=(/i/))
if (stat /= nf90_noerr) call handleerr(stat)

stat = nf90_get_att(nc, id, "units", unitsname)
if (stat /= nf90_noerr) call handleerr(stat)

stat = nf90_get_att(nc, id, "calendar", calname)
if (stat /= nf90_noerr) call handleerr(stat)


End subroutine Read_Field1st_time
