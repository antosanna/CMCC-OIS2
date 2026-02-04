MODULE tradmp
   !!======================================================================
   !!                       ***  MODULE  tradmp  ***
   !! Ocean physics: internal restoring trend on active tracers (T and S)
   !!======================================================================
   !! History :  OPA  ! 1991-03  (O. Marti, G. Madec)  Original code
   !!                 ! 1992-06  (M. Imbard)  doctor norme
   !!                 ! 1998-07  (M. Imbard, G. Madec) ORCA version
   !!            7.0  ! 2001-02  (M. Imbard)  add distance to coast, Original code
   !!            8.1  ! 2001-02  (G. Madec, E. Durand)  cleaning
   !!  NEMO      1.0  ! 2002-08  (G. Madec, E. Durand)  free form + modules
   !!            3.2  ! 2009-08  (G. Madec, C. Talandier)  DOCTOR norm for namelist parameter
   !!            3.3  ! 2010-06  (C. Ethe, G. Madec) merge TRA-TRC
   !!            3.4  ! 2011-04  (G. Madec, C. Ethe) Merge of dtatem and dtasal + suppression of CPP keys
   !!            3.6  ! 2015-06  (T. Graham)  read restoring coefficient in a file
   !!            3.7  ! 2015-10  (G. Madec)  remove useless trends arrays
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   tra_dmp_alloc : allocate tradmp arrays
   !!   tra_dmp       : update the tracer trend with the internal damping
   !!   tra_dmp_init  : initialization, namlist read, parameters control
   !!----------------------------------------------------------------------
   USE oce            ! ocean: variables
   USE dom_oce        ! ocean: domain variables
   USE trd_oce        ! trends: ocean variables
   USE trdtra         ! trends manager: tracers
   USE zdf_oce        ! ocean: vertical physics
   USE phycst         ! physical constants
   USE dtatsd         ! data: temperature & salinity
   USE zdfmxl         ! vertical physics: mixed layer depth
   !
   USE in_out_manager ! I/O manager
   USE iom            ! XIOS
   USE lib_mpp        ! MPP library
   USE prtctl         ! Print control
   USE timing         ! Timing
   USE stopack        !

   IMPLICIT NONE
   PRIVATE

   PUBLIC   tra_dmp        ! called by step.F90
   PUBLIC   tra_dmp_init   ! called by nemogcm.F90

   !                                           !!* Namelist namtra_dmp : T & S newtonian damping *
   LOGICAL            , PUBLIC ::   ln_tradmp   !: internal damping flag
   INTEGER            , PUBLIC ::   nn_zdmp     !: = 0/1/2 flag for damping in the mixed layer
   CHARACTER(LEN=999), PUBLIC :: cn_resto = 'damping.nc'
   INTEGER         ::   nn_hdmp   =   -1      ! = 0/-1/'latitude' for damping over T and S
   REAL(wp)        ::   rn_surf   =   50._wp  ! surface time scale for internal damping        [days]
   REAL(wp)        ::   rn_bot    =  360._wp  ! bottom time scale for internal damping         [days]
   REAL(wp)        ::   rn_dep    =  800._wp  ! depth of transition between rn_surf and rn_bot [meters]
   INTEGER         ::   nn_file   =    2      ! = 1 create a damping.coeff NetCDF file
   INTEGER         ::   nn_lsf    =    0      ! Number of SH filter iterations
   INTEGER         ::   nn_ftdm   =    1      ! Frequency of bias update
   REAL(wp)        ::   rn_zinfl  = 50000._wp ! distance of influence for damping term
   REAL(wp)        ::   rn_zlat0  = 5._wp     ! latitude strip where resto decreases
   INTEGER            , PUBLIC ::  esc_pole_dmp ! no damping in the pole

   REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   resto    !: restoring coeff. on T and S (s-1)
   REAL(wp),         ALLOCATABLE, SAVE, DIMENSION(:,:)     ::   z2da     !: restoring coeff. on T and S (s-1)
   REAL(wp), DIMENSION(:,:,:,:), ALLOCATABLE ::  zts_dta,zztmp

   !! * Substitutions
#  include "do_loop_substitute.h90"
#  include "domzgr_substitute.h90"
   !!----------------------------------------------------------------------
   !! NEMO/OCE 4.0 , NEMO Consortium (2018)
   !! $Id: tradmp.F90 15023 2021-06-18 14:35:25Z gsamson $
   !! Software governed by the CeCILL license (see ./LICENSE)
   !!----------------------------------------------------------------------
