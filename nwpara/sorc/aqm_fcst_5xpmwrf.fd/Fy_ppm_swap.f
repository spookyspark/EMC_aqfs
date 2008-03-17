
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
C $Header: /project/work/rep/CCTM/src/hadv/yamo/y_ppm.F,v 1.1 2005/06/22 16:37:34 yoj Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE Y_PPM ( FDATE, FTIME, TSTEP, LVL, BCON )

C-----------------------------------------------------------------------
C Function:
C   Piecewise Parabolic Method advection in the Y-direction

C Preconditions:

C Subroutines and functions called:

C Revision history:
C  28 Jun 2004: Jeff Young

C   1 Nov 06: Jeff Young - Following Glenn Hammond, moved all communication
C   out of HPPM to this level; using "swap_sandia" communication; update only
C   local values in the CGRID array within a time step, discarding previous
C   ghost values.

C-----------------------------------------------------------------------

      USE CGRID_DEFN            ! inherits GRID_CONF and CGRID_SPCS
      USE SE_MODULES         ! stenex
!     USE SUBST_COMM_MODULE     ! stenex
!     USE SUBST_UTIL_MODULE     ! stenex

      USE SWAP_SANDIA

      IMPLICIT NONE

C Includes:

      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_SPC.EXT"      ! gas chemistry species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_ADV.EXT"      ! gas chem advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_ADV.EXT"      ! aerosol advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_ADV.EXT"      ! non-react advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/TR_ADV.EXT"      ! tracer advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"       ! constants
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"     ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"      ! I/O definitions and declarations
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/PE_COMM.EXT"     ! PE communication displacement and direction

C Arguments:

      INTEGER, INTENT( IN ) :: FDATE         ! current model date, coded YYYYDDD
      INTEGER, INTENT( IN ) :: FTIME         ! current model time, coded HHMMSS
      INTEGER, INTENT( IN ) :: TSTEP         ! time step (HHMMSS)
      INTEGER, INTENT( IN ) :: LVL           ! layer
!     REAL,    INTENT( IN ) :: BCON( NBNDY,1: ) ! boundary concentrations
      REAL,    INTENT( IN ) :: BCON( :,: )      ! boundary concentrations

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

      INTEGER, PARAMETER :: SWP = 3

C File Variables:

      REAL         VHAT( NCOLS+1,NROWS+1 )       ! x1-component CX-velocity

C Local Variables:

      CHARACTER( 16 ) :: PNAME = 'Y_PPM'
      LOGICAL, SAVE :: FIRSTIME = .TRUE.
      CHARACTER( 96 ) :: XMSG = ' '

      integer, save :: logdev

      REAL          DX2                         ! dx2 (meters)
      INTEGER, SAVE :: ASPC                     ! RHOJ index in CGRID

      REAL, ALLOCATABLE, SAVE :: DSY( : ),      ! ds = DX2
     &                           VELY( : ),     ! Velocities along a column
     &                           CONY( :,: )    ! Conc's along a column

      REAL          DT                          ! TSTEP in sec
      INTEGER       ALLOCSTAT

      INTEGER, SAVE :: ADV_MAP( N_SPC_ADV )     ! global adv map to CGRID

      CHARACTER( 16 ) :: X2VEL = 'X2VEL'

      INTEGER      COL, ROW, SPC, VAR           ! loop counters
      INTEGER      A2C

      INTEGER MY_TEMP
!     INTEGER, SAVE :: STARTROW, ENDROW
      LOGICAL, SAVE :: BNDY_PE_LOY, BNDY_PE_HIY

      INTEGER NORTH_ROW, M
