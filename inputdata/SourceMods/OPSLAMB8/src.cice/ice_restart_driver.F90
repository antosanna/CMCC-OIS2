!=======================================================================

! Read and write ice model restart files
!
! authors Elizabeth C. Hunke, LANL
!         William H. Lipscomb LANL
!         David Bailey, NCAR
!
! 2004-05: Block structure added by William Lipscomb
!          Restart module separated from history module
! 2006 ECH: Accepted some CESM code into mainstream CICE
!           Converted to free source form (F90)
! 2008 ECH: Rearranged order in which internal stresses are written and read
! 2010 ECH: Changed eice, esno to qice, qsno
! 2012 ECH: Added routines for reading/writing extended grid
! 2013 DAB: Added generic interfaces for writing restart fields.

      module ice_restart_driver

        use ice_kinds_mod
        use ice_arrays_column, only: oceanmixed_ice
        use ice_constants, only: c0, c1, p5, &
            field_loc_center, field_loc_NEcorner, &
            field_type_scalar, field_type_vector
        use ice_restart_shared, only: &
            restart_coszen, restart_dir, pointer_file, &
            runid, use_restart_time,      &
            ln_asmaice, ln_asmboth, ln_asmiau, lenstr,nday_asmiau
        use ice_restart
        use ice_restart_incr !DEEP: Added for reading increment field in netcdf format
        use ice_exit, only: abort_ice
        use ice_fileunits, only: nu_diag, nu_rst_pointer, nu_restart,nu_dump
        use icepack_intfc, only: icepack_warnings_flush, icepack_warnings_aborted
        use icepack_intfc, only: icepack_aggregate,aggregate_only
        use icepack_intfc, only: icepack_query_tracer_indices,icepack_query_tracer_sizes,icepack_query_parameters


      implicit none
      private
      public :: dumpfile, restartfile, restartfile_v4,ice_da_state_update

!=======================================================================

      contains

!=======================================================================

!=======================================================================
!---! these subroutines write/read Fortran unformatted data files ..
!=======================================================================

