
C***********************************************************************
C   Portions of Models-3/CMAQ software were developed or based on      *
C   information from various groups: Federal Government employees,     *
C   contractors working on a United States Government contract, and    *
C   non-Federal sources (including research institutions).  These      *
C   research institutions have given the Government permission to      *
C   use, prepare derivative works, and distribute copies of their      *
C   work in Models-3/CMAQ to the public and to permit others to do     *
C   so.  EPA therefore grants similar permissions for use of the       *
C   Models-3/CMAQ software, but users are requested to provide copies  *
C   of derivative works to the Government without restrictions as to   *
C   use by others.  Users are responsible for acquiring their own      *
C   copies of commercial software associated with Models-3/CMAQ and    *
C   for complying with vendor requirements.  Software copyrights by    *
C   the MCNC Environmental Modeling Center are used with their         *
C   permissions subject to the above restrictions.                     *
C***********************************************************************

C RCS file, release, date & time of last delta, author, state, [and locker]
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/hdiff/multiscale/hdiff.F,v 1.1.1.1 2005/09/09 18:56:06 sjr Exp $ 

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE HDIFF ( JDATE, JTIME, TSTEP )

C-----------------------------------------------------------------------
C Function:
C   Horizontal diffusion with constant eddy diffusivity - gen. coord.
C   The process time step is set equal to TSTEP(2). Boundary concentrations
C   are set using a Dirichlet (no flux) condition
      
C Preconditions:
C   Dates and times represented YYYYDDD:HHMMSS.
C   No "skipped" dates and times.  All boundary input variables have the
C   same boundary perimeter structure with a thickness of 1
C   CGRID in ppm units or micro-g/m**3, #/m**3 for aerosols
      
C Subroutines and functions called:
C   INIT3, TIME2SEC, CGRID_MAP, NEXTIME, RHO_J, 
C   HCDIFF3D
 
C Revision history:
C   Jeff - 5 Nov 97, 1 Jan 98
C   DWB  - 1 Feb 98, use simple B/C (no conc gradient at domain boundary)

C   David Wong Sep. 1998
C     -- parallelized the code
C     -- removed the intermediate constant CRHOJ_Q and placed the answer of
C        the calculation directly into CGRID. Removed the next immediate
C        loop completely.

C   David Wong 1/19/99
C      -- add a loop_index call
C      -- change loop index ending point to avoid accessing invalid region.
C         (reason to do this is to prevent using boundary data from PINTERP,
C          which sets pseudo-boundary data to 0)
 
C   Daewon Byun 10/10/2000
C      -- generalized 3d horizontal diffusivity module
C      -- accomdates 3d hdiff values

C    15 Dec 00 J.Young: PE_COMM3 -> Dave Wong's f90 stenex COMM 
C     6 Aug 01 J.Young: Use HGRD_DEFN
C     5 Mar 03 J.Young: move CGRID to module

C    25 Mar 04 G.Hammond: RK11/RK22 ghost cell updates moved outside main loop;
C                         use explicit boundary arrays for CGRID ghost cells;
C                         use SNL's "swap3d".

C  28 Oct 2005: Jeff Young - layer dependent advection, dyn. vert. layers
C-----------------------------------------------------------------------
      
      USE CGRID_DEFN            ! inherits GRID_CONF and CGRID_SPCS
      USE SE_MODULES         ! stenex
!     USE SUBST_UTIL_MODULE     ! stenex
!     USE SUBST_COMM_MODULE     ! stenex

      

      IMPLICIT NONE

C Includes:

!     INCLUDE SUBST_HGRD_ID     ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID     ! vertical dimensioning parameters
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/GC_SPC.EXT"      ! gas chemistry species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/AE_SPC.EXT"      ! aerosol species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/NR_SPC.EXT"      ! non-reactive species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/TR_SPC.EXT"      ! tracer species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/GC_DIFF.EXT"     ! gas chem diffusion species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/AE_DIFF.EXT"     ! aerosol diffusion species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/NR_DIFF.EXT"     ! non-react diffusion species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/TR_DIFF.EXT"     ! tracer diffusion species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/CONST.EXT"       ! constants
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PARMS3.EXT"     ! I/O parameters definitions
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/FDESC3.EXT"     ! file header data structure
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/IODECL3.EXT"      ! I/O definitions and declarations
!     INCLUDE SUBST_COORD_ID    ! coordinate & domain definitions (req IOPARMS)
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PE_COMM.EXT"     ! PE communication displacement and direction

C Arguments:
      
      INTEGER     JDATE         ! current model date, coded YYYYDDD
      INTEGER     JTIME         ! current model time, coded HHMMSS
      INTEGER     TSTEP( 2 )    ! time step vector (HHMMSS)
                                ! TSTEP(1) = local output step
                                ! TSTEP(2) = sciproc sync. step (chem)

C External Functions not declared in IODECL3.EXT:
      
      INTEGER, EXTERNAL :: TIME2SEC, SETUP_LOGDEV
      
