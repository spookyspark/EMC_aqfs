
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/hadv/yamo/y_yamo.F,v 1.1.1.1 2005/09/09 18:56:06 sjr Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE Y_YAMO ( FDATE, FTIME, TSTEP, LVL, BCON, YTRHOJ )

C-----------------------------------------------------------------------
C Function:
C   Advection in the horizontal plane, Y-direction first
      
C Preconditions:
      
C Subroutines and functions called:
 
C Revision history:
C  19 Jan 2004: Jeff Young
C  28 Oct 2005: Jeff Young - layer dependent advection, dyn. vert. layers
      
C-----------------------------------------------------------------------

      USE CGRID_DEFN            ! inherits GRID_CONF and CGRID_SPCS
      USE SE_MODULES         ! stenex
!     USE SUBST_COMM_MODULE     ! stenex
!     USE SUBST_UTIL_MODULE     ! stenex

      IMPLICIT NONE
      
C Includes:

!     INCLUDE SUBST_VGRD_ID     ! vertical dimensioning parameters
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/GC_SPC.EXT"      ! gas chemistry species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/GC_ADV.EXT"      ! gas chem advection species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/AE_ADV.EXT"      ! aerosol advection species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/NR_ADV.EXT"      ! non-react advection species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/TR_ADV.EXT"      ! tracer advection species and map table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/CONST.EXT"       ! constants
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PARMS3.EXT"     ! I/O parameters definitions
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/IODECL3.EXT"      ! I/O definitions and declarations
!     INCLUDE SUBST_COORD_ID    ! coordinate & domain definitions (req IOPARMS)
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PE_COMM.EXT"     ! PE communication displacement and direction

C Arguments:
      
      INTEGER     FDATE         ! current model date, coded YYYYDDD
      INTEGER     FTIME         ! current model time, coded HHMMSS
      INTEGER     TSTEP         ! time step (HHMMSS)
      INTEGER     LVL           ! layer
      REAL        BCON( NBNDY,* )       ! boundary concentrations
!     REAL        YTRHOJ( 0:NROWS,NCOLS )
      REAL        YTRHOJ( :,: ) ! subroutine argument entry as (NCOLS,NROWS+1)

C External Functions not declared in IODECL3.EXT:
      
      INTEGER, EXTERNAL :: SEC2TIME, TIME2SEC, setup_logdev
      REAL,    EXTERNAL :: ZFDBC
      
C Parameters:

C Advected species dimension

      INTEGER, PARAMETER :: N_SPC_ADV = N_GC_ADV
     &                                + N_AE_ADV
     &                                + N_NR_ADV
     &                                + N_TR_ADV
     &                                + 1       ! for advecting RHO*SqRDMT
 
C File Variables:
 
      REAL         VHAT( NCOLS+1,NROWS+1 )       ! x1-component CX-velocity

C Local Variables:

      REAL         TRRHOJ( 0:NROWS )

      CHARACTER( 16 ) :: PNAME = 'Y_YAMO'
      LOGICAL, SAVE :: FIRSTIME = .TRUE.

      integer, save :: logdev

      CHARACTER( 96 ) :: XMSG = ' '

      REAL          DX2                         ! dx1 (meters)
      INTEGER, SAVE :: ASPC                     ! RHOJ index in CGRID
      REAL          ADJFAC                      ! Yamo's adjustment - jp 11/02
      REAL          ADJFAC_L

      REAL, ALLOCATABLE, SAVE :: DSY( : ),      ! ds = DX1
     &                           VELY( : ),     ! Velocities along a column
     &                           CONY( :,: )    ! Conc's along a column
      REAL          DT                          ! TSTEP in sec
      INTEGER       ALLOCSTAT

      INTEGER, SAVE :: ADV_MAP( N_SPC_ADV )     ! global adv map to CGRID

      INTEGER      COL, ROW, SPC, VAR           ! loop counters
      INTEGER      A2C

      CHARACTER( 16 ) :: X2VEL = 'X2VEL'

      INTEGER MY_TEMP
      INTEGER, SAVE :: STARTROW, ENDROW, STARTROW2, ENDROW2, ENDROW2_LIM
      LOGICAL, SAVE :: BNDY_PE_LOY, BNDY_PE_HIY

