!  SVN:$Id: ice_read_write.F90 861 2014-10-21 16:44:30Z tcraig $
!=======================================================================

! Routines for opening, reading and writing external files
!
! author: Tony Craig, NCAR
!
! 2004: Block structure added by William Lipscomb, LANL
! 2006: Converted to free source form (F90) by Elizabeth Hunke
! 2007: netcdf versions added by Alison McLaren & Ann Keen, Met Office

      module ice_read_incr

      use ice_kinds_mod
      use ice_constants, only: c0, spval_dbl, &
          field_loc_noupdate, field_type_noupdate
      use ice_communicate, only: my_task, master_task
      use ice_broadcast, only: broadcast_scalar
      use ice_domain, only: distrb_info,orca_halogrid
      use ice_domain_size, only: max_blocks, nx_global, ny_global, ncat
      use ice_blocks, only: nx_block, ny_block, nghost
      use ice_exit, only: abort_ice
!      use ice_read_write
      use ice_fileunits, only: nu_diag

      use netcdf

      implicit none

      public :: ice_read_incr_global

!=======================================================================

      contains

!=======================================================================

! Read a netCDF file and scatter to processors.
! If the optional variables field_loc and field_type are present,
! the ghost cells are filled using values from the global array.
! This prevents them from being filled with zeroes in land cells
! (subroutine ice_HaloUpdate need not be called).
!
! Adapted by Alison McLaren, Met Office from ice_read

!=======================================================================

! Read a netcdf file.
! Just like ice_read_nc except that it returns a global array.
! work_g is a real array
!
! Adapted by William Lipscomb, LANL, from ice_read
! Adapted by Ann Keen, Met Office, to read from a netcdf file

      subroutine ice_read_incr_global (fid,  nrec, varname, work_g, diag)

      use ice_calendar, only: dt

      integer (kind=int_kind), intent(in) :: &
           fid           , & ! file id
           nrec              ! record number

      character (len=9), intent(in) :: &
           varname           ! field name in netcdf file

      real (kind=dbl_kind), dimension(nx_global,ny_global), &
           intent(out) :: &
           work_g            ! output array (real, 8-byte)

      logical (kind=log_kind) :: &
           diag              ! if true, write diagnostic output

      ! local variables

!#ifdef USE_NETCDF
! netCDF file diagnostics:
      integer (kind=int_kind) :: &
         varid,           & ! netcdf id for field
         status,          & ! status output from netcdf routines
         ndim, nvar,      & ! sizes of netcdf file
         id,              & ! dimension index
         dimlen             ! size of dimension

      real (kind=dbl_kind) :: &
         amin, amax, asum   ! min, max values and sum of input array

      character (char_len) :: &
         dimname            ! dimension name
!
!#ifdef ORCA_GRID
      real (kind=dbl_kind), dimension(:,:), allocatable :: &
         work_g3
     if (orca_halogrid) then
      if (my_task == master_task) then
          allocate(work_g3(nx_global+2,ny_global+1))
      else
          allocate(work_g3(1,1))   ! to save memory
      endif

      work_g3(:,:) = c0
      endif
!#endif
      work_g(:,:) = c0

      if (my_task == master_task) then

        !-------------------------------------------------------------
        ! Find out ID of required variable
        !-------------------------------------------------------------

         status = nf90_inq_varid(fid, trim(varname), varid)

         if (status /= nf90_noerr) then
           call abort_ice ( &
            'ice_read_global_nc: Cannot find variable '//trim(varname) )
         endif

       !--------------------------------------------------------------
       ! Read global array
       !--------------------------------------------------------------

        if (orca_halogrid) then
               status = nf90_get_var( fid, varid, work_g3, &
               start=(/1,1,nrec/), &
               count=(/nx_global+2,ny_global+1,1/) )
               work_g=work_g3(2:nx_global+1,1:ny_global)
        else
               status = nf90_get_var( fid, varid, work_g, &
               start=(/1,1,nrec/), &
               count=(/nx_global,ny_global,1/) )
!         work_g = work_g/dt    !DEEP:: IAU dividing total increment into model timesteps
        endif
      endif                     ! my_task = master_task

    !-------------------------------------------------------------------
    ! optional diagnostics
    !-------------------------------------------------------------------

      if (my_task == master_task .and. diag) then
!          write(nu_diag,*) &
!            'ice_read_global_nc, fid= ',fid, ', nrec = ',nrec, &
!            ', varname = ',trim(varname)
!          status = nf90_inquire(fid, nDimensions=ndim, nVariables=nvar)
!          write(nu_diag,*) 'ndim= ',ndim,', nvar= ',nvar
!          do id=1,ndim
!            status =
!            nf90_inquire_dimension(fid,id,name=dimname,len=dimlen)
!            write(nu_diag,*) 'Dim name = ',trim(dimname),', size =
!            ',dimlen
!         enddo
         amin = minval(work_g)
         amax = maxval(work_g, mask = work_g /= spval_dbl)
         asum = sum   (work_g, mask = work_g /= spval_dbl)
         write(nu_diag,*) 'min, max, sum = ', amin, amax, asum
      endif

  if (orca_halogrid) deallocate(work_g3)

!#else
!      work_g = c0 ! to satisfy intent(out) attribute
!#endif
      end subroutine ice_read_incr_global

      end module ice_read_incr

!=======================================================================