C Parameters:

C Advected species dimension

      INTEGER, PARAMETER :: N_SPC_DIFF = N_GC_DIFF
     &                                 + N_AE_DIFF
     &                                 + N_NR_DIFF
     &                                 + N_TR_DIFF
!    &                                 + 1       ! diff RHO_J
 
C File Variables:
 
      REAL         CONC  ( 0:NCOLS+1,0:NROWS+1 )   ! conc working array
      REAL         RHOJ  ( 0:NCOLS+1,0:NROWS+1,NLAYS ) ! density X Jacobian
      CHARACTER( 8 ), SAVE :: COMMSTR                  ! for both CONC and RHOJ
      REAL         RK11  (   NCOLS+1,NROWS+1,NLAYS )   ! RHOJ at x1 cell face
                                               ! reused as 11 eddy diff. factor
      REAL         RK22  (   NCOLS+1,NROWS+1,NLAYS )   ! RHOJ at x2 cell face
                                               ! reused as 22 eddy diff. factor
      REAL         K11BAR3D ( NCOLS+1,NROWS+1,NLAYS ) ! ave. Cx11 eddy diff
      REAL         K22BAR3D ( NCOLS+1,NROWS+1,NLAYS ) ! ave. Cx22 eddy diff
      REAL         DT                          ! diffusion time step
      REAL         CRHOJ_Q                     ! intermediate, coupled conc.


C Local Variables:

      CHARACTER( 16 ) :: PNAME = 'HDIFF'
      
      LOGICAL, SAVE :: FIRSTIME = .TRUE.

      REAL          DX1                         ! dx1 (meters)
      REAL          DX2                         ! dx2 (meters)
      REAL, SAVE :: RDX1S                       ! reciprocal dx1*dx1
      REAL, SAVE :: RDX2S                       ! reciprocal dx2*dx2
      
      REAL          DTDX1S                      ! dt/dx1**2
      REAL          DTDX2S                      ! dt/dx2**2
      REAL          DTSEC                       ! model time step in seconds
      INTEGER       NSTEPS                      ! diffusion time steps
      INTEGER       STEP                        ! FIX dt
      INTEGER       FDATE                       ! interpolation date
      INTEGER       FTIME                       ! interpolation time

      INTEGER, SAVE :: DIFF_MAP( N_SPC_DIFF )   ! global diff map to CGRID
      INTEGER, SAVE :: LOGDEV

      INTEGER      C, R, L, S, V, N            ! loop counters
      INTEGER      D2C
      INTEGER      ALLOCSTAT

      CHARACTER( 96 ) :: XMSG = ' '
     
      INTEGER MY_TEMP
      INTEGER, SAVE :: STARTROW, ENDROW
      INTEGER, SAVE :: STARTCOL, ENDCOL

      INTERFACE
         SUBROUTINE RHO_J ( JDATE, JTIME, TSTEP, RHOJ )
            IMPLICIT NONE
            INTEGER, INTENT( IN ) :: JDATE, JTIME, TSTEP( 2 )
            REAL, INTENT( OUT )   :: RHOJ( :,:,: )
         END SUBROUTINE RHO_J
!        SUBROUTINE HCDIFF3D ( JDATE, JTIME, K11BAR, K22BAR, DT )
!           IMPLICIT NONE
!           INTEGER, INTENT( IN ) :: JDATE, JTIME
!           REAL, INTENT( OUT )   :: K11BAR( :,:,: ), K22BAR( :,:,: )
!           REAL, INTENT( OUT )   :: DT
!        END SUBROUTINE HCDIFF3D
      END INTERFACE
 
C-----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN

         FIRSTIME = .FALSE.

!        LOGDEV = INIT3()
         LOGDEV = SETUP_LOGDEV()

C Get dx1 from HGRD_DEFN

         IF ( GDTYP_GD .EQ. LATGRD3 ) THEN
            DX1 = DG2M * XCELL_GD
     &          * COS( PI180*( YORIG_GD + YCELL_GD*FLOAT( GL_NROWS/2 ))) ! in m.
            DX2 = DG2M * YCELL_GD   ! in m.
            ELSE
            DX1 = XCELL_GD          ! in m.
            DX2 = YCELL_GD          ! in m.
            END IF

         RDX1S = 1.0 / ( DX1 * DX1 )
         RDX2S = 1.0 / ( DX2 * DX2 )

C Get CGRID offsets
 
         CALL CGRID_MAP( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )
 
C Create global map to CGRID
 
         S = 0
         DO V = 1, N_GC_DIFF
            S = S + 1
            DIFF_MAP( S ) = GC_STRT - 1 + GC_DIFF_MAP( V )
            END DO
         DO V = 1, N_AE_DIFF
            S = S + 1
            DIFF_MAP( S ) = AE_STRT - 1 + AE_DIFF_MAP( V )
            END DO
         DO V = 1, N_NR_DIFF
            S = S + 1
            DIFF_MAP( S ) = NR_STRT - 1 + NR_DIFF_MAP( V )
            END DO
         DO V = 1, N_TR_DIFF
            S = S + 1
            DIFF_MAP( S ) = TR_STRT - 1 + TR_DIFF_MAP( V )
            END DO
 
