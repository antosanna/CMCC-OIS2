c Program to read sea ice thickness and velocity, can be used to read other scaler or vector fields
      PROGRAM CONV
      parameter(nx1=360,ny1=120,nx=nx1,ny=ny1,imt=nx1,jmt=ny1)

      dimension heff(imt,jmt,12)
      dimension uice(imt,jmt),vice(imt,jmt)

      dimension clon(imt,jmt),clat(imt,jmt),kmt(imt,jmt)
      dimension ulat(imt,jmt),ulon(imt,jmt),HTN(imt,jmt),HTE(imt,jmt)
     &,HUS(imt,jmt),HUW(imt,jmt),angle(imt,jmt),dxt(imt,jmt)
     &,dyt(imt,jmt)

      character *80 fopen(5), f1,f2,f3
      character *4 cyear(1900:2100),cyear1(1900:2100)
      character *12 char, caux
      integer SLEN

      f2='heff.H'
      CALL GETARG(1,caux)
      READ(caux,*) iyear

c read lon and lat for scalar fields (like sea ice thickness and concentration)
      open(20,file='grid.dat')
      read(20,'(10f8.2)') ((clon(i,j),i=1,nx1),j=1,ny1)
      read(20,'(10f8.2)') ((clat(i,j),i=1,nx1),j=1,ny1)
      close(20)

c read model grid mask; ocean levels > 0, land <= 0
      open(20,file='io.dat_360_120.output')
      read(20,'(360i2)') kmt
      close(20)

      write(unit=cyear(iyear),fmt='(i4)') iyear
      WRITE(*,*) ' Reading File ', trim(cyear(iyear))
      i=slen(f2)
C    &,access='direct',form='unformatted',recl=nx1*ny1*4
      open(2,file=f2(1:i)//cyear(iyear)
C    &,access='sequential',form='unformatted'
     &,access='direct',form='unformatted',recl=nx1*ny1*4
     &,status='unknown')

      do imon=1,12
      read(2,rec=imon)((heff(i,j,imon),i=1,nx1),j=1,ny1)
      end do
      call writenc(f2(1:i)//cyear(iyear)//'.nc',nx1,ny1,clon,clat,heff)

      close(2)

      stop
      END PROGRAM CONV
      INTEGER FUNCTION slen (string)
C ---
C --- this function computes the length of a character string less
C --- trailing blanks
C --- slen > 0, length of string less trailing blanks
C ---      = 0, character string is blank
C ---
      CHARACTER*(*) string
      CHARACTER*1 cblank
      INTEGER i
      DATA cblank/' '/
C ---
      DO 50 i = LEN(string), 1, -1
         IF (string(i:i) .NE. ' ')  GO TO 100
50    CONTINUE
      i = 0
100   CONTINUE
      slen = i
      RETURN
      END FUNCTION slen
