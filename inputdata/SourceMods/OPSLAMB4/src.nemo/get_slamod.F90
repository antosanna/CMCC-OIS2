MODULE get_slamod
!#if   defined key_mpp_mpi

   USE dom_oce        ! ocean space and time domain
   USE oce              ! ocean dynamics and tracers
   USE phycst           ! physical constants
   USE prtctl           ! Print control                    (prt_ctl routine)
   USE iom              ! IOM library
   USE in_out_manager   ! I/O manager
   USE lib_mpp          ! MPP library
   USE timing           ! Timing

   IMPLICIT NONE
   PRIVATE
   
   PUBLIC   get_sla
CONTAINS
   SUBROUTINE get_sla( nnyear ) 
     INTEGER                         ::   ios, n, nlines, io
     CHARACTER(LEN=150)              :: slafwb_dir
     INTEGER, INTENT(IN)             :: nnyear
     CHARACTER(LEN=4)                :: chyear
     CHARACTER(LEN=200)              :: file
     REAL, DIMENSION(:), ALLOCATABLE :: sla_arr
     LOGICAL                         :: THERE
     NAMELIST/nam_fwb/ slafwb_dir

      IF(lwp) THEN
       WRITE(numout,*)
       WRITE(numout,*) 'get_sla : getting the sla daily data FOR YEAR = ',nnyear
       WRITE(numout,*) '~~~~~~~~ '
      ENDIF

      !REWIND( numnam_ref )              ! Namelist namsbc in reference namelist : Surface boundary
      READ  ( numnam_ref, nam_fwb, IOSTAT = ios, ERR = 901)
901   IF( ios /= 0 ) CALL ctl_nam ( ios , 'nam_fwb in reference namelist' )

      !REWIND( numnam_cfg )              ! Namelist namsbc in configuration namelist : Parameters of the run
      READ  ( numnam_cfg, nam_fwb, IOSTAT = ios, ERR = 902 )
902   IF( ios /= 0 ) CALL ctl_nam ( ios , 'nam_fwb in configuration namelist' )
      IF(lwm) WRITE ( numond, nam_fwb )

     IF(lwp) WRITE(numout,*) slafwb_dir
     WRITE(chyear,'(I0.4)') nnyear

     file=trim(slafwb_dir)//"sla_ave_"//trim(chyear)//".dat"

     INQUIRE( FILE=trim(file), EXIST=THERE )             ! DEEP:: Enquiring if sla file file exsis or not

     IF ( THERE ) THEN

        IF(lwp) WRITE(numout,*) "get_sla :: OPENING FILE = ", trim(file)
        OPEN(UNIT=1,FILE=trim(file),FORM="FORMATTED",STATUS="OLD",ACTION="READ")
        nlines=0
        DO
          READ(1,*,iostat=io)                            ! Reading the total number of lines (data) inside file
          IF (io/=0) EXIT
          nlines = nlines + 1
        END DO
        REWIND (1)

        !WRITE(numout,*) "get_sla :: NLINES = ",nlines

        IF(nlines .LE. 366) THEN

          IF( ALLOCATED(sla_arr)) DEALLOCATE(sla_arr)
          IF( ALLOCATED(sla_diff)) DEALLOCATE(sla_diff)
          ALLOCATE(sla_arr(nlines))
          ALLOCATE(sla_diff(nlines))
      
        ELSE
          CALL ctl_stop("get_sla :: E R R O R :: Total number of lines exceeds maximum counts")
        ENDIF

        DO n = 1,nlines
          READ(1,110) sla_arr(n)
        END DO

110  FORMAT(9x,f15.12)

        DO n = 1,nlines-1          
          sla_diff(n)= sla_arr(n+1)-sla_arr(n)      !Calculating the SLA gradient (DAILY)
          sla_diff(n) = sla_diff(n)/100. !from cm to m
        END DO
        sla_diff(nlines)=sla_arr(nlines)-sla_arr(nlines-1) !Replacing the last gradient value with the previous day
        sla_diff(nlines)=sla_diff(nlines)/100.

        CLOSE(1)
    
     ELSE     
         CALL ctl_stop("get_sla :: E R R O R :: Required file for SLA field does not exsit")
     ENDIF
     RETURN
   END SUBROUTINE get_sla
END MODULE get_slamod