C Get local loop boundaries

         CALL SE_LOOP_INDEX ( 'R', 1, NROWS, 1, MY_TEMP, STARTROW, ENDROW )

         CALL SE_LOOP_INDEX ( 'C', 1, NCOLS, 1, MY_TEMP, STARTCOL, ENDCOL )

         WRITE( COMMSTR,'(4I2)' )  1, 0, 2, 0

         END IF                    ! if firstime
                                     
      DTSEC = FLOAT( TIME2SEC( TSTEP( 2 ) ) )
      FDATE = JDATE
      FTIME = JTIME
 
C Get the computational grid ( rho X Jacobian ) for this step

      CALL RHO_J ( FDATE, FTIME, TSTEP, RHOJ )

      CALL SE_COMM ( RHOJ, DSPL_N0_E0_S1_W1, DRCN_S_W, COMMSTR )

C get face values for RHOJ (assumes dx1 = dx2)

      DO L = 1, NLAYS
         DO R = STARTROW, ENDROW        !  DO R = 1, NROWS + 1
            DO C = STARTCOL, ENDCOL     !     DO C = 1, NCOLS + 1
               RK11( C,R,L ) = 0.5 * ( RHOJ( C,R,L ) + RHOJ( C-1,R,  L ) )
               RK22( C,R,L ) = 0.5 * ( RHOJ( C,R,L ) + RHOJ( C,  R-1,L ) )
               END DO
            END DO
         END DO

C Do the gridded computation for horizontal diffusion

C Get the contravariant eddy diffusivities

      CALL HCDIFF3D ( FDATE, FTIME, K11BAR3D, K22BAR3D, DT )

C get number of steps based on eddy time 
 
      NSTEPS = INT ( DTSEC / DT ) + 1
      DT = DTSEC / FLOAT( NSTEPS )
 
      WRITE( LOGDEV,1005 ) DT, NSTEPS

      DTDX1S = DT * RDX1S
      DTDX2S = DT * RDX2S

      DO L = 1, NLAYS
         DO R = STARTROW, ENDROW        !  DO R = 1, NROWS + 1
            DO C = STARTCOL, ENDCOL     !     DO C = 1, NCOLS + 1
               RK11( C,R,L ) = RK11( C,R,L ) * K11BAR3D( C,R,L )
               RK22( C,R,L ) = RK22( C,R,L ) * K22BAR3D( C,R,L )
               END DO
            END DO
         END DO

      CALL SE_COMM ( RK11, DSPL_N0_E1_S0_W0, DRCN_E )
      CALL SE_COMM ( RK22, DSPL_N1_E0_S0_W0, DRCN_N )

C Loop over species, layers, nsteps

      DO 366 S = 1, N_SPC_DIFF
         D2C = DIFF_MAP( S )

         DO 355 L = 1, NLAYS

C Load working array (CGRID is coupled, CONC is mixing ratio)

            DO 344 N = 1, NSTEPS

               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     CONC( C,R ) = CGRID( C,R,L,D2C ) / RHOJ( C,R,L )
                     END DO
                  END DO

C South boundary

               R = 1
               DO C = 1, MY_NCOLS
                  CONC( C,R-1 ) = CONC( C,R )
                  END DO

C North boundary

               R = MY_NROWS
               DO C = 1, MY_NCOLS
                  CONC( C,R+1 ) = CONC( C,R )
                  END DO

C West boundary

               C = 1
               DO R = 1, MY_NROWS
                  CONC( C-1,R ) = CONC( C,R )
                  END DO

C East boundary

               C = MY_NCOLS
               DO R = 1, MY_NROWS
                  CONC( C+1,R ) = CONC( C,R )
                  END DO

               CALL SE_COMM ( CONC, DSPL_N1_E1_S1_W1, DRCN_N_E_S_W, COMMSTR )

C Update CGRID

               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS

                     CGRID( C,R,L,D2C ) = RHOJ( C,R,L ) * CONC( C,R )
     &                                  + DTDX1S
     &                                  * ( RK11( C+1,R,L )
     &                                    * ( CONC( C+1,R ) - CONC( C,R ) )
     &                                    - RK11( C,R,L )
     &                                    * ( CONC( C,R )   - CONC( C-1,R ) ) )
     &                                  + DTDX2S
     &                                  * ( RK22( C,R+1,L )
     &                                    * ( CONC( C,R+1 ) - CONC( C,R ) )
     &                                    - RK22( C,R,L )
     &                                    * ( CONC( C,R )   - CONC( C,R-1 ) ) )

                     END DO
                  END DO

344            CONTINUE

355         CONTINUE
366      CONTINUE

      RETURN

1005  FORMAT( / 5X, 'H-eddy DT & integration steps: ', 1PE15.7, I8 )

      END