! Dumps all values needed for a restart
! author Elizabeth C. Hunke, LANL

      subroutine dumpfile(filename_spec)

      use ice_blocks, only: nx_block, ny_block
      use ice_domain, only: nblocks
      use ice_domain_size, only: nilyr, nslyr, ncat, max_blocks
      use ice_flux, only: scale_factor, swvdr, swvdf, swidr, swidf, &
          strocnxT, strocnyT, sst, frzmlt, iceumask, &
          stressp_1, stressp_2, stressp_3, stressp_4, &
          stressm_1, stressm_2, stressm_3, stressm_4, &
          stress12_1, stress12_2, stress12_3, stress12_4
      use ice_flux, only: coszen
      use ice_state, only: aicen, vicen, vsnon, trcrn, uvel, vvel

      character(len=char_len_long), intent(in), optional :: filename_spec

      ! local variables

      integer (kind=int_kind) :: &
          i, j, k, iblk, &     ! counting indices
          nt_Tsfc, nt_sice, nt_qice, nt_qsno

      logical (kind=log_kind) :: diag

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_blocks) :: &
         work1

      character (len=3) :: nchar

      character(len=*), parameter :: subname = '(dumpfile)'

      call icepack_query_tracer_indices(nt_Tsfc_out=nt_Tsfc, nt_sice_out=nt_sice, &
           nt_qice_out=nt_qice, nt_qsno_out=nt_qsno)
      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
         file=__FILE__, line=__LINE__)

      if (present(filename_spec)) then
         call init_restart_write(filename_spec)
      else
         call init_restart_write
      endif

      diag = .true.

      !-----------------------------------------------------------------
      ! state variables
      ! Tsfc is the only tracer written to binary files.  All other
      ! tracers are written to their own dump/restart binary files.
      !-----------------------------------------------------------------

      call write_restart_field(nu_dump,0,aicen(:,:,:,:),'ruf8','aicen',ncat,diag)
      call write_restart_field(nu_dump,0,vicen(:,:,:,:),'ruf8','vicen',ncat,diag)
      call write_restart_field(nu_dump,0,vsnon(:,:,:,:),'ruf8','vsnon',ncat,diag)
      call write_restart_field(nu_dump,0,trcrn(:,:,nt_Tsfc,:,:),'ruf8','Tsfcn',ncat,diag)

      do k=1,nilyr
         write(nchar,'(i3.3)') k
         call write_restart_field(nu_dump,0,trcrn(:,:,nt_sice+k-1,:,:),'ruf8', &
                                 'sice'//trim(nchar),ncat,diag)
      enddo

      do k=1,nilyr
         write(nchar,'(i3.3)') k
         call write_restart_field(nu_dump,0,trcrn(:,:,nt_qice+k-1,:,:),'ruf8', &
                                 'qice'//trim(nchar),ncat,diag)
      enddo

      do k=1,nslyr
         write(nchar,'(i3.3)') k
         call write_restart_field(nu_dump,0,trcrn(:,:,nt_qsno+k-1,:,:),'ruf8', &
                                 'qsno'//trim(nchar),ncat,diag)
      enddo

      !-----------------------------------------------------------------
      ! velocity
      !-----------------------------------------------------------------
      call write_restart_field(nu_dump,0,uvel,'ruf8','uvel',1,diag)
      call write_restart_field(nu_dump,0,vvel,'ruf8','vvel',1,diag)

      !-----------------------------------------------------------------
      ! radiation fields
      !-----------------------------------------------------------------

      if (restart_coszen) call write_restart_field(nu_dump,0,coszen,'ruf8','coszen',1,diag)

      call write_restart_field(nu_dump,0,scale_factor,'ruf8','scale_factor',1,diag)

      call write_restart_field(nu_dump,0,swvdr,'ruf8','swvdr',1,diag)
      call write_restart_field(nu_dump,0,swvdf,'ruf8','swvdf',1,diag)
      call write_restart_field(nu_dump,0,swidr,'ruf8','swidr',1,diag)
      call write_restart_field(nu_dump,0,swidf,'ruf8','swidf',1,diag)

      !-----------------------------------------------------------------
      ! ocean stress (for bottom heat flux in thermo)
      !-----------------------------------------------------------------
      call write_restart_field(nu_dump,0,strocnxT,'ruf8','strocnxT',1,diag)
      call write_restart_field(nu_dump,0,strocnyT,'ruf8','strocnyT',1,diag)

      !-----------------------------------------------------------------
      ! internal stress
      !-----------------------------------------------------------------
      call write_restart_field(nu_dump,0,stressp_1,'ruf8','stressp_1',1,diag)
      call write_restart_field(nu_dump,0,stressp_3,'ruf8','stressp_3',1,diag)
      call write_restart_field(nu_dump,0,stressp_2,'ruf8','stressp_2',1,diag)
      call write_restart_field(nu_dump,0,stressp_4,'ruf8','stressp_4',1,diag)

      call write_restart_field(nu_dump,0,stressm_1,'ruf8','stressm_1',1,diag)
      call write_restart_field(nu_dump,0,stressm_3,'ruf8','stressm_3',1,diag)
      call write_restart_field(nu_dump,0,stressm_2,'ruf8','stressm_2',1,diag)
      call write_restart_field(nu_dump,0,stressm_4,'ruf8','stressm_4',1,diag)

      call write_restart_field(nu_dump,0,stress12_1,'ruf8','stress12_1',1,diag)
      call write_restart_field(nu_dump,0,stress12_3,'ruf8','stress12_3',1,diag)
      call write_restart_field(nu_dump,0,stress12_2,'ruf8','stress12_2',1,diag)
      call write_restart_field(nu_dump,0,stress12_4,'ruf8','stress12_4',1,diag)

      !-----------------------------------------------------------------
      ! ice mask for dynamics
      !-----------------------------------------------------------------

      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks
         do j = 1, ny_block
         do i = 1, nx_block
            work1(i,j,iblk) = c0
            if (iceumask(i,j,iblk)) work1(i,j,iblk) = c1
         enddo
         enddo
      enddo
      !$OMP END PARALLEL DO
      call write_restart_field(nu_dump,0,work1,'ruf8','iceumask',1,diag)

      ! for mixed layer model
      if (oceanmixed_ice) then
         call write_restart_field(nu_dump,0,sst,'ruf8','sst',1,diag)
         call write_restart_field(nu_dump,0,frzmlt,'ruf8','frzmlt',1,diag)
      endif

      end subroutine dumpfile

!=======================================================================

! Restarts from a dump
! author Elizabeth C. Hunke, LANL

      subroutine restartfile (ice_ic)

      use ice_boundary, only: ice_HaloUpdate_stress
      use ice_blocks, only: nghost, nx_block, ny_block
      use ice_calendar, only: istep0, npt, calendar
      use ice_communicate, only: my_task, master_task
      use ice_domain, only: nblocks, halo_info
      use ice_domain_size, only: nilyr, nslyr, ncat, &
          max_blocks
      use ice_flux, only: scale_factor, swvdr, swvdf, swidr, swidf, &
          strocnxT, strocnyT, sst, frzmlt, iceumask, &
          stressp_1, stressp_2, stressp_3, stressp_4, &
          stressm_1, stressm_2, stressm_3, stressm_4, &
          stress12_1, stress12_2, stress12_3, stress12_4
      use ice_flux, only: coszen
      use ice_grid, only: tmask, grid_type
      use ice_state, only: trcr_depend, aice, vice, vsno, trcr, &
          aice0, aicen, vicen, vsnon, trcrn, aice_init, uvel, vvel, &
          trcr_base, nt_strata, n_trcr_strata

      character (*), optional :: ice_ic

      ! local variables

      integer (kind=int_kind) :: &
         i, j, k, iblk, &     ! counting indices
         ntrcr, &             ! number of tracers
         nt_Tsfc, nt_sice, nt_qice, nt_qsno

      logical (kind=log_kind) :: &
         diag

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_blocks) :: &
         work1

      character (len=3) :: nchar

      character(len=*), parameter :: subname = '(restartfile)'

      call icepack_query_tracer_sizes(ntrcr_out=ntrcr)
      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
          file=__FILE__, line=__LINE__)

      call icepack_query_tracer_indices(nt_Tsfc_out=nt_Tsfc, nt_sice_out=nt_sice, &
           nt_qice_out=nt_qice, nt_qsno_out=nt_qsno)
      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
         file=__FILE__, line=__LINE__)

      call init_restart_read(ice_ic)
      call calendar()

      diag = .true.

      !-----------------------------------------------------------------
      ! state variables
      ! Tsfc is the only tracer read in this file.  All other
      ! tracers are in their own dump/restart files.
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) ' min/max area, vol ice, vol snow, Tsfc'

      call read_restart_field(nu_restart,0,aicen,'ruf8', &
              'aicen',ncat,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,vicen,'ruf8', &
              'vicen',ncat,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,vsnon,'ruf8', &
              'vsnon',ncat,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,trcrn(:,:,nt_Tsfc,:,:),'ruf8', &
              'Tsfcn',ncat,diag,field_loc_center, field_type_scalar)

      if (my_task == master_task) &
         write(nu_diag,*) 'min/max sice for each layer'
      do k=1,nilyr
         write(nchar,'(i3.3)') k
         call read_restart_field(nu_restart,0,trcrn(:,:,nt_sice+k-1,:,:),'ruf8', &
              'sice'//trim(nchar),ncat,diag,field_loc_center,field_type_scalar)
      enddo

      if (my_task == master_task) &
         write(nu_diag,*) 'min/max qice for each layer'
      do k=1,nilyr
         write(nchar,'(i3.3)') k
         call read_restart_field(nu_restart,0,trcrn(:,:,nt_qice+k-1,:,:),'ruf8', &
              'qice'//trim(nchar),ncat,diag,field_loc_center,field_type_scalar)
      enddo

      if (my_task == master_task) &
         write(nu_diag,*) 'min/max qsno for each layer'
      do k=1,nslyr
         write(nchar,'(i3.3)') k
         call read_restart_field(nu_restart,0,trcrn(:,:,nt_qsno+k-1,:,:),'ruf8', &
              'qsno'//trim(nchar),ncat,diag,field_loc_center,field_type_scalar)
      enddo

      !-----------------------------------------------------------------
      ! velocity
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'min/max velocity components'

      call read_restart_field(nu_restart,0,uvel,'ruf8', &
           'uvel',1,diag,field_loc_NEcorner, field_type_vector)
      call read_restart_field(nu_restart,0,vvel,'ruf8', &
           'vvel',1,diag,field_loc_NEcorner, field_type_vector)

      !-----------------------------------------------------------------
      ! radiation fields
      !-----------------------------------------------------------------

      if (my_task == master_task) &
         write(nu_diag,*) 'radiation fields'

      if (restart_coszen) call read_restart_field(nu_restart,0,coszen,'ruf8', &
           'coszen',1,diag)
      call read_restart_field(nu_restart,0,scale_factor,'ruf8', &
           'scale_factor',1,diag, field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,swvdr,'ruf8', &
           'swvdr',1,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,swvdf,'ruf8', &
           'swvdf',1,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,swidr,'ruf8', &
           'swidr',1,diag,field_loc_center, field_type_scalar)
      call read_restart_field(nu_restart,0,swidf,'ruf8', &
           'swidf',1,diag,field_loc_center, field_type_scalar)

      !-----------------------------------------------------------------
      ! ocean stress
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'min/max ocean stress components'

      call read_restart_field(nu_restart,0,strocnxT,'ruf8', &
           'strocnxT',1,diag,field_loc_center, field_type_vector)
      call read_restart_field(nu_restart,0,strocnyT,'ruf8', &
           'strocnyT',1,diag,field_loc_center, field_type_vector)

      !-----------------------------------------------------------------
      ! internal stress
      ! The stress tensor must be read and scattered in pairs in order
      ! to properly match corner values across a tripole grid cut.
      !-----------------------------------------------------------------
      if (my_task == master_task) write(nu_diag,*) &
           'internal stress components'

      call read_restart_field(nu_restart,0,stressp_1,'ruf8', &
           'stressp_1',1,diag,field_loc_center,field_type_scalar) ! stressp_1
      call read_restart_field(nu_restart,0,stressp_3,'ruf8', &
           'stressp_3',1,diag,field_loc_center,field_type_scalar) ! stressp_3
      call read_restart_field(nu_restart,0,stressp_2,'ruf8', &
           'stressp_2',1,diag,field_loc_center,field_type_scalar) ! stressp_2
      call read_restart_field(nu_restart,0,stressp_4,'ruf8', &
           'stressp_4',1,diag,field_loc_center,field_type_scalar) ! stressp_4

      call read_restart_field(nu_restart,0,stressm_1,'ruf8', &
           'stressm_1',1,diag,field_loc_center,field_type_scalar) ! stressm_1
      call read_restart_field(nu_restart,0,stressm_3,'ruf8', &
           'stressm_3',1,diag,field_loc_center,field_type_scalar) ! stressm_3
      call read_restart_field(nu_restart,0,stressm_2,'ruf8', &
           'stressm_2',1,diag,field_loc_center,field_type_scalar) ! stressm_2
      call read_restart_field(nu_restart,0,stressm_4,'ruf8', &
           'stressm_4',1,diag,field_loc_center,field_type_scalar) ! stressm_4

      call read_restart_field(nu_restart,0,stress12_1,'ruf8', &
           'stress12_1',1,diag,field_loc_center,field_type_scalar) ! stress12_1
      call read_restart_field(nu_restart,0,stress12_3,'ruf8', &
           'stress12_3',1,diag,field_loc_center,field_type_scalar) ! stress12_1

      call read_restart_field(nu_restart,0,stress12_2,'ruf8', &
           'stress12_2',1,diag,field_loc_center,field_type_scalar) ! stress12_2
      call read_restart_field(nu_restart,0,stress12_4,'ruf8', &
           'stress12_4',1,diag,field_loc_center,field_type_scalar) ! stress12_4

      if (trim(grid_type) == 'tripole') then
         call ice_HaloUpdate_stress(stressp_1, stressp_3, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressp_3, stressp_1, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressp_2, stressp_4, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressp_4, stressp_2, halo_info, &
                                    field_loc_center,  field_type_scalar)

         call ice_HaloUpdate_stress(stressm_1, stressm_3, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressm_3, stressm_1, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressm_2, stressm_4, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stressm_4, stressm_2, halo_info, &
                                    field_loc_center,  field_type_scalar)

         call ice_HaloUpdate_stress(stress12_1, stress12_3, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stress12_3, stress12_1, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stress12_2, stress12_4, halo_info, &
                                    field_loc_center,  field_type_scalar)
         call ice_HaloUpdate_stress(stress12_4, stress12_2, halo_info, &
                                    field_loc_center,  field_type_scalar)
      endif

      !-----------------------------------------------------------------
      ! ice mask for dynamics
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'ice mask for dynamics'

      call read_restart_field(nu_restart,0,work1,'ruf8', &
           'iceumask',1,diag,field_loc_center, field_type_scalar)

      iceumask(:,:,:) = .false.
      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks
         do j = 1, ny_block
         do i = 1, nx_block
            if (work1(i,j,iblk) > p5) iceumask(i,j,iblk) = .true.
         enddo
         enddo
      enddo
      !$OMP END PARALLEL DO

      ! for mixed layer model
      if (oceanmixed_ice) then

         if (my_task == master_task) &
              write(nu_diag,*) 'min/max sst, frzmlt'

         call read_restart_field(nu_restart,0,sst,'ruf8', &
              'sst',1,diag,field_loc_center, field_type_scalar)
         call read_restart_field(nu_restart,0,frzmlt,'ruf8', &
              'frzmlt',1,diag,field_loc_center, field_type_scalar)
      endif

      !-----------------------------------------------------------------
      ! Ensure unused stress values in west and south ghost cells are 0
      !-----------------------------------------------------------------
      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks
         do j = 1, nghost
         do i = 1, nx_block
            stressp_1 (i,j,iblk) = c0
            stressp_2 (i,j,iblk) = c0
            stressp_3 (i,j,iblk) = c0
            stressp_4 (i,j,iblk) = c0
            stressm_1 (i,j,iblk) = c0
            stressm_2 (i,j,iblk) = c0
            stressm_3 (i,j,iblk) = c0
            stressm_4 (i,j,iblk) = c0
            stress12_1(i,j,iblk) = c0
            stress12_2(i,j,iblk) = c0
            stress12_3(i,j,iblk) = c0
            stress12_4(i,j,iblk) = c0
         enddo
         enddo
         do j = 1, ny_block
         do i = 1, nghost
            stressp_1 (i,j,iblk) = c0
            stressp_2 (i,j,iblk) = c0
            stressp_3 (i,j,iblk) = c0
            stressp_4 (i,j,iblk) = c0
            stressm_1 (i,j,iblk) = c0
            stressm_2 (i,j,iblk) = c0
            stressm_3 (i,j,iblk) = c0
            stressm_4 (i,j,iblk) = c0
            stress12_1(i,j,iblk) = c0
            stress12_2(i,j,iblk) = c0
            stress12_3(i,j,iblk) = c0
            stress12_4(i,j,iblk) = c0
         enddo
         enddo
      enddo
      !$OMP END PARALLEL DO

      !-----------------------------------------------------------------
      ! Ensure ice is binned in correct categories
      ! (should not be necessary unless restarting from a run with
      !  different category boundaries).
      !
      ! If called, this subroutine does not give exact restart.
      !-----------------------------------------------------------------
!!!      call cleanup_itd

      !-----------------------------------------------------------------
      ! compute aggregate ice state and open water area:
      !-----------------------------------------------------------------

      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks

      do j = 1, ny_block
      do i = 1, nx_block
         if (tmask(i,j,iblk)) &
            call icepack_aggregate(ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   trcrn = trcrn(i,j,:,:,iblk),   &
                                   vicen = vicen(i,j,:,iblk),     &
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   trcr  = trcr (i,j,:,iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   vsno  = vsno (i,j,  iblk),     &
                                   aice0 = aice0(i,j,  iblk),     &
                                   ntrcr = ntrcr,                 &
                                   trcr_depend   = trcr_depend(:), &
                                   trcr_base     = trcr_base(:,:),   &
                                   n_trcr_strata = n_trcr_strata(:), &
                                   nt_strata     = nt_strata(:,:))
         aice_init(i,j,iblk) = aice(i,j,iblk)
      enddo
      enddo

      enddo
      !$OMP END PARALLEL DO

      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
         file=__FILE__, line=__LINE__)

      ! if runid is bering then need to correct npt for istep0
      if (trim(runid) == 'bering') then
         npt = npt - istep0
      endif

      end subroutine restartfile

!=======================================================================

! Restarts from a CICE v4.1 (binary) dump
! author Elizabeth C. Hunke, LANL

      subroutine restartfile_v4 (ice_ic)

      use ice_broadcast, only: broadcast_scalar
      use ice_blocks, only: nghost, nx_block, ny_block
      use ice_calendar, only: istep0, istep1, timesecs, calendar, npt, &
          set_date_from_timesecs
      use ice_communicate, only: my_task, master_task
      use ice_domain, only: nblocks, distrb_info
      use ice_domain_size, only: nilyr, nslyr, ncat, nx_global, ny_global, &
          max_blocks
      use ice_flux, only: scale_factor, swvdr, swvdf, swidr, swidf, &
          strocnxT, strocnyT, sst, frzmlt, iceumask, &
          stressp_1, stressp_2, stressp_3, stressp_4, &
          stressm_1, stressm_2, stressm_3, stressm_4, &
          stress12_1, stress12_2, stress12_3, stress12_4
      use ice_gather_scatter, only: scatter_global_stress
      use ice_grid, only: tmask
      use ice_read_write, only: ice_open, ice_read, ice_read_global
      use ice_state, only: trcr_depend, aice, vice, vsno, trcr, &
          aice0, aicen, vicen, vsnon, trcrn, aice_init, uvel, vvel, &
          trcr_base, nt_strata, n_trcr_strata

      character (*), optional :: ice_ic

      ! local variables

      integer (kind=int_kind) :: &
         i, j, k, n, iblk, &     ! counting indices
         ntrcr, &                ! number of tracers
         nt_Tsfc, nt_sice, nt_qice, nt_qsno, &
         iignore                 ! dummy variable

      real (kind=real_kind) :: &
         rignore                 ! dummy variable

      character(len=char_len_long) :: &
         filename, filename0

      logical (kind=log_kind) :: &
         diag

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_blocks) :: &
         work1

      real (kind=dbl_kind), dimension(:,:), allocatable :: &
         work_g1, work_g2

      real (kind=dbl_kind) :: &
         time_forc      ! historic, now local

      character(len=*), parameter :: subname = '(restartfile_v4)'

      call icepack_query_tracer_sizes(ntrcr_out=ntrcr)
      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
          file=__FILE__, line=__LINE__)

      call icepack_query_tracer_indices(nt_Tsfc_out=nt_Tsfc, nt_sice_out=nt_sice, &
           nt_qice_out=nt_qice, nt_qsno_out=nt_qsno)
      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
         file=__FILE__, line=__LINE__)

      if (present(ice_ic)) then
         filename = ice_ic
      elseif (my_task == master_task) then
         open(nu_rst_pointer,file=pointer_file)
         read(nu_rst_pointer,'(a)') filename0
         filename = trim(filename0)
         close(nu_rst_pointer)
         write(nu_diag,*) 'Read ',pointer_file(1:lenstr(pointer_file))
      endif

      call ice_open(nu_restart,filename,0)

      if (my_task == master_task) &
         write(nu_diag,*) 'Using restart dump=', trim(filename)

      if (use_restart_time) then

         if (my_task == master_task) then
            read (nu_restart) istep0,timesecs,time_forc
            write(nu_diag,*) 'Restart read at istep=',istep0,timesecs
         endif
         call broadcast_scalar(istep0,master_task)
         istep1 = istep0
         call broadcast_scalar(timesecs,master_task)
