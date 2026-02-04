!  SVN:$Id: ice_restart.F90 607 2013-03-29 15:49:42Z eclare $
!=======================================================================

! Read and write ice model restart files using netCDF or binary
! interfaces.
!DEEP: Taken and modified from ice_restart.F90 in CICE src
! authors David A Bailey, NCAR

      module ice_restart_incr

      use ice_broadcast
      use ice_exit, only: abort_ice
      use ice_kinds_mod
      use netcdf
      use ice_restart_shared, only: &
           restart_ext, restart_dir, restart_file, pointer_file, &
          runid, restart_coszen, use_restart_time, lcdf64, lenstr
      use ice_read_incr
      use ice_fileunits, only: nu_diag, nu_rst_pointer
      use icepack_intfc, only: icepack_query_parameters
      use icepack_intfc, only: icepack_query_tracer_sizes
      use icepack_intfc, only: icepack_query_tracer_flags
      use icepack_intfc, only: icepack_warnings_flush, icepack_warnings_aborted

      implicit none
      private
      public :: read_restart_field_incr

      integer (kind=int_kind) :: ncid

!=======================================================================

      contains

!=======================================================================

! Reads a single increment field (un-categorised)

      subroutine read_restart_field_incr(nu,work,atype,vname, &
                                    diag,field_loc,field_type)

      use ice_domain_size, only: nx_global, ny_global
      use ice_fileunits, only: nu_diag
      use ice_read_incr, only: ice_read_incr_global

      integer (kind=int_kind), intent(in) :: &
           nu            ! unit number (not used for netcdf)

      real (kind=dbl_kind), dimension(nx_global,ny_global), &
           intent(inout) :: &
           work              ! input array (real, 8-byte)

      character (len=4), intent(in) :: &
           atype             ! format for output array
                             ! (real/integer, 4-byte/8-byte)

      logical (kind=log_kind), intent(in) :: &
           diag              ! if true, write diagnostic output

      character (len=9), intent(in)  :: vname

      integer (kind=int_kind), optional, intent(in) :: &
           field_loc, &      ! location of field on staggered grid
           field_type        ! type of field (scalar, vector, angle)

      ! local variables

      integer (kind=int_kind) :: &
        n,     &      ! number of dimensions for variable
        varid, &      ! variable id
        status        ! status variable from netCDF routine

        call ice_read_incr_global(nu, 1, vname, work, diag)

      end subroutine read_restart_field_incr

!=======================================================================

      end module ice_restart_incr

!=======================================================================