CONTAINS

   INTEGER FUNCTION tra_dmp_alloc()
      !!----------------------------------------------------------------------
      !!                ***  FUNCTION tra_dmp_alloc  ***
      !!----------------------------------------------------------------------
      ALLOCATE( zztmp(jpi,jpj,jpk,jpts),zts_dta(jpi,jpj,jpk,jpts),resto(jpi,jpj,jpk), &
              & z2da(jpi,jpj), STAT= tra_dmp_alloc )
      !
      CALL mpp_sum ( 'tradmp', tra_dmp_alloc )
      IF( tra_dmp_alloc > 0 )   CALL ctl_warn('tra_dmp_alloc: allocation of arrays failed')
      z2da(:,:) = 1._wp
      !
   END FUNCTION tra_dmp_alloc


   SUBROUTINE tra_dmp( kt, Kbb, Kmm, pts, Krhs )
      !!----------------------------------------------------------------------
      !!                   ***  ROUTINE tra_dmp  ***
      !!
      !! ** Purpose :   Compute the tracer trend due to a newtonian damping
      !!      of the tracer field towards given data field and add it to the
      !!      general tracer trends.
      !!
      !! ** Method  :   Newtonian damping towards t_dta and s_dta computed
      !!      and add to the general tracer trends:
      !!                     ta = ta + resto * (t_dta - tb)
      !!                     sa = sa + resto * (s_dta - sb)
      !!         The trend is computed either throughout the water column
      !!      (nlmdmp=0) or in area of weak vertical mixing (nlmdmp=1) or
      !!      below the well mixed layer (nlmdmp=2)
      !!
      !! ** Action  : - tsa: tracer trends updated with the damping trend
      !!----------------------------------------------------------------------
      INTEGER,                                   INTENT(in   ) :: kt              ! ocean time-step index
      INTEGER,                                   INTENT(in   ) :: Kbb, Kmm, Krhs  ! time level indices
      REAL(wp), DIMENSION(jpi,jpj,jpk,jpts,jpt), INTENT(inout) :: pts             ! active tracers and RHS of tracer equation
      !
      INTEGER ::   ji, jj, jk, jn   ! dummy loop indices
      !REAL(wp), DIMENSION(A2D(nn_hls),jpk,jpts)     ::  zts_dta,zztmp
      !REAL(wp), DIMENSION(:,:,:,:), ALLOCATABLE ::  zts_dta,zztmp
      REAL(wp), DIMENSION(:,:,:)  , ALLOCATABLE ::  zwrk
      REAL(wp), DIMENSION(:,:,:,:), ALLOCATABLE ::  ztrdts
      CHARACTER(len=20)  ::  c_kind='ORCA_GLOB'
      !!----------------------------------------------------------------------
      !
      !ALLOCATE( zztmp(jpi,jpj,jpk,jpts),zts_dta(jpi,jpj,jpk,jpts) )
      !zztmp(:,:,:,:)=0._wp


      IF( ln_timing )   CALL timing_start('tra_dmp')
      !
      IF( l_trdtra .OR. iom_use('hflx_dmp_cea') .OR. iom_use('sflx_dmp_cea') ) THEN   !* Save ta and sa trends
      !   ALLOCATE( ztrdts(A2D(nn_hls),jpk,jpts) )
      ALLOCATE( ztrdts(jpi,jpj,jpk,jpts) )
         DO jn = 1, jpts
      !      DO_3D( nn_hls, nn_hls, nn_hls, nn_hls, 1, jpk )
            DO_3D( 0, 0, 0, 0, 1, jpk )
               ztrdts(ji,jj,jk,jn) = pts(ji,jj,jk,jn,Krhs)
            END_3D
         END DO
      ENDIF
      !                           !==  input T-S data at kt  ==!
      CALL dta_tsd( kt, zts_dta )            ! read and interpolates T-S data at kt
      !WRITE(numout,*) "MAX zts_dta",maxval(zts_dta(:,:,:,jp_tem)),"MAX pts",maxval(pts(:,:,:,jp_tem,Kbb)),"MAX diff",maxval((zts_dta(:,:,:,jp_tem)-pts(:,:,:,jp_tem,Kbb))*tmask) ,"again ", maxval((zts_dta(:,:,:,jp_tem)-pts(:,:,:,jp_tem,Kbb))*tmask(:,:,:))
      !                           !==  input T-S data at kt  ==!
      IF( ln_stopack .AND. nn_spp_tdmp > 0 ) THEN
           z2da(:,:) = 1._wp
           CALL spp_gen(kt, z2da, nn_spp_tdmp, rn_tdmp_sd, jk_spp_tdmp )
      ENDIF
      !
      IF( MOD( kt - 1, nn_ftdm ) == 0 .OR. kt == nit000 ) THEN
        IF( nn_lsf > 0 ) THEN
          IF(lwp) WRITE(numout,*) ' SHAPIRO FILTERING WITH PASSES ',nn_lsf
          DO jk=1,jpkm1
           CALL Shapiro_1D(zts_dta(:,:,jk,jp_tem)-pts(:,:,jk,jp_tem,Kbb),nn_lsf,c_kind,zztmp(:,:,jk,jp_tem),jk)
           CALL Shapiro_1D(zts_dta(:,:,jk,jp_sal)-pts(:,:,jk,jp_sal,Kbb),nn_lsf,c_kind,zztmp(:,:,jk,jp_sal),jk)
          ENDDO
          !WRITE(numout,*) "MAX shap ",maxval(zztmp(:,:,:,jp_tem))
        ELSE
          zztmp(:,:,:,jp_tem) = (zts_dta(:,:,:,jp_tem)-pts(:,:,:,jp_tem,Kbb))*tmask(:,:,:)
          zztmp(:,:,:,jp_sal) = (zts_dta(:,:,:,jp_sal)-pts(:,:,:,jp_sal,Kbb))*tmask(:,:,:)

        ENDIF
!         WHERE( .NOT. ABS(zztmp) .LT. 1.e+12_wp ) zztmp = 0._wp
        zztmp(:,:,jpk,:) = 0._wp
      ENDIF
      CALL iom_put('tem_lsbias',zztmp(:,:,:,jp_tem) )
      CALL iom_put('sal_lsbias',zztmp(:,:,:,jp_sal) )
      SELECT CASE ( nn_zdmp )     !==  type of damping  ==!
      !
      CASE( 0 )                        !*  newtonian damping throughout the water column  *!
         !WRITE(numout,*) "MAX before ", maxval(abs(pts(:,:,:,jp_tem,Krhs)))
         !WRITE(numout,*) "MAX rest*zty ", maxval(abs(resto(:,:,:) *zztmp(:,:,:,jp_tem)))
         !WRITE(numout,*) "MAX rest only", maxval(abs(resto(:,:,:)))

           DO jn = 1, jpts