C Statement functions:

      INTEGER, SAVE :: SFX    ! fixed parameter for southern boundary
      INTEGER, SAVE :: NFX    ! fixed parameter for northern boundary

      REAL    BCCN            ! boundary concentrations stmt fn

      INTEGER BFX             ! dummy positional parameter
      INTEGER CR              ! row or column index
      INTEGER SS              ! species index

      BCCN ( BFX, CR, SS ) = BCON( BFX + CR, SS )

C Required interface for allocatable array dummy arguments

      INTERFACE
         SUBROUTINE HCONTVEL ( FDATE, FTIME, TSTEP, LVL, UORV, UHAT )
            IMPLICIT NONE
            INTEGER,         INTENT( IN )     :: FDATE, FTIME, TSTEP, LVL
            CHARACTER( 16 ), INTENT( IN )     :: UORV
            REAL,            INTENT( OUT )    :: UHAT( :,: )
         END SUBROUTINE HCONTVEL
         SUBROUTINE HPPM ( NI, CON, VEL, DT, DS, ORI )
            IMPLICIT NONE
            INTEGER,         INTENT( IN )     :: NI
            REAL,            INTENT( IN OUT ) :: CON( :,: )
            REAL,            INTENT( IN )     :: VEL( : )
            REAL,            INTENT( IN )     :: DT
            REAL,            INTENT( IN )     :: DS ( : )
            CHARACTER,       INTENT( IN )     :: ORI
         END SUBROUTINE HPPM
      END INTERFACE
C-----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
!        logdev = init3()
         logdev = setup_logdev()

         SFX = 0
         NFX = MY_NCOLS + MY_NROWS + 3