!         call broadcast_scalar(time_forc,master_task)
         call set_date_from_timesecs(timesecs)
         call calendar()

      else

         if (my_task == master_task) &
            read (nu_restart) iignore,rignore,rignore

      endif

      diag = .true.     ! write min/max diagnostics for field

      !-----------------------------------------------------------------
      ! state variables
      ! Tsfc is the only tracer read in this file.  All other
      ! tracers are in their own dump/restart files.
      !-----------------------------------------------------------------
      do n=1,ncat
         if (my_task == master_task) &
              write(nu_diag,*) 'cat ',n, &
                               ' min/max area, vol ice, vol snow, Tsfc'

         call ice_read(nu_restart,0,aicen(:,:,n,:),'ruf8',diag, &
                       field_loc_center, field_type_scalar)
         call ice_read(nu_restart,0,vicen(:,:,n,:),'ruf8',diag, &
                       field_loc_center, field_type_scalar)
         call ice_read(nu_restart,0,vsnon(:,:,n,:),'ruf8',diag, &
                       field_loc_center, field_type_scalar)
         call ice_read(nu_restart,0,trcrn(:,:,nt_Tsfc,n,:),'ruf8',diag, &
                       field_loc_center, field_type_scalar)

         if (my_task == master_task) &
              write(nu_diag,*) 'cat ',n, 'min/max sice for each layer'
         do k=1,nilyr
            call ice_read(nu_restart,0,trcrn(:,:,nt_sice+k-1,n,:),'ruf8',diag, &
                          field_loc_center, field_type_scalar)
         enddo

         if (my_task == master_task) &
              write(nu_diag,*) 'cat ',n, 'min/max qice for each layer'
         do k=1,nilyr
            call ice_read(nu_restart,0,trcrn(:,:,nt_qice+k-1,n,:),'ruf8',diag, &
                          field_loc_center, field_type_scalar)
         enddo

         if (my_task == master_task) &
              write(nu_diag,*) 'cat ',n, 'min/max qsno for each layer'
         do k=1,nslyr
            call ice_read(nu_restart,0,trcrn(:,:,nt_qsno+k-1,n,:),'ruf8',diag, &
                          field_loc_center, field_type_scalar)
         enddo
      enddo ! ncat

      !-----------------------------------------------------------------
      ! velocity
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'min/max velocity components'

      call ice_read(nu_restart,0,uvel,'ruf8',diag, &
                       field_loc_NEcorner, field_type_vector)
      call ice_read(nu_restart,0,vvel,'ruf8',diag, &
                       field_loc_NEcorner, field_type_vector)

      !-----------------------------------------------------------------
      ! radiation fields
      !-----------------------------------------------------------------

      if (my_task == master_task) &
         write(nu_diag,*) 'radiation fields'

      call ice_read(nu_restart,0,scale_factor,'ruf8',diag, &
                    field_loc_center, field_type_scalar)
      call ice_read(nu_restart,0,swvdr,'ruf8',diag, &
                    field_loc_center, field_type_scalar)
      call ice_read(nu_restart,0,swvdf,'ruf8',diag, &
                    field_loc_center, field_type_scalar)
      call ice_read(nu_restart,0,swidr,'ruf8',diag, &
                    field_loc_center, field_type_scalar)
      call ice_read(nu_restart,0,swidf,'ruf8',diag, &
                    field_loc_center, field_type_scalar)

      !-----------------------------------------------------------------
      ! ocean stress
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'min/max ocean stress components'

      call ice_read(nu_restart,0,strocnxT,'ruf8',diag, &
                       field_loc_center, field_type_vector)
      call ice_read(nu_restart,0,strocnyT,'ruf8',diag, &
                       field_loc_center, field_type_vector)

      !-----------------------------------------------------------------
      ! internal stress
      ! The stress tensor must be read and scattered in pairs in order
      ! to properly match corner values across a tripole grid cut.
      !-----------------------------------------------------------------
      if (my_task == master_task) write(nu_diag,*) &
           'internal stress components'

      allocate (work_g1(nx_global,ny_global), &
                work_g2(nx_global,ny_global))

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stressp_1
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stressp_3
      call scatter_global_stress(stressp_1, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stressp_3, work_g2, work_g1, &
                                 master_task, distrb_info)

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stressp_2
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stressp_4
      call scatter_global_stress(stressp_2, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stressp_4, work_g2, work_g1, &
                                 master_task, distrb_info)

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stressm_1
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stressm_3
      call scatter_global_stress(stressm_1, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stressm_3, work_g2, work_g1, &
                                 master_task, distrb_info)

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stressm_2
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stressm_4
      call scatter_global_stress(stressm_2, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stressm_4, work_g2, work_g1, &
                                 master_task, distrb_info)

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stress12_1
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stress12_3
      call scatter_global_stress(stress12_1, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stress12_3, work_g2, work_g1, &
                                 master_task, distrb_info)

      call ice_read_global(nu_restart,0,work_g1,'ruf8',diag) ! stress12_2
      call ice_read_global(nu_restart,0,work_g2,'ruf8',diag) ! stress12_4
      call scatter_global_stress(stress12_2, work_g1, work_g2, &
                                 master_task, distrb_info)
      call scatter_global_stress(stress12_4, work_g2, work_g1, &
                                 master_task, distrb_info)

      deallocate (work_g1, work_g2)

      !-----------------------------------------------------------------
      ! ice mask for dynamics
      !-----------------------------------------------------------------
      if (my_task == master_task) &
           write(nu_diag,*) 'ice mask for dynamics'

      call ice_read(nu_restart,0,work1,'ruf8',diag, &
                    field_loc_center, field_type_scalar)

      iceumask(:,:,:) = .false.
      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks
         do j = 1, ny_block
         do i = 1, nx_block
            if (work1(i,j,iblk) > p5) iceumask(i,j,iblk) = .true.
         enddo
         enddo
      enddo
      !$OMP END PARALLEL DO

      ! for mixed layer model
      if (oceanmixed_ice) then

         if (my_task == master_task) &
              write(nu_diag,*) 'min/max sst, frzmlt'

         call ice_read(nu_restart,0,sst,'ruf8',diag, &
                       field_loc_center, field_type_scalar)
         call ice_read(nu_restart,0,frzmlt,'ruf8',diag, &
                       field_loc_center, field_type_scalar)
      endif

      if (my_task == master_task) close(nu_restart)

      !-----------------------------------------------------------------
      ! Ensure unused stress values in west and south ghost cells are 0
      !-----------------------------------------------------------------
      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks
         do j = 1, nghost
         do i = 1, nx_block
            stressp_1 (i,j,iblk) = c0
            stressp_2 (i,j,iblk) = c0
            stressp_3 (i,j,iblk) = c0
            stressp_4 (i,j,iblk) = c0
            stressm_1 (i,j,iblk) = c0
            stressm_2 (i,j,iblk) = c0
            stressm_3 (i,j,iblk) = c0
            stressm_4 (i,j,iblk) = c0
            stress12_1(i,j,iblk) = c0
            stress12_2(i,j,iblk) = c0
            stress12_3(i,j,iblk) = c0
            stress12_4(i,j,iblk) = c0
         enddo
         enddo
         do j = 1, ny_block
         do i = 1, nghost
            stressp_1 (i,j,iblk) = c0
            stressp_2 (i,j,iblk) = c0
            stressp_3 (i,j,iblk) = c0
            stressp_4 (i,j,iblk) = c0
            stressm_1 (i,j,iblk) = c0
            stressm_2 (i,j,iblk) = c0
            stressm_3 (i,j,iblk) = c0
            stressm_4 (i,j,iblk) = c0
            stress12_1(i,j,iblk) = c0
            stress12_2(i,j,iblk) = c0
            stress12_3(i,j,iblk) = c0
            stress12_4(i,j,iblk) = c0
         enddo
         enddo
      enddo
      !$OMP END PARALLEL DO

      !-----------------------------------------------------------------
      ! Ensure ice is binned in correct categories
      ! (should not be necessary unless restarting from a run with
      !  different category boundaries).
      !
      ! If called, this subroutine does not give exact restart.
      !-----------------------------------------------------------------