!           DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,1,jpkm1)         
           DO_3D( 1,1, 1, 1, 1, jpkm1 )
               pts(ji,jj,jk,jn,Krhs) = pts(ji,jj,jk,jn,Krhs)           &
                  &                  + resto(ji,jj,jk) * z2da(ji,jj) * zztmp(ji,jj,jk,jn)
            END_3D
         END DO
          !WRITE(numout,*) "MAX after ", maxval(abs(pts(:,:,:,jp_tem,Krhs)))
         !
      CASE ( 1 )                       !*  no damping in the turbocline (avt > 5 cm2/s)  *!
        !DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,1, jpkm1 )
         DO_3D( 1, 1, 1, 1, 1, jpkm1 )
            IF( avt(ji,jj,jk) <= avt_c ) THEN
               pts(ji,jj,jk,jp_tem,Krhs) = pts(ji,jj,jk,jp_tem,Krhs)   &
                  &                      + resto(ji,jj,jk) * z2da(ji,jj) * zztmp(ji,jj,jk,jp_tem)
               pts(ji,jj,jk,jp_sal,Krhs) = pts(ji,jj,jk,jp_sal,Krhs)   &
                  &                      + resto(ji,jj,jk) * z2da(ji,jj) * zztmp(ji,jj,jk,jp_sal)
            ENDIF
         END_3D
         !
      CASE ( 2 )                       !*  no damping in the mixed layer   *!
        !DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,1, jpkm1 )
        DO_3D( 1, 1, 1, 1, 1, jpkm1 )
            IF( gdept(ji,jj,jk,Kmm) >= hmlp (ji,jj) ) THEN
               pts(ji,jj,jk,jp_tem,Krhs) = pts(ji,jj,jk,jp_tem,Krhs)   &
                  &                      + resto(ji,jj,jk) * z2da(ji,jj) * zztmp(ji,jj,jk,jp_tem)
               pts(ji,jj,jk,jp_sal,Krhs) = pts(ji,jj,jk,jp_sal,Krhs)   &
                  &                      + resto(ji,jj,jk) * z2da(ji,jj) * zztmp(ji,jj,jk,jp_sal)
            ENDIF
         END_3D
         !
      END SELECT

      !
      ! outputs (clem trunk)
      IF( iom_use('hflx_dmp_cea') .OR. iom_use('sflx_dmp_cea') ) THEN
         ALLOCATE( zwrk(jpi,jpj,jpk) )          ! Needed to handle expressions containing e3t when using key_qco or key_linssh
         zwrk(:,:,:) = 0._wp

         IF( iom_use('hflx_dmp_cea') ) THEN
           ! DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,1, jpk )
            DO_3D( 1, 1, 1, 1, 1, jpk )
               zwrk(ji,jj,jk) = ( pts(ji,jj,jk,jp_tem,Krhs) - ztrdts(ji,jj,jk,jp_tem) ) * e3t(ji,jj,jk,Kmm)
            END_3D
            CALL iom_put('hflx_dmp_cea', SUM( zwrk(:,:,:), dim=3 ) * rcp * rho0 ) ! W/m2
         ENDIF
         IF( iom_use('sflx_dmp_cea') ) THEN
           !DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,1, jpk )           
            DO_3D( 1, 1, 1, 1, 1, jpk )
               zwrk(ji,jj,jk) = ( pts(ji,jj,jk,jp_sal,Krhs) - ztrdts(ji,jj,jk,jp_sal) ) * e3t(ji,jj,jk,Kmm)
            END_3D
            CALL iom_put('sflx_dmp_cea', SUM( zwrk(:,:,:), dim=3 ) * rho0 )       ! g/m2/s
         ENDIF

         DEALLOCATE( zwrk )
      ENDIF
      !
      IF( l_trdtra )   THEN       ! trend diagnostic
         ztrdts(:,:,:,:) = pts(:,:,:,:,Krhs) - ztrdts(:,:,:,:)
         CALL trd_tra( kt, Kmm, Krhs, 'TRA', jp_tem, jptra_dmp, ztrdts(:,:,:,jp_tem) )
         CALL trd_tra( kt, Kmm, Krhs, 'TRA', jp_sal, jptra_dmp, ztrdts(:,:,:,jp_sal) )
         DEALLOCATE( ztrdts )
      ENDIF
      !                           ! Control print
      IF(sn_cfctl%l_prtctl)   CALL prt_ctl( tab3d_1=pts(:,:,:,jp_tem,Krhs), clinfo1=' dmp  - Ta: ', mask1=tmask,   &
         &                                  tab3d_2=pts(:,:,:,jp_sal,Krhs), clinfo2=       ' Sa: ', mask2=tmask, clinfo3='tra' )
      !
      !DEALLOCATE( zztmp,zts_dta )

      IF( ln_timing )   CALL timing_stop('tra_dmp')
      !
   END SUBROUTINE tra_dmp


   SUBROUTINE tra_dmp_init
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE tra_dmp_init  ***
      !!
      !! ** Purpose :   Initialization for the newtonian damping
      !!
      !! ** Method  :   read the namtra_dmp namelist and check the parameters
      !!----------------------------------------------------------------------
      INTEGER ::   ios, imask   ! local integers
      !
      NAMELIST/namtra_dmp/ ln_tradmp, nn_zdmp,nn_hdmp, rn_surf, rn_bot, rn_dep, nn_file, &
        & rn_zinfl, rn_zlat0, nn_lsf, nn_ftdm,esc_pole_dmp !, cn_resto
      !!----------------------------------------------------------------------
      !
      READ  ( numnam_ref, namtra_dmp, IOSTAT = ios, ERR = 901)
901   IF( ios /= 0 )   CALL ctl_nam ( ios , 'namtra_dmp in reference namelist' )
      !
      READ  ( numnam_cfg, namtra_dmp, IOSTAT = ios, ERR = 902 )
