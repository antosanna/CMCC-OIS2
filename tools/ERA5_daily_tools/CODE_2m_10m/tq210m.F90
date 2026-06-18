      PROGRAM tq210m

      IMPLICIT NONE

      REAL*8, ALLOCATABLE, DIMENSION(:,:)   :: sst, t2m, q2m, t10m, q10m, u10m, v10m, qsat, dU, mask
      REAL*8, ALLOCATABLE, DIMENSION(:)     :: lons, lats, time_rec
      REAL*8, ALLOCATABLE, DIMENSION(:,:,:) :: t10m_mrg, q10m_mrg
      REAL*8  :: zcoef_qsatw
      INTEGER :: nx, ny, jt, nt, jpi, jpj, ii, jj
      INTEGER :: nc0, nc1, nc2, nc3, nc4, nc5, nc6, nc7, nc8, id0, id1, id2, id3, id4, id5, id6, id7, id8
      CHARACTER(LEN=100) :: Tinf, Qinf, Uinf, Vinf, SSTinf, MSKin, Toutf, Qoutf, MSKinf
      CHARACTER(LEN=200) :: unitsname, calname
      REAL*8, PARAMETER  :: rhoa =    1.22        ! air density
      COMMON /DOMAIN/ jpi, jpj


      nc0 = -999 ; id0 = -999
      nc1 = -999 ; id1 = -999
      nc2 = -999 ; id2 = -999
      nc3 = -999 ; id3 = -999
      nc4 = -999 ; id4 = -999
      nc5 = -999 ; id5 = -999
      nc6 = -999 ; id6 = -999
      nc7 = -999 ; id7 = -999
      nc8 = -999 ; id8 = -999

      !Input files
      CALL GETARG(1,Tinf) 
      CALL GETARG(2,Qinf)
      CALL GETARG(3,Uinf)
      CALL GETARG(4,Vinf)
      CALL GETARG(5,SSTinf)
      CALL GETARG(6,MSKinf)

      Tinf=trim(Tinf)
      Qinf=trim(Qinf)
      Uinf=trim(Uinf)
      Vinf=trim(Vinf)      
      SSTinf=trim(SSTinf)
      MSKinf=trim(MSKinf)

      !Output files for 10m T and Q
      Toutf = trim( Tinf(1:6)//"t10m"//Tinf(10:24) )
      Qoutf = trim( Qinf(1:6)//"q10m"//Qinf(10:24) )

      CALL Read_Dimensions(Tinf,nx,ny,nt)
      WRITE(*,*) ' DIMENSIONS ARE ', nx, ny, nt
      jpi=nx
      jpj=ny


      ALLOCATE ( t10m_mrg(nx, ny, nt),&
                 q10m_mrg(nx, ny, nt),&
                 lons(nx), lats(ny), mask(nx, ny), time_rec(nt))

      WRITE(*,*) ' Reading lon: '
      CALL Read_Field1st(Qinf,'lon',nx,lons,nc6,id6)
      WRITE(*,*) ' Reading lat: '
      CALL Read_Field1st(Tinf,'lat',ny,lats,nc7,id7)
      WRITE(*,*) ' Reading time: '
      CALL Read_Field1st_time(Tinf,'time',nt,time_rec,nc8,id8,unitsname,calname)

      write(*,*) lats(2),lons(2) 

      !WRITE(*,*) ' '
      !WRITE(*,*) '     Reading MASK file: '
      !CALL Read_Field2st(MSKinf,'mask',nx,ny,jt,mask,nc0,id0)

!      nt=10

      ALLOCATE( t2m( nx, ny),&
                  q2m( nx, ny),&
                  t10m( nx, ny),&
                  q10m( nx, ny),&
                  u10m( nx, ny),&
                  v10m( nx, ny),&
                  sst(nx, ny),&
                  qsat(nx, ny),&
                  dU(nx, ny))

      DO jt = 1, nt

        t2m=0._8
        q2m=0._8
        t10m=0._8
        q10m=0._8
        u10m=0._8
        v10m=0._8
        sst=0._8
        qsat=0._8
        dU=0._8

!        WRITE(*,*) ' For record: ', jt, ' over ', nt
!        WRITE(*,*) ' '
!        WRITE(*,*) '     Reading T2M  for record: ',jt
        CALL Read_Field2st(Tinf,'t2m',nx,ny,jt,t2m,nc1,id1)

!        WRITE(*,*) ' '
!        WRITE(*,*) '     Reading Q2M  for record: ',jt
        CALL Read_Field2st(Qinf,'q2m',nx,ny,jt,q2m,nc2,id2)

!        WRITE(*,*) ' '
!        WRITE(*,*) '     Reading U10M for record: ',jt
        CALL Read_Field2st(Uinf,'u10m',nx,ny,jt,u10m,nc3,id3)

!        WRITE(*,*) ' '
!        WRITE(*,*) '     Reading V10M for record: ',jt
        CALL Read_Field2st(Vinf,'v10m',nx,ny,jt,v10m,nc4,id4)

        dU(:,:) = SQRT(  u10m(:,:) * u10m(:,:)   &
         &             + v10m(:,:) * v10m(:,:)  )

!        WRITE(*,*) ' '
!        WRITE(*,*) '     Reading SST  for record: ',jt
        CALL Read_Field2st(SSTinf,'sst',nx,ny,jt,sst,nc5,id5)

        zcoef_qsatw = 0.98 * 640380. / rhoa

        Block1: where (abs(sst(:,:)) .gt. 400.)
               sst(:,:) = 0.
        elsewhere
            sst(:,:)= sst(:,:)
        end where Block1

        Block2: where (sst(:,:) .ne. 0.)
               qsat(:,:) = zcoef_qsatw * EXP( -5107.4 / sst(:,:) )
        elsewhere
            qsat(:,:)=0.
        end where Block2

        CALL tq10m(2._8, 10._8, sst, t2m, qsat, q2m, dU, t10m, q10m)

        WRITE(*,*) 'Done estimating t10m and q10m for : ',jt,' over ',nt

        t10m_mrg(:,:,jt) = t10m(:,:)
        q10m_mrg(:,:,jt) = q10m(:,:)

      ENDDO

      DEALLOCATE( t2m,&
                  q2m,&
                  t10m,&
                  q10m,&
                  u10m,&
                  v10m,&
                  sst,&
                  qsat,&
                  dU)

      CALL write_q10m(Qoutf,nx,ny,nt,3,q10m_mrg,lons,lats,time_rec,unitsname,calname)
      WRITE(*,*) 'Output file written for Humidity at 10m :: ',Qoutf
      CALL write_t10m(Toutf,nx,ny,nt,3,t10m_mrg,lons,lats,time_rec,unitsname,calname)
      WRITE(*,*) 'Output file written for Temperature at 10m :: ',Toutf

      DEALLOCATE( t10m_mrg,&
                  q10m_mrg, lons, lats)

      END PROGRAM tq210m


      SUBROUTINE tq10m(zt, zu, sst, T_zt, q_sat_in, q_zt, dU, T_zu, q_zu)

      INTEGER jpi, jpj, ii, jj
      COMMON /DOMAIN/ jpi, jpj
      REAL*8, INTENT(in   )                     ::   zt       ! height for T_zt and q_zt                   [m]
      REAL*8, INTENT(in   )                     ::   zu       ! heightfor dU                              [m]
      REAL*8, INTENT(in   ), DIMENSION(jpi,jpj) ::   sst      ! seasurface temperature              [Kelvin]
      REAL*8, INTENT(in   ), DIMENSION(jpi,jpj) ::   T_zt     !potential air temperature            [Kelvin]
      REAL*8, INTENT(in   ), DIMENSION(jpi,jpj) ::   q_sat_in    ! seasurface specific humidity         [kg/kg]
      REAL*8, INTENT(in   ), DIMENSION(jpi,jpj) ::   q_zt     !specific air humidity                 [kg/kg]
      REAL*8, INTENT(in   ), DIMENSION(jpi,jpj) ::   dU      !relative wind module at zu            [m/s]
      REAL*8,                DIMENSION(jpi,jpj) ::   Cd       !transfer coefficient for momentum         (tau)
      REAL*8,                DIMENSION(jpi,jpj) ::   Ch       !transfer coefficient for sensible heat (Q_sens)
      REAL*8,                DIMENSION(jpi,jpj) ::   Ce       !transfert coefficient for evaporation   (Q_lat)
      REAL*8, INTENT(out ), DIMENSION(jpi,jpj) ::   T_zu     ! airtemp. shifted at zu                     [K]
      REAL*8, INTENT(out ), DIMENSION(jpi,jpj) ::   q_zu     ! spec.hum.  shifted at zu               [kg/kg]
      !
      REAL*8  ::   denom1, denom2
      INTEGER ::   j_itt
      INTEGER , PARAMETER ::   nb_itt = 5       ! number of itterations
      REAL*8, PARAMETER ::  vkarmn   =    0.4_8        !: von Karman constant
      REAL*8, PARAMETER ::   grav  = 9.80665_8     !: gravity [m/s2]
      LOGICAL ::   l_zt_equal_zu = .FALSE.      ! if q and t are givenat different height than U
      REAL*8, DIMENSION(:,:), POINTER ::   U_zu          ! relativewind at zu                            [m/s]
      REAL*8, DIMENSION(:,:), POINTER ::   Ce_n10        ! 10m neutrallatent coefficient
      REAL*8, DIMENSION(:,:), POINTER ::   Ch_n10        ! 10m neutralsensible coefficient
      REAL*8, DIMENSION(:,:), POINTER ::   sqrt_Cd_n10   ! root squareof Cd_n10
      REAL*8, DIMENSION(:,:), POINTER ::   sqrt_Cd       ! root squareof Cd
      REAL*8, DIMENSION(:,:), POINTER ::   zeta_u        ! stabilityparameter at height zu
      REAL*8, DIMENSION(:,:), POINTER ::   zeta_t        ! stabilityparameter at height zt
      REAL*8, DIMENSION(:,:), POINTER ::   zpsi_h_u, zpsi_m_u
      REAL*8, DIMENSION(:,:), POINTER ::   ztmp0, ztmp1, ztmp2, zeta_tmp0, q_sat
      REAL*8, DIMENSION(:,:), POINTER ::   stab          ! 1ststability test integer


      ALLOCATE( U_zu( jpi, jpj),&
                Ce_n10( jpi, jpj),&
                Ch_n10( jpi, jpj),&
                sqrt_Cd_n10( jpi, jpj),&
                sqrt_Cd( jpi, jpj),&
                zeta_u( jpi, jpj),&
                stab(jpi, jpj),&
                zpsi_h_u(jpi, jpj),&
                zpsi_m_u(jpi, jpj),&
                ztmp0(jpi, jpj),&
                ztmp1(jpi, jpj),&
                ztmp2(jpi, jpj),&
                zeta_tmp0(jpi,jpj),&
                zeta_t(jpi,jpj),&
                q_sat(jpi,jpj))


      Block3: where (dU(:,:) .lt. 0.5_8)
             U_zu(:,:) = 0.5_8
      elsewhere
             U_zu(:,:) = dU(:,:)
      end where Block3

      Block4: where (q_sat_in(:,:) .gt. 200._8)
             q_sat(:,:) = 0.
      elsewhere
             q_sat(:,:) = q_sat_in(:,:)
      end where Block4

      ztmp0 = T_zt*(1. + 0.608*q_zt) - sst*(1. + 0.608*q_sat) ! air-sea difference of virtual pot. temp. at zt
      stab  = 0.5 + sign(0.5,ztmp0)

      call cd_neutral_10m(U_zu,ztmp0)

      sqrt_Cd_n10 = SQRT( ztmp0 )
      Ce_n10  = 1.e-3*( 34.6 * sqrt_Cd_n10 )
      Ch_n10  = 1.e-3*sqrt_Cd_n10*(18.*stab + 32.7*(1. - stab))

      !! Initializing transf. coeff. with their first guess neutral
      !equivalents :
      Cd = ztmp0   ;   Ce = Ce_n10   ;   Ch = Ch_n10   ;   sqrt_Cd = sqrt_Cd_n10

      !! Initializing values at z_u with z_t values:
      T_zu = T_zt   ;   q_zu = q_zt

      !!  * Now starting iteration loop
      DO j_itt=1, nb_itt
         !
         ztmp1 = T_zu - sst   ! Updating air/sea differences
         ztmp2 = q_zu - q_sat

         ! Updating turbulent scales :   (L&Y 2004 eq. (7))
         
         ztmp1  = Ch/sqrt_Cd*ztmp1    ! theta*
         ztmp2  = Ce/sqrt_Cd*ztmp2    ! q*

         ztmp0 = T_zu*(1. + 0.608*q_zu) ! virtual potential temperature at zu

         ! Estimate the inverse of Monin-Obukov length (1/L) at height
         ! zu:

         ztmp0 =  (vkarmn*grav/ztmp0*(ztmp1*(1.+0.608*q_zu) + 0.608*T_zu*ztmp2)) / (Cd*U_zu*U_zu)

         !! Stability parameters :
         zeta_u   = zu*ztmp0   ;  zeta_u = sign( min(abs(zeta_u),10.0), zeta_u )

         call psi_h( zeta_u,zeta_tmp0 )
         zpsi_h_u = zeta_tmp0

         call psi_m( zeta_u, zeta_tmp0)
         zpsi_m_u = zeta_tmp0

         !! Shifting temperature and humidity at zu (L&Y 2004 eq.
         !(9b-9c))

         zeta_t = zt*ztmp0 ;  zeta_t = sign( min(abs(zeta_t),10.0), zeta_t )

         call psi_h( zeta_t,zeta_tmp0 )
         zeta_t = zeta_tmp0
         stab = LOG(zu/zt) - zpsi_h_u + zeta_t  ! stab just used as temp array!!!
         T_zu = T_zt + ztmp1/vkarmn*stab    ! ztmp1 is still theta*
         q_zu = q_zt + ztmp2/vkarmn*stab    ! ztmp2 is still q*
         q_zu = max(0., q_zu)

!           ! Update neutral wind speed at 10m and neutral Cd at 10m (L&Y
!           ! 2004 eq. 9a)...
!           !   In very rare low-wind conditions, the old way of
!           !   estimating the
!           !   neutral wind speed at 10m leads to a negative value that
!           !   causes the code
!           !   to crash. To prevent this a threshold of 0.25m/s is
!           !   imposed.
         ztmp0 = MAX( 0.25 , U_zu/(1. + sqrt_Cd_n10/vkarmn*(LOG(zu/10.) - zpsi_m_u)) ) !  U_n10
         call cd_neutral_10m(ztmp0,ztmp1)
         ztmp0 = ztmp1 ! Cd_n10
         sqrt_Cd_n10 = sqrt(ztmp0)

         Ce_n10  = 1.e-3 * (34.6 * sqrt_Cd_n10)                     !           CL&Y 2004 eq. (6b)
         stab    = 0.5 + sign(0.5,zeta_u)                           ! update stability
         Ch_n10  = 1.e-3*sqrt_Cd_n10*(18.*stab + 32.7*(1. - stab))  !           CL&Y 2004 eq. (6c-6d)

         !! Update of transfer coefficients:
         ztmp1 = 1. + sqrt_Cd_n10/vkarmn*(LOG(zu/10.) - zpsi_m_u)   ! L&Y 2004 eq. (10a)
         Cd      = ztmp0 / ( ztmp1*ztmp1 )
         sqrt_Cd = SQRT( Cd )
         !
         ztmp0 = (LOG(zu/10.) - zpsi_h_u) / vkarmn / sqrt_Cd_n10
         ztmp2 = sqrt_Cd / sqrt_Cd_n10
         ztmp1 = 1. + Ch_n10*ztmp0
         Ch  = Ch_n10*ztmp2 / ztmp1  ! L&Y 2004 eq. (10b)
         !
         ztmp1 = 1. + Ce_n10*ztmp0
         Ce  = Ce_n10*ztmp2 / ztmp1  ! L&Y 2004 eq. (10c)
          !
!      write(*,*)T_zu(1000,200), Q_zu(1000,200)
      END DO
      DEALLOCATE( U_zu,&
                Ce_n10,&
                Ch_n10,&
                sqrt_Cd_n10,&
                sqrt_Cd,&
                zeta_u,&
                stab,&
                zpsi_h_u,&
                zpsi_m_u,&
                ztmp0,&
                ztmp1,&
                ztmp2)
      RETURN
      END SUBROUTINE tq10m

      SUBROUTINE cd_neutral_10m( zw10, outzw10 ) 
       !!----------------------------------------------------------------------
       !! Estimate of the neutral drag coefficient at 10m as a function
       !! of neutral wind  speed at 10m
       !!
       !! Origin: Large & Yeager 2008 eq.(11a) and eq.(11b)
       !!
       !! Author: L. Brodeau, june 2014
       !!----------------------------------------------------------------------
       INTEGER jpi, jpj,ii,jj
       COMMON /DOMAIN/ jpi, jpj
       REAL*8, DIMENSION(jpi,jpj), INTENT(in) ::   zw10           !scalar wind speed at 10m (m/s)
       REAL*8, DIMENSION(jpi,jpj), INTENT(inout) ::   outzw10 !scalar wind speed at 10m (m/s)
       !
       REAL*8, DIMENSION(:,:), POINTER ::   rgt33, tmp
       !!----------------------------------------------------------------------
       !
       ALLOCATE( rgt33( jpi, jpj))
       ALLOCATE( tmp( jpi, jpj))
       !
       !! When wind speed > 33 m/s => Cyclone conditions => special
       !treatment
       
        do ii = 1,jpi
        do jj = 1,jpj
           if (zw10(ii,jj) .eq. 0.) write(*,*)'zw10, ii,jj',ii,jj
        enddo
        enddo


       rgt33 = 0.5_8 + SIGN( 0.5_8, (zw10 - 33._8) )   ! If zw10 < 33. => 0, else => 1
       tmp = 1.e-3 * ( &
         &       (1._8 - rgt33)*( 2.7_8/zw10 + 0.142_8 + zw10/13.09_8 - 3.14807E-10*zw10**6) & ! zw10< 33.
         &      + rgt33         *      2.34_8   )
       outzw10=tmp
       DEALLOCATE(rgt33)
       DEALLOCATE(tmp)
       RETURN
       !
       END SUBROUTINE cd_neutral_10m

       SUBROUTINE psi_h( pta, out_pta )    !! Psis, L&Y 2004 eq. (8c), (8d), (8e)
       !-------------------------------------------------------------------------------
       ! universal profile stability function for temperature and
       ! humidity
       !-------------------------------------------------------------------------------
       INTEGER jpi, jpj
       COMMON /DOMAIN/ jpi, jpj
       REAL*8, DIMENSION(jpi,jpj), INTENT(in) ::   pta
       REAL*8, DIMENSION(jpi,jpj), INTENT(inout) ::   out_pta
       !
       REAL*8, DIMENSION(:,:), POINTER        ::   X2, X, stabit
       !-------------------------------------------------------------------------------
       !
       ALLOCATE( X2( jpi, jpj),&
              X( jpi, jpj),&
              stabit( jpi, jpj))
       !
       X2 = SQRT( ABS( 1. - 16.*pta ) )   ;   X2 = MAX( X2 , 1. )   ; X    = SQRT( X2 )
       stabit = 0.5 + SIGN( 0.5 , pta )
       out_pta = -5.*pta*stabit   &
!    Stable
          &    + (1. - stabit)*(2.*LOG( (1. + X2)*0.5 ))
!    Unstable
       !
       DEALLOCATE(X2)
       DEALLOCATE(X)
       DEALLOCATE(stabit)
       RETURN
          !
       END SUBROUTINE psi_h

       !!======================================================================

       SUBROUTINE psi_m( pta, out_pta)   !! Psis, L&Y 2004 eq. (8c), (8d), (8e)
       !-------------------------------------------------------------------------------
       ! universal profile stability function for momentum
       !-------------------------------------------------------------------------------
       INTEGER jpi, jpj
       COMMON /DOMAIN/ jpi, jpj
       REAL*8, DIMENSION(jpi,jpj), INTENT(in) :: pta
       REAL*8, DIMENSION(jpi,jpj), INTENT(inout) :: out_pta
       !
       REAL*8, DIMENSION(:,:), POINTER        :: X2, X, stabit
       REAL*8, PARAMETER                      :: rpi = 3.141592653589793_8 !: pi
       !-------------------------------------------------------------------------------
       !
       ALLOCATE( X2( jpi, jpj),&
              X( jpi, jpj),&
              stabit( jpi, jpj))
       !
       X2 = SQRT( ABS( 1. - 16.*pta ) )  ;  X2 = MAX( X2 , 1. )   ;   X = SQRT( X2 )
       stabit = 0.5 + SIGN( 0.5 , pta )
       out_pta = -5.*pta*stabit  & ! Stable
         &    + (1. - stabit)*(2.*LOG((1. + X)*0.5) + LOG((1. + X2)*0.5) - 2.*ATAN(X) + rpi*0.5)  ! Unstable
       !
       DEALLOCATE(X2)
       DEALLOCATE(X)
       DEALLOCATE(stabit)
       RETURN
       !
       END SUBROUTINE psi_m