!!!      call cleanup_itd

      !-----------------------------------------------------------------
      ! compute aggregate ice state and open water area
      !-----------------------------------------------------------------

      !$OMP PARALLEL DO PRIVATE(iblk,i,j)
      do iblk = 1, nblocks

      do j = 1, ny_block
      do i = 1, nx_block
         if (tmask(i,j,iblk)) &
            call icepack_aggregate(ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   trcrn = trcrn(i,j,:,:,iblk),   &
                                   vicen = vicen(i,j,:,iblk),     &
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   trcr  = trcr (i,j,:,iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   vsno  = vsno (i,j,  iblk),     &
                                   aice0 = aice0(i,j,  iblk),     &
                                   ntrcr = ntrcr,                 &
                                    trcr_depend   = trcr_depend(:),&
                                   trcr_base     = trcr_base(:,:),   &
                                   n_trcr_strata = n_trcr_strata(:), &
                                   nt_strata     = nt_strata(:,:))
         aice_init(i,j,iblk) = aice(i,j,iblk)
      enddo
      enddo

      enddo
      !$OMP END PARALLEL DO

      call icepack_warnings_flush(nu_diag)
      if (icepack_warnings_aborted()) call abort_ice(error_message=subname, &
         file=__FILE__, line=__LINE__)

      ! creates new file
      filename = trim(restart_dir) // '/iced.converted'
      call dumpfile(filename)
      call final_restart
      ! stop

      ! if runid is bering then need to correct npt for istep0
      if (trim(runid) == 'bering') then
         npt = npt - istep0
      endif

      end subroutine restartfile_v4

      subroutine ice_da_state_update(stepp)

      use ice_blocks, only:  nx_block, ny_block
      use ice_calendar !, only: istep0, istep1, time, time_forc,calendar, npt, dt, istep
      use ice_communicate, only: my_task, master_task
      use ice_constants, only: c0, p5, c10, c100, p999999
!          field_loc_center, field_loc_NEcorner,
!          field_type_scalar, field_type_vector
      use ice_domain, only: nblocks,distrb_info
      use ice_domain_size, only: nilyr, nslyr, ncat, max_blocks
      use ice_fileunits, only: nu_diag, nu_rst_pointer, nu_restart, nu_dump
      use ice_gather_scatter, only: scatter_global, gather_global
      use ice_grid, only: tmask
      use ice_read_write, only: ice_open, ice_read, ice_read_global
      use ice_state, only: trcr_depend, aice, vice, incraice, incrhice, vsno, trcr, &
          aice0, aicen, incraicen, incrhicen, hicen_asm, vicen, vsnon, trcrn, aice_init, &
          aice_glob, vice_glob, incraice_glob, incrhice_glob, &
          trcr_base, nt_strata, n_trcr_strata

      use ice_init, only: incr_file
     use netcdf

      integer (kind=int_kind) :: &
          i, j, k, n, iblk, &     ! counting indices
          ilo,ihi,jlo,jhi, ij, &
          iyear, imonth, iday ,ntrcr    ! year, month, day

      integer (kind=int_kind) :: &
         icells

      integer (kind=int_kind), intent(in) :: &
         stepp

  !     integer (kind=int_kind), dimension (nx_block*ny_block) :: &
  !       indxi, indxj      ! compressed i/j indices


      integer (kind=int_kind) :: &
         istop, jstop ! indices of grid cell where model aborts

      integer (kind=int_kind) :: &
         ndt, elapsed_days   !Total number of model steps from init to final/prescribed date

      integer (kind=int_kind) :: ncid, incr_fileid, status
      logical (kind=log_kind) :: diag

      character(len=char_len_long) :: &
         filename, filename0, filepath

      character(len=8) :: dates_string, x1
      character(len=4) :: yr

      real (kind=dbl_kind) :: puny,cszn,netsw ! counter for history averaging

      call icepack_query_parameters(puny_out=puny)
      call icepack_query_tracer_sizes(ntrcr_out=ntrcr)


      ndt = 86400*nday_asmiau/dt !required and recalculated at any step

      if (stepp .eq. 0) then                    !At the first model time step

            filename = trim(incr_file)
            if (my_task == master_task) then
               write(nu_diag,*) 'Reading Increment file: ',filename
            endif
            status = nf90_open(trim(filename), nf90_nowrite, ncid)
            if (status /= nf90_noerr) call abort_ice( &
               'ice: Error reading increment ncfile '//trim(filename))
            !Reading increment file (un-categorised)
            if (my_task == master_task) write(nu_diag,*) 'Reading SIC .'
            incr_fileid = ncid

           call read_restart_field_incr(incr_fileid,incraice_glob,'ruf8', &
                  'INCICECOV',diag,field_loc_center, field_type_scalar)
          if (my_task == master_task) write(nu_diag,*) 'yday=',yday
          !Scattering increment into blocks
         ! incraice_glob(:,:)=0.9
          call scatter_global(incraice, incraice_glob,&
master_task,distrb_info,field_loc_center, field_type_scalar)

           if (ln_asmboth) then
            if (my_task == master_task) write(nu_diag,*) 'Reading SIT ..'
            call read_restart_field_incr(incr_fileid,incrhice_glob,'ruf8', &
                   'INCICETHI',diag,field_loc_center, field_type_scalar)
            call scatter_global(incrhice, incrhice_glob, master_task,&
distrb_info,field_loc_center, field_type_scalar)
               endif

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
             do j = 1, ny_block
             do i = 1, nx_block
            if (tmask(i,j,iblk)) then
                call aggregate_only (ncat,  &
                           aicen=aicen(i,j,:,iblk),   &
                           vicen=vicen(i,j,:,iblk),   &
                           vsnon = vsnon(i,j,:,iblk),     &
                           aice  = aice (i,j,  iblk),     &
                           vice  = vice (i,j,  iblk),     &
                           vsno  = vsno (i,j,  iblk),     &
                           aice0 = aice0(i,j,  iblk))
                aice_init(i,j,iblk) = aice(i,j,iblk)
             endif
           enddo
           enddo
           enddo
           !$OMP END PARALLEL DO

           !DEEP:: Correcting increments blockwise manner


          !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

                 if(abs(incraice(i,j,iblk)) .gt. c1) incraice(i,j,iblk)= p999999 !removing bad values (if any)
                 if(isnan(incraice(i,j,iblk))) incraice(i,j,iblk) = c0 !removing NaNs (if any)

                 if(ln_asmboth) then
                   if( (abs(incrhice(i,j,iblk)) .gt. c100) ) incrhice(i,j,iblk) = c0
                   if(isnan(incrhice(i,j,iblk))) incrhice(i,j,iblk) = c0
                   if( (vice(i,j,iblk) + incrhice(i,j,iblk)) .lt. c0)  incrhice(i,j,iblk) =  vice(i,j,iblk)*(-1._dbl_kind)
                   if( aice(i,j,iblk) < 0.00001_dbl_kind .and. ((vice(i,j,iblk)  + incrhice(i,j,iblk)) .gt. c0) ) incrhice(i,j,iblk) = vice(i,j,iblk)*(-1._dbl_kind)
           endif

                 if( (aice(i,j,iblk) + incraice(i,j,iblk)) .gt. p999999) then
                        incraice(i,j,iblk) = p999999 -aice(i,j,iblk)
                 else if((aice(i,j,iblk) + incraice(i,j,iblk)) .lt. c0) then !when incr < 0. then the oceanvar tells that the point should be ice-free
                        incraice(i,j,iblk) = c0 - aice(i,j,iblk)
                 endif

           enddo !nx_block
           enddo !ny_block
           enddo !nblocks
           !$OMP END PARALLEL DO

           if (ln_asmiau .and. stepp .eq. 0) then

                !ndt = 86400*nday_asmiau/dt
                incraice = incraice/ndt                 !Scaling total SIC increment into model timesteps
                if (ln_asmboth) incrhice = incrhice/ndt !Scaling total SIT increment into model timesteps
                if (my_task == master_task) then
                 write(nu_diag,*) ' '
                 write(nu_diag,*) '******* Initiaing I-A-U ********'
                 write(nu_diag,*) '      nday_asmiau = ',nday_asmiau
                 write(nu_diag,*) '      dt          = ',dt
                 write(nu_diag,*) 'ndt = 86400*nday_asmiau/dt =',ndt
                 write(nu_diag,*) 'incr_AICE = incr_AICE/ndt'
                 write(nu_diag,*) 'incr_HICE = incr_HICE/ndt'
                 write(nu_diag,*) 'max incraice ::',maxval(incraice)
                 write(nu_diag,*) ' '
                endif


           else

              if (my_task == master_task) then
               write(nu_diag,*) ' '
               write(nu_diag,*) '********* Initiaing D-I **********'
               write(nu_diag,*) ' '
              endif

           endif !(.not. ln_asmiau)

              !-----------------------------------------------------------------
              ! Adding increments
              !-----------------------------------------------------------------

              if (ln_asmboth) then !For Concentration and Thickness increments both

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks

            do j = 1, ny_block
            do i = 1, nx_block

           if (tmask(i,j,iblk)) &
            call addincr(          ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   vicen = vicen(i,j,:,iblk),     &
                                   incraicen = incraicen(i,j,:,iblk),   &
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   incraice  = incraice (i,j,  iblk),     &
                                   tmask  = tmask (i,j,  iblk),     &
                                   hicen_asm = hicen_asm(i,j,:,iblk),     &
                                   incrhicen = incrhicen(i,j,:,iblk),&
                                   incrhice  = incrhice (i,j,  iblk))


           enddo !for i
           enddo !for j
          enddo !nblocks
          !$OMP END PARALLEL DO

         else if (ln_asmaice) then !for concentration only

          !$OMP PARALLEL DO PRIVATE(iblk,i,j)
          do iblk = 1, nblocks

           do j = 1, ny_block
           do i = 1, nx_block

           if (tmask(i,j,iblk)) &
            call addincr(          ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   vicen = vicen(i,j,:,iblk),     &
                                   incraicen = incraicen(i,j,:,iblk),&
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   incraice  = incraice (i,j,  iblk),&
                                   tmask  = tmask (i,j,  iblk))

           enddo !for i
           enddo !for j
          enddo !nblocks
          !$OMP END PARALLEL DO

          endif




           !-----------------------------------------------------------------
           ! Bound State
           !-----------------------------------------------------------------

!             call bound_state (aicen, trcrn, vicen, vsnon)

           !-----------------------------------------------------------------
           ! Aggreagting after update
           !-----------------------------------------------------------------

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

         if (tmask(i,j,iblk)) then

            call icepack_aggregate(ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   trcrn = trcrn(i,j,:,:,iblk),   &
                                   vicen = vicen(i,j,:,iblk),     &
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   trcr  = trcr (i,j,:,iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   vsno  = vsno (i,j,  iblk),     &
                                   aice0 = aice0(i,j,  iblk),     &
                                   ntrcr = ntrcr,                 &
                                   trcr_depend   = trcr_depend(:), &
                                   trcr_base     = trcr_base(:,:),   &
                                   n_trcr_strata = n_trcr_strata(:), &
                                   nt_strata     = nt_strata(:,:))
        aice_init(i,j,iblk) = aice(i,j,iblk)
          endif

      enddo
      enddo

      enddo                     ! iblk
      !$OMP END PARALLEL DO


           if (my_task == master_task) then

             if (ln_asmboth) then !for SIC and SIT

              if (ln_asmiau) then
               write(nu_diag,*) 'I-A-U DONE for SIC+SIT: Model Step =',stepp
               write(nu_diag,*) '********************************'
               write(nu_diag,*) ''
              else
               write(nu_diag,*) 'D-I DONE for SIC+SIT  : Model Step =',stepp
               write(nu_diag,*) '********************************'
               write(nu_diag,*) ''
              endif

             else                 !for SIC

              if (ln_asmiau) then

                write(nu_diag,*) 'I-A-U DONE for SIC    : Model Step =',stepp
                write(nu_diag,*) '********************************'
                write(nu_diag,*) ''

              else

               write(nu_diag,*) 'D-I   DONE for SIC    : Model Step =',stepp
               write(nu_diag,*) '********************************'
               write(nu_diag,*) ''

              endif !ln_asmiau

            endif !ln_asmboth

           endif !mytask

         endif !istep = 0

!-----------------------------------------------------------------------------------------------------
!
!                               Below is ONLY for I-A-U
!
!-----------------------------------------------------------------------------------------------------

        !  if (stepp .gt. 0. .and. stepp .le. ndt .and. ln_asmiau) then
        if (stepp .gt. 0. .and. ln_asmiau) then  
         ! usually appied to 7 days , the rest of the days would have been without and  melting processes could araise

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

           if (tmask(i,j,iblk)) then
                      call aggregate_only (ncat,  &
                           aicen=aicen(i,j,:,iblk),   &
                           vicen=vicen(i,j,:,iblk),   &
                           vsnon = vsnon(i,j,:,iblk),     &
                           aice  = aice (i,j,  iblk),     &
                           vice  = vice (i,j,  iblk),     &
                           vsno  = vsno (i,j,  iblk),     &
                           aice0 = aice0(i,j,  iblk))
               aice_init(i,j,iblk) = aice(i,j,iblk)
           endif
           enddo
           enddo
           enddo
           !$OMP END PARALLEL DO

           !DEEP:: Correcting increments blockwise manner

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

                 if(abs(incraice(i,j,iblk)) .gt. c1) incraice(i,j,iblk)= p999999 !removing bad values (if any)
                 if(isnan(incraice(i,j,iblk))) incraice(i,j,iblk) = c0 !removing NaNs (if any)

                 if(ln_asmboth) then
                   if( (abs(incrhice(i,j,iblk)) .gt. c100) ) incrhice(i,j,iblk) = c0
                   if(isnan(incrhice(i,j,iblk))) incrhice(i,j,iblk) = c0
                   if( (vice(i,j,iblk) + incrhice(i,j,iblk)) .lt. c0)  incrhice(i,j,iblk) =  vice(i,j,iblk)*(-1._dbl_kind)
                   if( aice(i,j,iblk) < 0.00001_dbl_kind .and.((vice(i,j,iblk)  + incrhice(i,j,iblk)) .gt. c0)) incrhice(i,j,iblk) = vice(i,j,iblk)*(-1._dbl_kind)
           endif

                 if( (aice(i,j,iblk) + incraice(i,j,iblk)) .gt. p999999) then
                        incraice(i,j,iblk) = p999999 -aice(i,j,iblk)
                 else if((aice(i,j,iblk) + incraice(i,j,iblk)) .lt. c0) then !when incr < 0. then the oceanvar tells that the point should be ice-free
                        incraice(i,j,iblk) = c0 - aice(i,j,iblk)
                 endif
           enddo !nx_block
           enddo !ny_block
           enddo !nblocks
           !$OMP END PARALLEL DO


           !-----------------------------------------------------------------
           ! Adding increments
           !-----------------------------------------------------------------
           if (ln_asmboth) then

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

!For Concentration and Thickness increments both
           if (tmask(i,j,iblk)) then
                      call addincr (ncat, &
                                 aicen=aicen(i,j,:,     iblk) , &
                                 vicen=vicen(i,j,:,     iblk) , &
                                 incraicen=incraicen(i,j,:, iblk) , &
                                 vsnon=vsnon(i,j,:,iblk)      , &
                                 aice=aice(i,j,        iblk) , &
                                 vice=vice(i,j,        iblk) , &
                                 incraice=incraice(i,j,    iblk) , &
                                 tmask=tmask(i,j,       iblk) , &
                                 hicen_asm=hicen_asm(i,j,:, iblk) , &
                                 incrhicen=incrhicen(i,j,:, iblk) , &
                                 incrhice=incrhice(i,j,    iblk))
           endif
           enddo
           enddo
           enddo !nblocks
           !$OMP END PARALLEL DO

           else if (ln_asmaice) then
!for concentration only
          !$OMP PARALLEL DO PRIVATE(iblk,i,j)
           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

            if (tmask(i,j,iblk)) then
                            call addincr (ncat, &
                                 aicen=aicen(i,j,:,     iblk) , &
                                 vicen=vicen(i,j,:,     iblk) , &
                                 incraicen=incraicen(i,j,:, iblk) , &
                                 vsnon=vsnon(i,j,:,iblk)      , &
                                 aice=aice(i,j,        iblk) , &
                                 vice=vice(i,j,        iblk) , &
                                 incraice=incraice(i,j,    iblk) , &
                                 tmask=tmask(i,j,       iblk))
           endif
           enddo
           enddo
           enddo !nblocks
           !$OMP END PARALLEL DO

           endif
           !-----------------------------------------------------------------
           ! Bound State
           !-----------------------------------------------------------------

!           call bound_state (aicen, trcrn, vicen, vsnon)

           !-----------------------------------------------------------------
           ! Aggreagting after update
           !-----------------------------------------------------------------

           !$OMP PARALLEL DO PRIVATE(iblk,i,j)

           do iblk = 1, nblocks
           do j = 1, ny_block
           do i = 1, nx_block

            if (tmask(i,j,iblk)) then
               call icepack_aggregate(ncat  = ncat,                  &
                                   aicen = aicen(i,j,:,iblk),     &
                                   trcrn = trcrn(i,j,:,:,iblk),   &
                                   vicen = vicen(i,j,:,iblk),     &
                                   vsnon = vsnon(i,j,:,iblk),     &
                                   aice  = aice (i,j,  iblk),     &
                                   trcr  = trcr (i,j,:,iblk),     &
                                   vice  = vice (i,j,  iblk),     &
                                   vsno  = vsno (i,j,  iblk),     &
                                   aice0 = aice0(i,j,  iblk),     &
                                   ntrcr = ntrcr,                 &
                                  trcr_depend   = trcr_depend(:),   &
                                   trcr_base     = trcr_base(:,:),   &
                                   n_trcr_strata = n_trcr_strata(:), &
                                   nt_strata     = nt_strata(:,:))

             aice_init(i,j,iblk) = aice(i,j,iblk)
           endif
           enddo
           enddo
           enddo !nblocks
           !$OMP END PARALLEL DO


           if (my_task == master_task) then
             if (ln_asmboth) then !for SIC and SIT
               write(nu_diag,*) 'I-A-U DONE for SIC+SIT: Model Step =',stepp
               write(nu_diag,*) '********************************'
               write(nu_diag,*) ''
             else                 !for SIC
                write(nu_diag,*) 'I-A-U DONE for SIC    : Model Step =',stepp
                write(nu_diag,*) '********************************'
                write(nu_diag,*) ''
             endif !ln_asmboth
           endif !mytask
       endif !ln_asmiau .and. stepp > 0

      end subroutine ice_da_state_update

!==============================================================================
! Apply increment (add/remove) to the concerned field.
!==============================================================================

      subroutine addincr  (ncat,                    &
                           aicen,                   &
                           vicen,                   &
                           incraicen,               &
                           vsnon,                   &
                           aice,                    &
                           vice,                    &
                           incraice,                &
                           tmask,                   &
                           hicen_asm,               &
                           incrhicen,               &
                           incrhice)

      use ice_restart_shared, only: ln_asmboth, ln_asmaice
      use ice_exit, only: abort_ice

!      integer (kind=int_kind), intent(in) :: &
!         nx_block, ny_block    ! block dimensions

!      real (kind=dbl_kind), dimension (nx_block,ny_block,ncat), &
!         intent(inout) :: &

      integer (kind=int_kind), intent(in) :: &
         ncat      ! number of thickness categories

      real (kind=dbl_kind), dimension(:), intent(inout) :: &
         aicen , &             ! concentration of ice
         vicen , &             ! volume per unit area of ice (m)
         vsnon

      real (kind=dbl_kind), &
         intent(in) :: &
         incraice              !total increment in concentration (corrected)

      real (kind=dbl_kind), &
         intent(inout), optional :: &
         incrhice

      real (kind=dbl_kind), intent(inout) :: &
         aice, &   ! concentration of ice
         vice

!      real (kind=dbl_kind), dimension (nx_block,ny_block), &
!         intent(inout) :: &
!         aice , &              ! concentration of ice
!         vice                  ! volume per unit area of ice (m)

!      logical (kind=log_kind), dimension (nx_block,ny_block), &
!         intent(in) :: &
!         tmask                 ! land/boundary mask, thickness (T-cell)

      logical (kind=log_kind), intent(in) :: &
         tmask                 ! land/boundary mask, thickness (T-cell)

!      real (kind=dbl_kind), dimension (nx_block,ny_block,ncat), &
!         intent(inout), optional :: &
!         hicen_asm , &         ! thickness of ice
!         incrhicen , &         ! increment in thickness (categorised)
!         incraicen             ! increment in concentration

      real (kind=dbl_kind), dimension(:), intent(inout), optional :: &
         hicen_asm , &         ! thickness of ice
         incrhicen , &         ! increment in thickness (categorised)
         incraicen             ! increment in concentration

      ! local variables

      real (kind=dbl_kind), dimension(ncat) :: &
         frac_vol , &          !Fractional contribution from each category for volume
         frac_aic              !Fractional contribution from each category for

!      integer (kind=int_kind), dimension (nx_block*ny_block) :: &
!         indxi, &              ! compressed indices in i/j directions
!         indxj

      real (kind=dbl_kind) :: &
         hsn                 ! snow thickness

      real (kind=dbl_kind), dimension (ncat) :: &
         hicen_loc             !Thickness Sea ice locally derived

      integer (kind=int_kind) :: &
         i, j, n, it, &        ! loop indices
         ij, nn, ii, jj        ! combined i/j horizontal index

      real (kind=dbl_kind) :: puny

      call icepack_query_parameters(puny_out=puny)


!      icells = 0
!      do j = 1, ny_block
!      do i = 1, nx_block
!         if (tmask(i,j)) then
!            icells = icells + 1
!            indxi(icells) = i
!            indxj(icells) = j
!         endif                  !tmask
!      enddo
!      enddo

!      if (icells > 0) then

!      do j = 1, ny_block
!      do i = 1, nx_block

             IF (ln_asmboth) THEN

                 !-----------------------------------------------------------------
                 ! Sea Ice Concentration and Sea Ice Thickness
                 !-----------------------------------------------------------------

                 if (aice < puny .and. incraice > puny .and. incrhice > puny) then     !checking if there are NO ICE in the cell

                             n=1 !generate ice only in the first category only
                             aicen(n)     = aicen(n) + incraice !updating sea ice area
                             vicen(n)     = vicen(n) + (incraice)*(incrhice)        !updating sea ice volume
                             hsn            = vsnon(n)/aicen(n)
                             vsnon(n)     = aicen(n) * hsn !updating snow thickness

                 else if (aice >= puny ) then !checking if there IS ICE

                    do n=1, ncat !looping over categories

                          if (aicen(n) > puny) then !making sure checking if the cell with the category has ice
                             frac_vol(n)  = vicen(n)/vice !contribution from category to each grid box volume
                             frac_aic(n)  = aicen(n)/aice !contribution from category to each grid box concentration

                             incraicen(n) = incraice*frac_aic(n) !distributing total increments into categories according to fractional !concentration
                             incrhicen(n) = incrhice*frac_vol(n) !distributing total increments into categories according to fractional !volume
                             hicen_asm(n) = vicen(n)/aicen(n) !estimating initial value of thickness

                             hsn            = vsnon(n)/aicen(n)

                             aicen(n)     = aicen(n) + incraicen(n) !adding/removing ice based on SIC increments
                             hicen_asm(n) = hicen_asm(n) + incrhicen(n) !adding/removing ice based on SIT increments
                             vsnon(n)     = aicen(n) * hsn !updating snow thickness
                             vicen(n)     = hicen_asm(n) * aicen(n) !updating the ice_volume based on updated Thickness and Concentration
                             if (vicen(n) < 0. ) vicen(n) = 0.
                          else
                             aicen(n) = c0
                             vicen(n) = c0
                             vsnon(n) = c0
                          endif  !aicen > puny
                    enddo        !ncat
                 endif           !aice > 0 or aice < 0

               ELSE IF (ln_asmaice) THEN

                 !-----------------------------------------------------------------
                 ! Sea Ice Concentration
                 !-----------------------------------------------------------------

                 if (aice < puny .and. incraice > puny ) then !checking if there are NO ICE in the cell
                             n=1 !generate ice only in the first category only
                             aicen(n)     = aicen(n) + incraice !generating ice with by SIC increment
                             vicen(n)     = vicen(n) + 0.2_dbl_kind*incraice            !generating ice with by SIV increment and a standard thickness (= 0.5m * SIC_incr)
                             hsn            = vsnon(n)/aicen(n)
                             vsnon(n)     = aicen(n) * hsn !updating snow thickness
                 else if (aice >= puny ) then !checking if there IS ICE
                    do n=1, ncat !looping over categories

                          if (aicen(n) > puny) then !making sure the cell with the category has ice
                             hicen_loc(n) = vicen(n)/aicen(n) !estimating initial value of thickness locally
                             frac_aic(n)  = aicen(n)/aice !contribution from category to each grid box concentration
                             incraicen(n) = incraice*frac_aic(n) !distributing total increments into categories according to fractional !concentration

                             hsn = vsnon(n)/aicen(n)

                             aicen(n)     = aicen(n) + incraicen(n) !adding/removing ice concentration based on SIC increments
                             vsnon(n)     = aicen(n) * hsn !updating snow thickness

                             vicen(n)     = vicen(n) + ( hicen_loc(n) * incraicen(n) )!adding/removing ice volume based on updated SIC increments
                             if (vicen(n) < 0.) vicen(n) = 0.
                          else
                             aicen(n) = c0
                             vicen(n) = c0
                             vsnon(n) = c0
                          endif    !aicen > puny
                    enddo          !ncat
                 endif             !aice > puny
               ENDIF               !ln_asmboth / ln_asmaice

!      enddo                        !nx_block
!      enddo                        !ny_block
!      endif                        !icells

      end subroutine addincr

!=======================================================================

      end module ice_restart_driver

!=======================================================================
