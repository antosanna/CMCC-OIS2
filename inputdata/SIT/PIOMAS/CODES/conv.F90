! Program to read sea ice thickness and velocity, can be used to read other scaler or vector fields
      PROGRAM CONV
      IMPLICIT NONE
      INTEGER, PARAMETER :: nx1=360,ny1=120,nx=nx1,ny=ny1,imt=nx1,jmt=ny1   
      REAL(4) :: heff(imt,jmt,12),clon(imt,jmt),clat(imt,jmt),kmt(imt,jmt)

      character (80) :: fopen(5), f1,f2,f3
      character (4)  :: cyear(1900:2100),cyear1(1900:2100)
      character (12) :: char, caux
      integer :: i,j,iyear,imon,maxm

      f2='heff.H'
!      f2='area.H'
      CALL GETARG(1,caux)
      READ(caux,*) iyear
      IF( IARGC() .eq. 2 ) THEN
         CALL GETARG(2,caux)
         READ(caux,*) maxm
      ELSE
         maxm = 12
      ENDIF

! read lon and lat for scalar fields (like sea ice thickness and concentration)
      open(20,file='grid.dat')
      read(20,'(10f8.2)') ((clon(i,j),i=1,nx1),j=1,ny1)
      read(20,'(10f8.2)') ((clat(i,j),i=1,nx1),j=1,ny1)
      close(20)

! read model grid mask; ocean levels > 0, land <= 0
      open(20,file='io.dat_360_120.output')
      do j=1,ny
      read(20,'(360i2)') kmt(:,j)
      enddo
      close(20)
      WRITE(*,*) ' CK : ',MINVAL(kmt),MAXVAL(kmt)

      write(unit=cyear(iyear),fmt='(i4)') iyear
      WRITE(*,*) ' Reading File ', trim(cyear(iyear))
!    &,access='direct',form='unformatted',recl=nx1*ny1*4
!    &,access='sequential',form='unformatted'
      open(2,file=trim(f2)//cyear(iyear) &
!    &,access='sequential',form='unformatted' &
    &,access='direct',form='unformatted',recl=nx1*ny1 &
     &,status='unknown')

      do imon=1,maxm
      write(*,*) 'Month: ',imon
      !read(2,rec=imon)((heff(i,j,imon),i=1,nx1),j=1,ny1)
      !!!read(2)((heff(i,j,imon),i=1,nx1),j=1,ny1)
!      read(2) heff(:,:,imon)
      read(2,rec=imon) heff(:,:,imon)
      !where (kmt<=0) heff(:,:,imon) = -9.
      end do
      close(2)
      call writenc(trim(f2)//cyear(iyear)//'.nc',nx1,ny1,maxm,clon,clat,heff)

      stop
      END PROGRAM CONV