902   IF( ios >  0 )   CALL ctl_nam ( ios , 'namtra_dmp in configuration namelist' )
      IF(lwm) WRITE ( numond, namtra_dmp )
      !
      IF(lwp) THEN                  ! Namelist print
         WRITE(numout,*)
         WRITE(numout,*) 'tra_dmp_init : T and S newtonian relaxation'
         WRITE(numout,*) '~~~~~~~~~~~~'
         WRITE(numout,*) '   Namelist namtra_dmp : set relaxation parameters'
         WRITE(numout,*) '      Apply relaxation   or not     ln_tradmp   = ', ln_tradmp
         WRITE(numout,*) '       mixed layer damping option      nn_zdmp  = ', nn_zdmp
         WRITE(numout,*) '      T and S damping option          nn_hdmp   = ', nn_hdmp
         WRITE(numout,*) '      surface time scale (days)       rn_surf   = ', rn_surf
         WRITE(numout,*) '      bottom time scale (days)        rn_bot    = ', rn_bot
         WRITE(numout,*) '      depth of transition (meters)    rn_dep    = ', rn_dep
         WRITE(numout,*) '      create a damping.coeff file     nn_file   = ', nn_file
         WRITE(numout,*)
        WRITE(numout,*)
      ENDIF
      !
      IF( ln_tradmp ) THEN
         !                          ! Allocate arrays
         IF( tra_dmp_alloc() /= 0 )   CALL ctl_stop( 'STOP', 'tra_dmp_init: unable to allocate arrays' )
         !
         SELECT CASE ( nn_hdmp )
         CASE (  -1  )   ;   IF(lwp) WRITE(numout,*) '   tracer damping in the Med & Red seas only'
         CASE ( 0:90 )   ;   IF(lwp) WRITE(numout,*) '   tracer damping poleward of', nn_hdmp, ' degrees'
         CASE DEFAULT
            WRITE(ctmp1,*) '          bad flag value for nn_hdmp = ', nn_hdmp
            CALL ctl_stop(ctmp1)
         END SELECT

         SELECT CASE (nn_zdmp)      ! Check values of nn_zdmp
         CASE ( 0 )   ;   IF(lwp) WRITE(numout,*) '   tracer damping as specified by mask'
         CASE ( 1 )   ;   IF(lwp) WRITE(numout,*) '   no tracer damping in the mixing layer (kz > 5 cm2/s)'
         CASE ( 2 )   ;   IF(lwp) WRITE(numout,*) '   no tracer damping in the mixed  layer'
         CASE DEFAULT
            CALL ctl_stop('tra_dmp_init : wrong value of nn_zdmp')
         END SELECT
         !
         !!TG: Initialisation of dtatsd - Would it be better to have dmpdta routine
         !    so can damp to something other than intitial conditions files?
         !!gm: In principle yes. Nevertheless, we can't anticipate demands that have never been formulated.
         IF( .NOT.ln_tsd_dmp ) THEN
            IF(lwp) WRITE(numout,*)
            IF(lwp) WRITE(numout, *)  '   read T-S data not initialized, we force ln_tsd_dmp=T'
            CALL dta_tsd_init( ld_tradmp=ln_tradmp )        ! forces the initialisation of T-S data
         ENDIF
         !                          ! Damping coefficients initialization
         resto(:,:,:)=0._wp
         CALL dtacof( nn_hdmp, rn_surf, rn_bot, rn_dep, nn_file, 'TRA', resto )
           !WRITE(numout,*) "MAX resto init ",maxval(resto(:,:,:))
          !
     ENDIF
      !
   END SUBROUTINE tra_dmp_init

   !!======================================================================

   SUBROUTINE dtacof( kn_hdmp, pn_surf, pn_bot, pn_dep,  &
      &               kn_file, cdtype , presto           )
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE dtacof  ***
      !!
      !! ** Purpose :   Compute the damping coefficient
      !!
      !! ** Method  :   Arrays defining the damping are computed for each grid
      !!                point for temperature and salinity (resto)
      !!                Damping depends on distance to coast, depth and latitude
      !!
      !! ** Action  : - resto, the damping coeff. for T and S
      !!----------------------------------------------------------------------
      USE iom
      USE ioipsl
      !!
      INTEGER                         , INTENT(in   )  ::  kn_hdmp    ! damping option
      REAL(wp)                        , INTENT(in   )  ::  pn_surf    ! surface time scale (days)
      REAL(wp)                        , INTENT(in   )  ::  pn_bot     ! bottom time scale (days)
      REAL(wp)                        , INTENT(in   )  ::  pn_dep     ! depth of transition (meters)
      INTEGER                         , INTENT(in   )  ::  kn_file    ! save the damping coef on a file or not
      CHARACTER(len=3)                , INTENT(in   )  ::  cdtype     ! =TRA or TRC (tracer indicator)
      REAL(wp), DIMENSION(jpi,jpj,jpk), INTENT(inout)  ::  presto     ! restoring coeff. (s-1)
      !
      INTEGER  ::   ji, jj, jk                  ! dummy loop indices
      INTEGER  ::   ii0, ii1, ij0, ij1          ! local integers
      INTEGER  ::   inum0, icot                 !   -       -
      REAL(wp) ::   zinfl, zlon                 ! local scalars
      REAL(wp) ::   zlat, zlat0, zlat1, zlat2   !   -      -
      REAL(wp) ::   zsdmp, zbdmp                !   -      -
      CHARACTER(len=20)                   :: cfile
      REAL(wp), POINTER, DIMENSION(:    ) :: zhfac
      REAL(wp), POINTER, DIMENSION(:,:  ) :: zmrs
      REAL(wp), POINTER, DIMENSION(:,:,:) :: zdct
      !!----------------------------------------------------------------------
      !
      IF( ln_timing )  CALL timing_start('dtacof')
      !
      ALLOCATE(zhfac(jpk))
      ALLOCATE(zmrs(jpi, jpj))
      ALLOCATE(zdct(jpi, jpj, jpk))
      !                                   ! ====================
      !                                   !  ORCA configuration : global domain
      !                                   ! ====================
      !
      IF(lwp) WRITE(numout,*)
      IF(lwp) WRITE(numout,*) '              dtacof : Global domain of ORCA'
      IF(lwp) WRITE(numout,*) '              ------------------------------'
      !
      presto(:,:,:) = 0._wp
      !
      IF( kn_hdmp >= 0 ) THEN      !  Damping poleward of 'nn_hdmp' degrees  !
         !                        !-----------------------------------------!
         IF(lwp) WRITE(numout,*)
         IF(lwp) WRITE(numout,*) '              Damping poleward of ', kn_hdmp, ' deg.'
         !
         CALL iom_open ( 'dist.coast.nc', icot, ldstop = .FALSE. )
         !
         IF( icot > 0 ) THEN          ! distance-to-coast read in file
            CALL iom_get  ( icot, jpdom_global, 'Tcoast', zdct )
            CALL iom_close( icot )
         ELSE                         ! distance-to-coast computed and saved in file (output in zdct)
            CALL cofdis( zdct )
         ENDIF

         !                            ! Compute arrays resto
         zinfl = rn_zinfl                  ! distance of influence for damping term
         zlat0 = rn_zlat0                  ! latitude strip where resto decreases
         zlat1 = REAL( kn_hdmp )           ! resto = 0 between -zlat1 and zlat1
         zlat2 = zlat1 + zlat0             ! resto increases from 0 to 1 between |zlat1| and |zlat2|

         IF ( kn_hdmp > 0 ) THEN
         DO_2D(nn_hls, nn_hls, nn_hls, nn_hls ) 
        !DO_2D(0,0,0,0)
              zlat = ABS( gphit(ji,jj) )
              IF ( zlat1 <= zlat .AND. zlat <= zlat2 ) THEN
                 presto(ji,jj,1) = 0.5_wp * (  1._wp - COS( rpi*(zlat-zlat1)/zlat0 )  )
              ELSEIF ( zlat > zlat2 ) THEN
                 presto(ji,jj,1) = 1._wp
              ENDIF
            END_2D
         ENDIF

         IF ( kn_hdmp == 0 ) presto(:,:,1) = 1._wp

         IF ( esc_pole_dmp == 1 ) THEN      ! no pole 
          DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
                  zlat = ABS(gphit(ji,jj))
                  IF ( zlat < 65._wp .AND. zlat > 60._wp ) THEN
                     presto(ji,jj,:) = 0.5_wp * (  1._wp - COS(rpi*(65._wp-zlat)/5._wp )  ) 
                  ENDIF
                  IF ( zlat > 65._wp ) THEN
                     presto(ji,jj,:) = 0._wp
                  ENDIF
          END_2D
         ENDIF


         IF ( kn_hdmp == 20 ) THEN       ! North Indian ocean (20N/30N x 45E/100E) : resto=0
          DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
                  zlat = gphit(ji,jj)
                  zlon = MOD( glamt(ji,jj), 360._wp )
                  IF ( zlat1 < zlat .AND. zlat < zlat2 .AND. 45._wp < zlon .AND. zlon < 100._wp ) THEN
                     presto(ji,jj,1) = 0._wp
                  ENDIF
          END_2D
         ENDIF

         zsdmp = 1._wp / ( pn_surf * rday )
         zbdmp = 1._wp / ( pn_bot  * rday )
         DO_3D(nn_hls, nn_hls, nn_hls, nn_hls,2,jpk )
         !DO_3D(0,0,0,0,1,jpkm1)
                  zdct(ji,jj,jk) = MIN( zinfl, zdct(ji,jj,jk) )
                  !   ... Decrease the value in the vicinity of the coast
                  presto(ji,jj,jk) = presto(ji,jj,1 ) * 0.5_wp * (  1._wp - COS( rpi*zdct(ji,jj,jk)/zinfl)  )
                  !   ... Vertical variation from zsdmp (sea surface) to zbdmp (bottom)
                  presto(ji,jj,jk) = presto(ji,jj,jk) * (  zbdmp + (zsdmp-zbdmp) * EXP(-gdept_0(ji,jj,jk)/pn_dep)  )
         END_3D
         !
      ENDIF

      !                                  ! =========================
      !                                  !  Med and Red Sea damping    (ORCA configuration only)
      !                                  ! =========================
      IF( (cn_cfg == "orca" .OR. cn_cfg == "ORCA") .AND. ( kn_hdmp >= 0 .OR. kn_hdmp == -1 ) ) THEN


     !    !
     !    zmrs(:,:) = 0._wp
     !    !
         SELECT CASE ( nn_cfg )
     !    !                                           ! =======================
     !    CASE ( 4 )                                  !  ORCA_R4 configuration
     !       !                                        ! =======================
     !       ij0 =  50   ;   ij1 =  56                    ! Mediterranean Sea

     !       ii0 =  81   ;   ii1 =  91   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ij0 =  50   ;   ij1 =  55
     !       ii0 =  75   ;   ii1 =  80   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ij0 =  52   ;   ij1 =  53
     !       ii0 =  70   ;   ii1 =  74   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ! Smooth transition from 0 at surface to 1./rday at the 18th level in Med and Red Sea
     !       DO jk = 1, 17
     !          zhfac (jk) = 0.5_wp * (  1._wp - COS( rpi * REAL(jk-1,wp) / 16._wp )  ) / rday
     !       END DO
     !       DO jk = 18, jpkm1
     !          zhfac (jk) = 1._wp / rday
     !       END DO
     !       !                                        ! =======================
     !    CASE ( 2 )                                  !  ORCA_R2 configuration
     !       !                                        ! =======================
     !       ij0 =  96   ;   ij1 = 110                    ! Mediterranean Sea
     !       ii0 = 157   ;   ii1 = 181   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ij0 = 100   ;   ij1 = 110
     !       ii0 = 144   ;   ii1 = 156   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ij0 = 100   ;   ij1 = 103
     !       ii0 = 139   ;   ii1 = 143   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       !
     !       ij0 = 101   ;   ij1 = 102                    ! Decrease before Gibraltar Strait
     !       ii0 = 139   ;   ii1 = 141   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0._wp
     !       ii0 = 142   ;   ii1 = 142   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp / 90._wp
     !       ii0 = 143   ;   ii1 = 143   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.40_wp
     !       ii0 = 144   ;   ii1 = 144   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.75_wp
     !       !
     !       ij0 =  87   ;   ij1 =  96                    ! Red Sea
     !       ii0 = 147   ;   ii1 = 163   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       !
     !       ij0 =  91   ;   ij1 =  91                    ! Decrease before Bab el Mandeb Strait
     !       ii0 = 153   ;   ii1 = 160   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.80_wp
     !       ij0 =  90   ;   ij1 =  90
     !       ii0 = 153   ;   ii1 = 160   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.40_wp
     !       ij0 =  89   ;   ij1 =  89
     !       ii0 = 158   ;   ii1 = 160   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp / 90._wp
     !       ij0 =  88   ;   ij1 =  88
     !       ii0 = 160   ;   ii1 = 163   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0._wp
     !       ! Smooth transition from 0 at surface to 1./rday at the 18th level in Med and Red Sea
     !       DO jk = 1, 17
     !          zhfac (jk) = 0.5_wp * (  1._wp - COS( rpi * REAL(jk-1,wp) / 16._wp )  ) / rday
     !       END DO
     !       DO jk = 18, jpkm1
     !          zhfac (jk) = 1._wp / rday
     !       END DO
     !       !                                        ! =======================
     !    CASE ( 05 )                                 !  ORCA_R05 configuration
     !       !                                        ! =======================
     !       ii0 = 568   ;   ii1 = 574                    ! Mediterranean Sea
     !       ij0 = 324   ;   ij1 = 333   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       ii0 = 575   ;   ii1 = 658
     !       ij0 = 314   ;   ij1 = 366   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       !
     !       ii0 = 641   ;   ii1 = 651                    ! Black Sea (remaining part
     !       ij0 = 367   ;   ij1 = 372   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       !
     !       ij0 = 324   ;   ij1 = 333                    ! Decrease before Gibraltar Strait
     !       ii0 = 565   ;   ii1 = 565   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp / 90._wp
     !       ii0 = 566   ;   ii1 = 566   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.40_wp
     !       ii0 = 567   ;   ii1 = 567   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 0.75_wp
     !       !
     !       ii0 = 641   ;   ii1 = 665                    ! Red Sea
     !       ij0 = 270   ;   ij1 = 310   ;   zmrs( mi0(ii0):mi1(ii1) , mj0(ij0):mj1(ij1) ) = 1._wp
     !       !
     !       ii0 = 666   ;   ii1 = 675                    ! Decrease before Bab el Mandeb Strait
     !       ij0 = 270   ;   ij1 = 290
     !       DO ji = mi0(ii0), mi1(ii1)
     !          zmrs( ji , mj0(ij0):mj1(ij1) ) = 0.1_wp * ABS( FLOAT(ji - mi1(ii1)) )
     !       END DO
     !       zsdmp = 1._wp / ( pn_surf * rday )
     !       zbdmp = 1._wp / ( pn_bot  * rday )
     !       DO jk = 1, jpk
     !          zhfac(jk) = (  zbdmp + (zsdmp-zbdmp) * EXP( -gdept_0(1,1,jk)/pn_dep )  )
     !       END DO
     !       !                                       ! ========================
         CASE ( 025 )                               !  ORCA_R025 configuration
            !                                       ! ========================
            WRITE(numout,*) '              ORCA configuration: Removing damping in Black Sea for 025'

            ii0 = 1253   ;   ii1 = 1320                    ! Black  Sea 
            ij0 = 715   ;   ij1 = 776   ;  presto(mi0(ii0):mi1(ii1),mj0(ij0):mj1(ij1),: ) = 0._wp
            WRITE(numout,*) '              ORCA configuration: Removing damping in Caspian Sea for 025'

            ii0 = 1330  ;   ii1 = 1440                    ! Black  Sea
            ij0 = 674   ;   ij1 = 824   ;  presto(mi0(ii0):mi1(ii1),mj0(ij0):mj1(ij1),: ) = 0._wp



     !       zmrs(:,:) = 0._wp
     !       !
         END SELECT

     !    DO jk = 1, jpkm1
     !       presto(:,:,jk) = zmrs(:,:) * zhfac(jk) + ( 1._wp - zmrs(:,:) ) * presto(:,:,jk)
     !    END DO

        ! Mask resto array and set to 0 first and last levels
         presto(:,:, : ) = presto(:,:,:) * tmask(:,:,:)
         presto(:,:, 1 ) = 0._wp
         presto(:,:,jpk) = 0._wp
         WHERE(ABS(presto(:,:,:)) > 10000000000._wp) presto(:,:,:)=0._wp
         CALL lbc_lnk("dtacof",presto,'T',1.)
     !    !                         !--------------------!
      ELSE                         !     No damping     !
     !    !                         !--------------------!
         IF( kn_hdmp /= 0 ) CALL ctl_stop( 'Choose a correct value of nn_hdmp or put ln_tradmp to FALSE' )
      ENDIF

      !                            !--------------------------------!
      IF( kn_file == 1 ) THEN      !  save damping coef. in a file  !
         !                         !--------------------------------!
         IF(lwp) WRITE(numout,*) '              create damping.coeff.nc file'
         IF( cdtype == 'TRA' ) cfile = 'damping.coeff'
         IF( cdtype == 'TRC' ) cfile = 'damping.coeff.trc'
         cfile = TRIM( cfile )
         CALL iom_open  ( cfile, inum0, ldwrt = .TRUE. )
         CALL iom_rstput( 0, 0, inum0, 'Resto', presto )
         CALL iom_close ( inum0 )
      ENDIF
      !
      DEALLOCATE(zhfac)
      DEALLOCATE(zmrs)
      DEALLOCATE(zdct)
      
      !IF(lwp) WRITE(numout,*) presto(:,:,10)!
      IF( ln_timing )  CALL timing_stop('dtacof')
      !
   END SUBROUTINE dtacof


   SUBROUTINE cofdis( pdct )
      !!----------------------------------------------------------------------
      !!                 ***  ROUTINE cofdis  ***
      !!
      !! ** Purpose :   Compute the distance between ocean T-points and the
      !!      ocean model coastlines. Save the distance in a NetCDF file.
      !!
      !! ** Method  :   For each model level, the distance-to-coast is
      !!      computed as follows :
      !!       - The coastline is defined as the serie of U-,V-,F-points
      !!      that are at the ocean-land bound.
      !!       - For each ocean T-point, the distance-to-coast is then
      !!      computed as the smallest distance (on the sphere) between the
      !!      T-point and all the coastline points.
      !!       - For land T-points, the distance-to-coast is set to zero.
      !!      C A U T I O N : Computation not yet implemented in mpp case.
      !!
      !! ** Action  : - pdct, distance to the coastline (argument)
      !!              - NetCDF file 'dist.coast.nc'
      !!----------------------------------------------------------------------
      USE ioipsl      ! IOipsl librairy
      !!
      REAL(wp), DIMENSION(jpi,jpj,jpk), INTENT( out ) ::   pdct   ! distance to the coastline
      !!
      INTEGER ::   ji, jj, jk, jl   ! dummy loop indices
      INTEGER ::   iju, ijt, icoast, itime, ierr, icot   ! local integers
      CHARACTER (len=32) ::   clname                     ! local name
      REAL(wp) ::   zdate0                               ! local scalar
      REAL(wp), POINTER, DIMENSION(:,:) ::  zxt, zyt, zzt, zmask
      REAL(wp), POINTER, DIMENSION(:  ) ::  zxc, zyc, zzc, zdis    ! temporary workspace
      LOGICAL , ALLOCATABLE, DIMENSION(:,:) ::  llcotu, llcotv, llcotf   ! 2D logical workspace
      !!----------------------------------------------------------------------
      !
      IF( ln_timing )  CALL timing_start('cofdis')
      !
      ALLOCATE(zmask(jpi, jpj),zxt(jpi, jpj),zyt(jpi, jpj),zzt(jpi, jpj))
      ALLOCATE(zxc(3*jpi*jpj),zyc(3*jpi*jpj),zzc(3*jpi*jpj),zdis(3*jpi*jpj))
      ALLOCATE( llcotu(jpi,jpj), llcotv(jpi,jpj), llcotf(jpi,jpj)  )
      !
      !!IF( lk_mpp    )   CALL mpp_sum( ierr )
      !!IF( ierr /= 0 )   CALL ctl_stop( 'STOP', 'cofdis: requested local arrays unavailable')

      ! 0. Initialization
      ! -----------------
      IF(lwp) WRITE(numout,*)
      IF(lwp) WRITE(numout,*) 'cofdis : compute the distance to coastline'
      IF(lwp) WRITE(numout,*) '~~~~~~'
      IF(lwp) WRITE(numout,*)
      IF( lk_mpp .AND. jpnij > 1) &
           & CALL ctl_stop('         Computation not yet implemented with key_mpp_...', &
           &               '         Rerun the code on another computer or ', &
           &               '         create the "dist.coast.nc" file using IDL' )

      pdct(:,:,:) = 0._wp
      zxt(:,:) = COS( rad * gphit(:,:) ) * COS( rad * glamt(:,:) )
      zyt(:,:) = COS( rad * gphit(:,:) ) * SIN( rad * glamt(:,:) )
      zzt(:,:) = SIN( rad * gphit(:,:) )


      ! 1. Loop on vertical levels
      ! --------------------------
      !                                                ! ===============
      DO jk = 1, jpkm1                                 ! Horizontal slab
         IF(lwp) WRITE(numout,*) ' Operating on level ', jk
         !                                             ! ===============
         ! Define the coastline points (U, V and F)
         DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
         !DO_2D(0,0,0,0)
               zmask(ji,jj) =  ( tmask(ji,jj+1,jk) + tmask(ji+1,jj+1,jk) &
                   &           + tmask(ji,jj  ,jk) + tmask(ji+1,jj  ,jk) )
               llcotu(ji,jj) = ( tmask(ji,jj,  jk) + tmask(ji+1,jj  ,jk) == 1._wp )
               llcotv(ji,jj) = ( tmask(ji,jj  ,jk) + tmask(ji  ,jj+1,jk) == 1._wp )
               llcotf(ji,jj) = ( zmask(ji,jj) > 0._wp ) .AND. ( zmask(ji,jj) < 4._wp )
         END_2D

         ! Lateral boundaries conditions
         llcotu(:, 1 ) = umask(:,  1+1  ,jk) == 1
         llcotu(:,jpj) = umask(:,jpj-1,jk) == 1
         llcotv(:, 1 ) = vmask(:,  1+1  ,jk) == 1
         llcotv(:,jpj) = vmask(:,jpj-1,jk) == 1
         llcotf(:, 1 ) = fmask(:,  1+1  ,jk) == 1
         llcotf(:,jpj) = fmask(:,jpj-1,jk) == 1

  !       IF( nperio == 1 .OR. nperio == 4 .OR. nperio == 6 ) THEN
            llcotu( 1 ,:) = llcotu(jpi-1,:)
            llcotu(jpi,:) = llcotu(  1+1  ,:)
            llcotv( 1 ,:) = llcotv(jpi-1,:)
            llcotv(jpi,:) = llcotv(  1+1  ,:)
            llcotf( 1 ,:) = llcotf(jpi-1,:)
            llcotf(jpi,:) = llcotf(  1+1  ,:)
  !       ELSE
  !          llcotu( 1 ,:) = umask(  2  ,:,jk) == 1
!            llcotu(jpi,:) = umask(jpim1,:,jk) == 1
!            llcotv( 1 ,:) = vmask(  2  ,:,jk) == 1
!            llcotv(jpi,:) = vmask(jpim1,:,jk) == 1
!            llcotf( 1 ,:) = fmask(  2  ,:,jk) == 1
!            llcotf(jpi,:) = fmask(jpim1,:,jk) == 1
!         ENDIF
!         IF( nperio == 3 .OR. nperio == 4 ) THEN
          IF(c_NFtype == 'T') THEN
            DO ji = 1, jpi-1
               iju = jpi - ji + 1
               llcotu(ji,jpj  ) = llcotu(iju,jpj-2)
               llcotf(ji,jpj-1) = llcotf(iju,jpj-2)
               llcotf(ji,jpj  ) = llcotf(iju,jpj-3)
            END DO
            DO ji = jpi/2, jpi-1
               iju = jpi - ji + 1
               llcotu(ji,jpj-1) = llcotu(iju,jpj-1)
            END DO
            DO ji = 2, jpi
               ijt = jpi - ji + 2
               llcotv(ji,jpj-1) = llcotv(ijt,jpj-2)
               llcotv(ji,jpj  ) = llcotv(ijt,jpj-3)
            END DO
         ENDIF
!         IF( nperio == 5 .OR. nperio == 6 ) THEN
          IF(c_NFtype == 'F') THEN
            DO ji = 1, jpi-1
               iju = jpi - ji
               llcotu(ji,jpj  ) = llcotu(iju,jpj-1)
               llcotf(ji,jpj  ) = llcotf(iju,jpj-2)
            END DO
            DO ji = jpi/2, jpi-1
               iju = jpi - ji
               llcotf(ji,jpj-1) = llcotf(iju,jpj-1)
            END DO
            DO ji = 1, jpi
               ijt = jpi - ji + 1
               llcotv(ji,jpj  ) = llcotv(ijt,jpj-1)
            END DO
            DO ji = jpi/2+1, jpi
               ijt = jpi - ji + 1
               llcotv(ji,jpj-1) = llcotv(ijt,jpj-1)
            END DO
         ENDIF

         ! Compute cartesian coordinates of coastline points
         ! and the number of coastline points
         icoast = 0
         DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
               IF( llcotf(ji,jj) ) THEN
                  icoast = icoast + 1
                  zxc(icoast) = COS( rad*gphif(ji,jj) ) * COS( rad*glamf(ji,jj) )
                  zyc(icoast) = COS( rad*gphif(ji,jj) ) * SIN( rad*glamf(ji,jj) )
                  zzc(icoast) = SIN( rad*gphif(ji,jj) )
               ENDIF
               IF( llcotu(ji,jj) ) THEN
                  icoast = icoast+1
                  zxc(icoast) = COS( rad*gphiu(ji,jj) ) * COS( rad*glamu(ji,jj) )
                  zyc(icoast) = COS( rad*gphiu(ji,jj) ) * SIN( rad*glamu(ji,jj) )
                  zzc(icoast) = SIN( rad*gphiu(ji,jj) )
               ENDIF
               IF( llcotv(ji,jj) ) THEN
                  icoast = icoast+1
                  zxc(icoast) = COS( rad*gphiv(ji,jj) ) * COS( rad*glamv(ji,jj) )
                  zyc(icoast) = COS( rad*gphiv(ji,jj) ) * SIN( rad*glamv(ji,jj) )
                  zzc(icoast) = SIN( rad*gphiv(ji,jj) )
               ENDIF
         END_2D

         ! Distance for the T-points
         DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
               IF( tmask(ji,jj,jk) == 0._wp ) THEN
                  pdct(ji,jj,jk) = 0._wp
               ELSE
                  DO jl = 1, icoast
                     zdis(jl) = ( zxt(ji,jj) - zxc(jl) )**2   &
                        &     + ( zyt(ji,jj) - zyc(jl) )**2   &
                        &     + ( zzt(ji,jj) - zzc(jl) )**2
                  END DO
                  pdct(ji,jj,jk) = ra * SQRT( MINVAL( zdis(1:icoast) ) )
               ENDIF
        END_2D
         !                                                ! ===============
      END DO                                              !   End of slab
      !                                                   ! ===============


      ! 2. Create the  distance to the coast file in NetCDF format
      ! ----------------------------------------------------------
      clname = 'dist.coast'
      itime  = 0
!      CALL ymds2ju( 0     , 1      , 1     , 0._wp , zdate0 )
!      CALL restini( 'NONE', jpi    , jpj   , glamt, gphit ,   &
!         &          jpk   , gdept_0, clname, itime, zdate0,   &
!         &          rdt   , icot                         )
!      CALL restput( icot, 'Tcoast', jpi, jpj, jpk, 0, pdct )
!      CALL restclo( icot )

      CALL iom_open(TRIM(clname), icot  , ldwrt = .TRUE. )
      CALL iom_rstput( 1, 1, icot, 'Tcoast'   , pdct      )
      CALL iom_close( icot )

      !
      DEALLOCATE(zxt,zyt,zzt,zmask)
      DEALLOCATE(zxc, zyc, zzc, zdis)
      DEALLOCATE( llcotu, llcotv, llcotf  )
      !
      IF( ln_timing )  CALL timing_stop('cofdis')
      !
   END SUBROUTINE cofdis
   !!======================================================================


      SUBROUTINE Shapiro_1D(rla_varin,id_np, cd_overlap, rlpa_varout, nk) !GIG
      IMPLICIT NONE
      INTEGER, INTENT(IN)                       :: id_np, nk
      REAL(wp), DIMENSION(jpi,jpj), INTENT(IN)  :: rla_varin !GIG
      CHARACTER(len=20), INTENT(IN)             :: cd_overlap !GIG
      REAL(wp), DIMENSION(jpi,jpj), INTENT(OUT) :: rlpa_varout !GIG

      REAL(wp), DIMENSION(jpi,jpj)              :: rlpa_varout_tmp
      REAL, PARAMETER                           :: rl_alpha = 1./2.    ! fixed stability coefficient (isotrope case)
      REAL, parameter                           :: rap_aniso_diff_XY=2.25 !  anisotrope case
      REAL                                      :: alphax,alphay, znum, zden,test
      INTEGER                                   :: ji, jj, jn, nn
!
!------------------------------------------------------------------------------
!
! Loop on several filter iterations

!     Global ocean case
      IF (( cd_overlap == 'MERCAT_GLOB' )   .OR.   &
          ( cd_overlap == 'REGULAR_GLOB' ) .OR.   &
          ( cd_overlap == 'ORCA_GLOB' )) THEN
             rlpa_varout(:,:) = rla_varin(:,:)
             rlpa_varout_tmp(:,:) = rlpa_varout(:,:)
!

       alphax=1./2.
       alphay=1./2.
!  Dx/Dy=rap_aniso_diff_XY  , D_ = vitesse de diffusion
!  140 passes du fitre, Lx/Ly=1.5, le rap_aniso_diff_XY correspondant est:
       IF ( rap_aniso_diff_XY .GE. 1. ) alphay=alphay/rap_aniso_diff_XY
       IF ( rap_aniso_diff_XY .LT. 1. ) alphax=alphax*rap_aniso_diff_XY

        DO jn = 1,id_np   ! number of passes of the filter
            ! DO_2D(nn_hls,nn_hls,nn_hls,nn_hls)
            DO_2D(0,0,0,0)
                  ! We crop on the coast
                   znum = rlpa_varout_tmp(ji,jj)   &
                          + 0.25*alphax*(rlpa_varout_tmp(ji-1,jj)-rlpa_varout_tmp(ji,jj))*tmask(ji-1,jj ,nk)  &
                          + 0.25*alphax*(rlpa_varout_tmp(ji+1,jj)-rlpa_varout_tmp(ji,jj))*tmask(ji+1,jj ,nk)  &
                          + 0.25*alphay*(rlpa_varout_tmp(ji ,jj-1)-rlpa_varout_tmp(ji,jj))*tmask(ji  ,jj-1,nk)  &
                          + 0.25*alphay*(rlpa_varout_tmp(ji ,jj+1)-rlpa_varout_tmp(ji,jj))*tmask(ji  ,jj+1,nk)
                   rlpa_varout(ji,jj)=znum*tmask(ji,jj,nk)+rla_varin(ji,jj)*(1.-tmask(ji,jj,nk))
            END_2D  ! end loop jj
!
!
!           Periodical condition in case of cd_overlap (global ocean)
!           - on a mercator projection grid we consider that singular point at
!           poles
!             are a mean of the values at points of the previous latitude
!           - on ORCA and regular grid we copy the values at points of the
!           previous latitude
            IF ( cd_overlap == 'MERCAT_GLOB' ) THEN
!GIG case unchecked
               rlpa_varout(1,1) = SUM(rlpa_varout(:,2)) / jpi
               rlpa_varout(jpi,jpj) = SUM(rlpa_varout(:,jpj-1)) / jpi
!            ELSE
!               call lbc_lnk(rlpa_varout, 'T', 1.) ! Boundary condition
            ENDIF
            rlpa_varout_tmp(:,:) = rlpa_varout(:,:)
         ENDDO  ! end loop jn
      ENDIF

!
END SUBROUTINE Shapiro_1D

END MODULE tradmp