C Get dx2 from HGRD_DEFN module

         IF ( GDTYP_GD .EQ. LATGRD3 ) THEN
            DX2 = DG2M * YCELL_GD   ! in m.
            ELSE
            DX2 = YCELL_GD          ! in m.
            END IF

         ALLOCATE ( DSY( -1:MY_NROWS+1 ),
     &              VELY(   MY_NROWS+1 ),
     &              CONY( 0:MY_NROWS+1,N_SPC_ADV ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating DSY, VELY, or CONY'
            CALL M3EXIT ( PNAME, FDATE, FTIME, XMSG, XSTAT1 )
            END IF

         DO ROW = -1, MY_NROWS + 1
            DSY ( ROW ) = DX2
            END DO

         CALL SE_COMM ( DSY, DSPL_N1_E0_S2_W0, DRCN_N_S, '1 -1' )

C Get CGRID offsets
 
         CALL CGRID_MAP( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )

         ASPC = GC_STRT - 1 + N_GC_SPCD

C Create global map to CGRID
 
         SPC = 0
         DO VAR = 1, N_GC_ADV
            SPC = SPC + 1
            ADV_MAP( SPC ) = GC_STRT - 1 + GC_ADV_MAP( VAR )
            END DO
         DO VAR = 1, N_AE_ADV
            SPC = SPC + 1
            ADV_MAP( SPC ) = AE_STRT - 1 + AE_ADV_MAP( VAR )
            END DO
         DO VAR = 1, N_NR_ADV
            SPC = SPC + 1
            ADV_MAP( SPC ) = NR_STRT - 1 + NR_ADV_MAP( VAR )
            END DO
         DO VAR = 1, N_TR_ADV
            SPC = SPC + 1
            ADV_MAP( SPC ) = TR_STRT - 1 + TR_ADV_MAP( VAR )
            END DO
 
         ADV_MAP( N_SPC_ADV ) = ASPC

         CALL SE_LOOP_INDEX ( 'R', 1, MY_NROWS, 1, MY_TEMP,
     &                           STARTROW, ENDROW )

         CALL SE_LOOP_INDEX ( 'R', 2, MY_NROWS, 1, MY_TEMP,
     &                           STARTROW2, ENDROW2 )

         CALL SE_HI_LO_BND_PE ( 'R', BNDY_PE_LOY, BNDY_PE_HIY )

         IF ( BNDY_PE_HIY ) THEN
            ENDROW2_LIM = ENDROW2
            ELSE
            ENDROW2_LIM = ENDROW2 + 1
            END IF

!        write( logdev,2005 ) bndy_pe_loy, bndy_pe_hiy,
!    &                        startrow, endrow, startrow2, endrow2, endrow2_lim
!        call flush_
2005  format(  '#y_yamo> :', 2l6, 2x, 5i6.3 )

         END IF                    ! if firstime

      DT = FLOAT ( TIME2SEC ( TSTEP ) )

C Do the computation for y advection

C Get the contravariant x2 velocity component

      CALL HCONTVEL ( FDATE, FTIME, TSTEP, LVL, X2VEL, VHAT )

      DO 253 COL = 1, MY_NCOLS

         DO ROW = STARTROW, ENDROW      !     DO ROW = 1, MY_NROWS+1
            VELY( ROW ) = VHAT( COL,ROW )
            END DO

         TRRHOJ( 1:NROWS ) = CGRID( COL,1:NROWS,LVL,ASPC )

         CALL SE_COMM ( TRRHOJ, DSPL_N0_E0_S1_W0, DRCN_S, '1 0' )

         IF ( BNDY_PE_LOY ) THEN
            ADJFAC = YTRHOJ( COL,2 ) / TRRHOJ( 1 )
            IF ( VELY( 1 ) .LT. 0.0 ) VELY( 1 ) = VELY( 1 ) * ADJFAC
            END IF

         DO ROW = STARTROW2, ENDROW2

            IF ( ROW .EQ. STARTROW2 ) THEN
               ADJFAC_L = YTRHOJ( COL,ROW ) / TRRHOJ( ROW-1 )
               ELSE
               ADJFAC_L = ADJFAC
               END IF

            IF ( ROW .LT. ENDROW2_LIM ) ADJFAC = YTRHOJ( COL,ROW+1 )
     &                                         / TRRHOJ( ROW )

            IF ( VELY( ROW ) .LT. 0.0 ) THEN
               VELY( ROW ) = VELY( ROW ) * ADJFAC
               ELSE IF ( VELY( ROW ) .GT. 0.0 ) THEN
               VELY( ROW ) = VELY( ROW ) * ADJFAC_L
               END IF

!           if ( vely( row ) .lt. 0.0 ) then
!              if ( adjfac .lt. 0.70 .or. adjfac .gt. 1.36 ) then
!                 write( logdev,2009 ) col, row, lvl, adjfac, vely(row)
!                 end if  !
!              else
!              if ( adjfac_l .lt. 0.70 .or. adjfac_l .gt. 1.36 ) then
!                 write( logdev,2011 ) col, row, lvl, adjfac_l, vely(row)
!                 end if  !
!              end if
2009           format(  '#y_yamo> col, row, lvl, adjfac,   vely: ',
     &                3i3, 1x, 2f7.2 )
2011           format(  '#y_yamo> col, row, lvl, adjfac_l, vely: ',
     &                3i3, 1x, 2f7.2 )

            END DO

         DO SPC = 1, N_SPC_ADV

            A2C = ADV_MAP( SPC )
            DO ROW = 1, MY_NROWS
               CONY( ROW,SPC ) = CGRID( COL,ROW,LVL,A2C )
               END DO

C South boundary

            IF ( BNDY_PE_LOY ) THEN
               IF ( VELY( 1 ) .LT. 0.0 ) THEN          ! outflow
                  CONY( 0,SPC ) = ZFDBC ( CONY( 1,SPC ), CONY( 2,SPC ),
     &                                    VELY( 1 ),     VELY( 2 ) )
                  ELSE    ! inflow
                  CONY( 0,SPC ) = BCCN( SFX,COL,SPC )
                  END IF
               END IF

C North boundary

            IF ( BNDY_PE_HIY ) THEN
               IF ( VELY( MY_NROWS+1 ) .GT. 0.0) THEN     ! outflow
                  CONY( MY_NROWS+1,SPC ) = ZFDBC ( CONY( MY_NROWS,SPC ),
     &                                             CONY( MY_NROWS-1,SPC ),
     &                                             VELY( MY_NROWS+1 ),
     &                                             VELY( MY_NROWS ) )
                  ELSE    ! inflow
                  CONY( MY_NROWS+1,SPC ) = BCCN( NFX,COL,SPC )
                  END IF
               END IF

            END DO

C PPM scheme

         CALL HPPM ( NROWS, CONY, VELY, DT, DSY, 'R' )

         DO SPC = 1, N_SPC_ADV
            A2C = ADV_MAP( SPC )
            DO ROW = 1, MY_NROWS
               CGRID( COL,ROW,LVL,A2C ) = CONY( ROW,SPC )
!              if ( cony( row,spc ) .le. 0.0 )
!    &            write( logdev,2019 ) ftime, col, row, lvl, spc, cony(row,spc )
               END DO
            END DO

2019  format( 'y_yamo# time, c, r, l, s, cony: ',
     &         I7.6, 4I4, 1pe12.3 )

253      CONTINUE

      RETURN
      END