!     REAL    HALO_NORTH( NCOLS,SWP,N_SPC_ADV )
!     REAL    HALO_SOUTH( NCOLS,SWP,N_SPC_ADV )
!     REAL    BUF_NS    ( SWP*NCOLS*N_SPC_ADV )
      REAL, ALLOCATABLE, SAVE :: HALO_NORTH( :,:,: )
      REAL, ALLOCATABLE, SAVE :: HALO_SOUTH( :,:,: )
      REAL, ALLOCATABLE, SAVE :: BUF_NS( : )

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
            INTEGER, PARAMETER                :: SWP = 3
            INTEGER,         INTENT( IN )     :: NI
            REAL,            INTENT( IN OUT ) :: CON( 1-SWP:,1: )
            REAL,            INTENT( IN )     :: VEL( : )
            REAL,            INTENT( IN )     :: DT
            REAL,            INTENT( IN )     :: DS ( -SWP: )
            CHARACTER,       INTENT( IN )     :: ORI
         END SUBROUTINE HPPM
      END INTERFACE
C-----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
!        logdev = init3 ()
         logdev = setup_logdev()

         SFX = 0
         NFX = MY_NCOLS + MY_NROWS + 3

C Get dx2 from HGRD_DEFN module

         IF ( GDTYP_GD .EQ. LATGRD3 ) THEN
            DX2 = DG2M * YCELL_GD   ! in m.
         ELSE
            DX2 = YCELL_GD          ! in m.
         END IF

         ALLOCATE ( CONY( 1-SWP:MY_NROWS+SWP,N_SPC_ADV ),
     &               DSY(  -SWP:MY_NROWS+SWP ),
     &              VELY( MY_NROWS+1 ), STAT = ALLOCSTAT ) ! Vel along a col
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating DSY, VELY, or CONY'
            CALL M3EXIT ( PNAME, FDATE, FTIME, XMSG, XSTAT1 )
         END IF

         DO ROW = -SWP, MY_NROWS+SWP
            DSY( ROW ) = DX2
         END DO

         ALLOCATE ( HALO_NORTH( MY_NCOLS,SWP,N_SPC_ADV ),
     &              HALO_SOUTH( MY_NCOLS,SWP,N_SPC_ADV ),
     &              BUF_NS    ( SWP*MY_NCOLS*N_SPC_ADV ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating HALO_NORTH, HALO_SOUTH, or BUF_NS'
            CALL M3EXIT ( PNAME, FDATE, FTIME, XMSG, XSTAT1 )
         END IF
         HALO_NORTH = 0.0   ! array
         HALO_SOUTH = 0.0   ! array
         BUF_NS     = 0.0   ! array

C SWAPnD interface (same array in both procs)
C                                                     SWAP1D SWAP2D SWAP3D
C 1st value of array to be sent,                         X     X      X
C 1st value of array to be received,                     X     X      X
C number of values to send in 1st dimension of array,    X     X      X
C number of values to send in 2nd dimension of array,          X      X
C number of values to send in 3rd dimension of array,                 X
C size of 1st dimension in array,                              X      X
C size of 2nd dimension in array,                                     X
C direction to receive from: NORTH,SOUTH,EAST,WEST       X     X      X

         CALL SWAP1D( DSY( 1 ),              DSY( MY_NROWS+1 ), SWP, NORTH )
         CALL SWAP1D( DSY( MY_NROWS+1-SWP ), DSY( 1-SWP ),      SWP, SOUTH )

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

!        CALL SE_LOOP_INDEX ( 'R', 1, MY_NROWS, 1, MY_TEMP,
!    &                           STARTROW, ENDROW )

         CALL SE_HI_LO_BND_PE ( 'R', BNDY_PE_LOY, BNDY_PE_HIY )

      END IF                    ! if firstime

      DT = FLOAT ( TIME2SEC ( TSTEP ) )

C Do the computation for y advection

C Get the contravariant x2 velocity component

      CALL HCONTVEL ( FDATE, FTIME, TSTEP, LVL, X2VEL, VHAT )

      CALL SWAP2D( VHAT( 1,1 ), VHAT( 1,NROWS+1 ), NCOLS+1, 1, NCOLS+1, NORTH ) 
      M = 0
      NORTH_ROW = MY_NROWS - SWP
      DO SPC = 1, N_SPC_ADV
         A2C = ADV_MAP( SPC )
         DO ROW = 1, SWP
            DO COL = 1, MY_NCOLS
               HALO_SOUTH( COL,ROW,SPC ) = CGRID( COL,ROW,LVL,A2C )
               HALO_NORTH( COL,ROW,SPC ) = CGRID( COL,NORTH_ROW+ROW,LVL,A2C )
               M = M + 1
               BUF_NS( M ) = HALO_NORTH( COL,ROW,SPC )
            END DO
         END DO
      END DO

      CALL SWAP3D( HALO_SOUTH, HALO_NORTH, MY_NCOLS, SWP, N_SPC_ADV,
     &             MY_NCOLS, SWP, NORTH )
      CALL SWAP3D( BUF_NS, HALO_SOUTH, MY_NCOLS, SWP, N_SPC_ADV,
     &             MY_NCOLS, SWP, SOUTH )

      DO 233 COL = 1, MY_NCOLS

!        DO ROW = STARTROW, ENDROW         !    DO ROW = 1, MY_NROWS+1
         DO ROW = 1, MY_NROWS+1
            VELY( ROW ) = VHAT( COL,ROW )
         END DO

         DO SPC = 1, N_SPC_ADV

            A2C = ADV_MAP( SPC )
            DO ROW = 1, MY_NROWS
               CONY( ROW,SPC ) = CGRID( COL,ROW,LVL,A2C )
            END DO

            DO ROW = 1, SWP
               CONY( ROW-SWP,SPC )      = HALO_SOUTH( COL,ROW,SPC )
               CONY( MY_NROWS+ROW,SPC ) = HALO_NORTH( COL,ROW,SPC )
            END DO

C South boundary

            IF ( BNDY_PE_LOY ) THEN
               IF ( VELY( 1 ) .LT. 0.0 ) THEN          ! outflow
                  CONY( 1-SWP:0,SPC) =
     &               ZFDBC ( CONY( 1,SPC ), CONY( 2,SPC ),
     &                       VELY( 1 ),     VELY( 2 ) )
               ELSE    ! inflow
                  CONY( 1-SWP:0,SPC ) = BCCN( SFX,COL,SPC )
               END IF
            END IF

C North boundary

            IF ( BNDY_PE_HIY ) THEN
               IF ( VELY( MY_NROWS+1 ) .GT. 0.0 ) THEN     ! outflow
                  CONY( MY_NROWS+1:MY_NROWS+SWP,SPC ) =
     &               ZFDBC ( CONY( MY_NROWS,SPC ), CONY( MY_NROWS-1,SPC ),
     &                       VELY( MY_NROWS+1 ),   VELY( MY_NROWS ) )
               ELSE    ! inflow
                  CONY( MY_NROWS+1:MY_NROWS+SWP,SPC ) = BCCN( NFX,COL,SPC )
               END IF
            END IF

         END DO

C PPM scheme

         CALL HPPM ( MY_NROWS, CONY, VELY, DT, DSY, 'R' )

         DO SPC = 1, N_SPC_ADV
            A2C = ADV_MAP( SPC )
            DO ROW = 1, MY_NROWS
               CGRID( COL,ROW,LVL,A2C ) = CONY( ROW,SPC )
!              if ( cony( row,spc ) .le. 0.0 )
!    &            write( logdev,2019 ) ftime, col, row, lvl, spc, cony(row,spc )
            END DO
         END DO

!        do row = 1, my_nrows
!           if ( cony( row,n_spc_adv ) .le. 0.0 ) then
!              write( logdev,2019 ) ftime, col, row, lvl,
!    &                              cony( row,n_spc_adv )
!           end if
!        end do
!019  format( 'y_ppm# date, time, col, row, lvl, cony: ',
!    &         2I7, 3I4, 1pe12.3 )
2019  format( 'y_ppm# time, c, r, l, s, cony: ',
     &         I7.6, 4I4, 1pe12.3 )


233   CONTINUE

      RETURN
      END
