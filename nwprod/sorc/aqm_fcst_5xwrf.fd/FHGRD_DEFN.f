
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/driver/yamo/HGRD_DEFN.F,v 1.1.1.1 2005/09/09 18:56:06 sjr Exp $ 

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      MODULE HGRD_DEFN

C Define the horizontal domain, globally and for each processor, if 1
C Revision History: David Wong 18 Feb 01: created
C                   Jeff Young 23 Feb 01: generalize
C                              31 Mar 01: add BLKPRM.EXT
C                              10 Nov 01: change to use GRIDDESC, env vars
C                   J Gipson   01 Sep 04: change block size to 50
C                   J Young    07 Dec 04: remove layer dependency (for MXCELLS,
C                                         MXBLKS) to implement vertical layer
C                                         dyn alloc appropriately
C.......................................................................

      IMPLICIT NONE

C grid name selected from GRIDDESC
      CHARACTER( 16 ), SAVE :: GRID_NAME

C returned coordinate system (projection)
      CHARACTER( 16 ), SAVE :: COORD_SYS_NAME

C map projection type (should be named PRTYP_GD!)
      INTEGER, SAVE :: GDTYP_GD = 2 ! LAMGRD3

C first map projection parameter (degrees)
      REAL( 8 ), SAVE :: P_ALP_GD = 30.0

C second map projection parameter (degrees)
      REAL( 8 ), SAVE :: P_BET_GD = 60.0

C third map projection parameter (degrees)
      REAL( 8 ), SAVE :: P_GAM_GD = -90.0

C longitude for coord-system center (degrees)
      REAL( 8 ), SAVE :: XCENT_GD = -90.0

C latitude for coord-system center (degrees)
      REAL( 8 ), SAVE :: YCENT_GD = 40.0

      REAL( 8 ), SAVE :: XORIG_GD ! X-coordinate origin of computational grid
      REAL( 8 ), SAVE :: YORIG_GD ! Y-coordinate origin of computational grid

      REAL( 8 ), SAVE :: XCELL_GD ! X-coordinate cell width (M)
      REAL( 8 ), SAVE :: YCELL_GD ! Y-coordinate cell width (M)

      INTEGER, SAVE :: MYPE = -1  ! set in par_init

      INTEGER, SAVE :: GL_NCOLS   ! no. of columns in global grid
      INTEGER, SAVE :: GL_NROWS   ! no. of rows in global grid
      INTEGER, SAVE :: GL_NBNDY   ! no. of cells in one layer of global boundary
 
      INTEGER, SAVE :: NPCOL      ! no. of processors across grid columns
      INTEGER, SAVE :: NPROW      ! no. of processors across grid rows
 
      INTEGER, SAVE :: NCOLS      ! grid columns array dimension
      INTEGER, SAVE :: NROWS      ! grid rows array dimension
      INTEGER, SAVE :: NBNDY      ! no. of cells in one layer of local boundary
 
!     INTEGER, PARAMETER :: NTHIK = 1     ! boundary thickness (cells)
      INTEGER, SAVE :: NTHIK      ! boundary thickness (cells)
 
      INTEGER, SAVE :: MY_NCOLS   ! local no. of computational grid columns
      INTEGER, SAVE :: MY_NROWS   ! local no. of computational grid rows
      INTEGER, SAVE :: MY_NBNDY   ! local no. of boundary cells
C column range for each processor
      INTEGER, ALLOCATABLE, SAVE :: COLSX_PE( :,: )
C row range for each processor
      INTEGER, ALLOCATABLE, SAVE :: ROWSX_PE( :,: )
 
C maximum stencil displacement in the north, east, south, and west direction
      INTEGER, PARAMETER :: MNDIS = 2
      INTEGER, PARAMETER :: MEDIS = 2
      INTEGER, PARAMETER :: MSDIS = 2
      INTEGER, PARAMETER :: MWDIS = 2

C BLKPRM

!     INTEGER, PARAMETER :: BLKSIZE = 500
!     INTEGER, PARAMETER :: BLKSIZE = 50
!     INTEGER, SAVE :: MXCELLS
!     INTEGER, SAVE :: MXBLKS

C Process Analysis

      INTEGER, SAVE :: PA_BEGCOL  ! Starting column for output
      INTEGER, SAVE :: PA_ENDCOL  ! Ending column for output
      INTEGER, SAVE :: PA_BEGROW  ! Starting row for output
      INTEGER, SAVE :: PA_ENDROW  ! Ending row for output
      INTEGER, SAVE :: PA_BEGLEV  ! Starting layer for output
      INTEGER, SAVE :: PA_ENDLEV  ! Ending layer for output

C Integral average conc

!     INTEGER, SAVE :: N_ASPCS    ! Number of species saved to avg conc file
!     CHARACTER( 16 ), SAVE :: AVG_CONC( 100 ) ! avg conc file species list
!     INTEGER, SAVE :: ACONC_BLEV ! Beginning level saved to avg conc file
!     INTEGER, SAVE :: ACONC_ELEV ! Ending level saved to avg conc file

      CONTAINS

         FUNCTION HGRD_INIT ( NPROCS, MYID ) RESULT ( SUCCESS )

!        INCLUDE SUBST_VGRD_ID     ! vertical dimensioning parameters
         INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/IODECL3.EXT"      ! I/O definitions and declarations
         INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PA_CTL.EXT"    ! Process analysis control parameters

         INTEGER :: NPROCS
         INTEGER :: MYID
         LOGICAL :: SUCCESS

         INTEGER, SAVE :: LOGDEV
         LOGICAL, SAVE :: FIRSTIME = .TRUE.
         CHARACTER( 96 ) :: XMSG = ' '

C environment variable grid name to select from GRIDDESC
         CHARACTER( 16 ) :: HGRD_NAME = 'GRID_NAME'
         LOGICAL, EXTERNAL :: DSCGRID ! get horizontal grid parameters
         INTEGER, EXTERNAL :: SETUP_LOGDEV
         INTEGER :: STATUS, ALST

         INTEGER, ALLOCATABLE :: NCOLS_PE( : )  ! Column range for each PE
         INTEGER, ALLOCATABLE :: NROWS_PE( : )  ! Row range for each PE

         INTEGER    I               ! Loop counter
         INTEGER    NDX             ! Temporary index for processors row, column
         INTEGER    NCOLX           ! Used for computing columns per domain
         INTEGER    NROWX           ! Used for computing rows per domain

C Number of columns in west-to-east subdomains
         INTEGER, ALLOCATABLE :: NCOLS_WE( : )
C Number of rows in south-to-north subdomains
         INTEGER, ALLOCATABLE :: NROWS_SN( : )

!        CHARACTER( 32 ) :: AVG_CONC_SPCS   = 'AVG_CONC_SPCS'
!        CHARACTER( 32 ) :: ACONC_BLEV_ELEV = 'ACONC_BLEV_ELEV'
         CHARACTER( 32 ) :: PA_BCOL_ECOL    = 'PA_BCOL_ECOL'
         CHARACTER( 32 ) :: PA_BROW_EROW    = 'PA_BROW_EROW'
         CHARACTER( 32 ) :: PA_BLEV_ELEV    = 'PA_BLEV_ELEV'
         CHARACTER( 32 ) :: NPCOL_NPROW     = 'NPCOL_NPROW'
         CHARACTER( 16 ) :: V_LIST( 2 )
         CHARACTER( 48 ) :: VARDESC

         INTEGER V, NV
         INTEGER IV( 2 )

         INTERFACE
            SUBROUTINE GET_ENVLIST ( ENV_VAR, NVARS, VAL_LIST )
               IMPLICIT NONE
               CHARACTER( * ),  INTENT ( IN )  :: ENV_VAR
               INTEGER,         INTENT ( OUT ) :: NVARS
               CHARACTER( 16 ), INTENT ( OUT ) :: VAL_LIST( : )
            END SUBROUTINE GET_ENVLIST
         END INTERFACE

C-----------------------------------------------------------------------

C This function is expected to be called only once - at startup

         IF ( FIRSTIME ) THEN
            FIRSTIME = .FALSE.
            LOGDEV = SETUP_LOGDEV()
            SUCCESS = .TRUE.

            MYPE = MYID

            VARDESC = 'Horizontal Domain Definition '
            CALL ENVSTR( HGRD_NAME, VARDESC, 'GRID_NAME', GRID_NAME, STATUS )
               IF ( STATUS .NE. 0 ) WRITE( LOGDEV, '(5X, A)' ) VARDESC
               IF ( STATUS .EQ. 1 ) THEN
                  XMSG = 'Environment variable improperly formatted'
                  CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
                  SUCCESS = .FALSE.; RETURN
                  ELSE IF ( STATUS .EQ. -1 ) THEN
                  XMSG = 'Environment variable set, but empty ... Using default'
                  WRITE( LOGDEV, '(5X, A)' ) XMSG
                  ELSE IF ( STATUS .EQ. -2 ) THEN
                  XMSG = 'Environment variable not set ... Using default'
                  WRITE( LOGDEV, '(5X, A)' ) XMSG
                  END IF

C With GRID_NAME (only input) retrieve all horizontal grid parameters from
C the grid description file pointed to by the GRIDDESC env var:

            IF ( .NOT. DSCGRID ( GRID_NAME,
     &                           COORD_SYS_NAME, GDTYP_GD, 
     &                           P_ALP_GD, P_BET_GD, P_GAM_GD,
     &                           XCENT_GD, YCENT_GD,
     &                           XORIG_GD, YORIG_GD, XCELL_GD, YCELL_GD,
     &                           GL_NCOLS, GL_NROWS, NTHIK ) ) THEN
               XMSG = 'Failure retrieving horizontal grid parameters'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

            IF ( LIPR .OR. LIRR ) THEN

C Retrieve the process analysis subdomain dimensions:

               CALL GET_ENVLIST ( PA_BCOL_ECOL, NV, V_LIST )
               IF ( NV .NE. 2 ) THEN
                  XMSG = 'Environment variable error for ' // PA_BCOL_ECOL
                  CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
                  SUCCESS = .FALSE.; RETURN
                  END IF
               READ( V_LIST( 1 ), '( I4 )' ) PA_BEGCOL
               READ( V_LIST( 2 ), '( I4 )' ) PA_ENDCOL

               CALL GET_ENVLIST ( PA_BROW_EROW, NV, V_LIST )
               IF ( NV .NE. 2 ) THEN
                  XMSG = 'Environment variable error for ' // PA_BROW_EROW
                  CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
                  SUCCESS = .FALSE.; RETURN
                  END IF
               READ( V_LIST( 1 ), '( I4 )' ) PA_BEGROW
               READ( V_LIST( 2 ), '( I4 )' ) PA_ENDROW

               CALL GET_ENVLIST ( PA_BLEV_ELEV, NV, V_LIST )
               IF ( NV .NE. 2 ) THEN
                  XMSG = 'Environment variable error for ' // PA_BLEV_ELEV
                  CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
                  SUCCESS = .FALSE.; RETURN
                  END IF
               READ( V_LIST( 1 ), '( I4 )' ) PA_BEGLEV
               READ( V_LIST( 2 ), '( I4 )' ) PA_ENDLEV

               ELSE

               PA_BEGCOL = 1 
               PA_ENDCOL = 1 
               PA_BEGROW = 1 
               PA_ENDROW = 1 
               PA_BEGLEV = 1 
               PA_ENDLEV = 1 

               END IF

C    Retrieve the domain decompostion processor array

            CALL GET_ENVLIST ( NPCOL_NPROW, NV, V_LIST )
            IF ( NV .NE. 2 ) THEN
               XMSG = 'Environment variable problem for ' // NPCOL_NPROW
     &              // ' using default 1X1'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
!              SUCCESS = .FALSE.; RETURN
               NV = 2
               V_LIST( 1 ) = '1'
               V_LIST( 2 ) = '1'
               END IF
            READ( V_LIST( 1 ), '( I4 )' ) NPCOL
            READ( V_LIST( 2 ), '( I4 )' ) NPROW

C Retrieve the species saved to integral average concentration file

!           CALL GET_ENVLIST ( AVG_CONC_SPCS, N_ASPCS, AVG_CONC )

C Retrieve the layer range used in integral average concentration file

!           CALL GET_ENVLIST ( ACONC_BLEV_ELEV, NV, V_LIST )
!           IF ( NV .NE. 2 ) THEN
!              XMSG = 'Environment variable error for ' // ACONC_BLEV_ELEV
!              CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
!              SUCCESS = .FALSE.; RETURN
!              END IF
!           READ( V_LIST( 1 ), '( I4 )' ) ACONC_BLEV
!           READ( V_LIST( 2 ), '( I4 )' ) ACONC_ELEV

C Check NPROCS against NPCOL*NPROW
            IF ( NPROCS .NE. NPCOL*NPROW ) THEN
               WRITE( LOGDEV,* ) ' --- Nprocs, NProw, NPcol ',
     &                                 NPROCS, NPROW, NPCOL
               XMSG = 'NPROCS is not equal to NPCOL*NPROW'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

!           ALLOCATE ( COLSX_PE( 2, 0:NPCOL*NPROW-1 ), STAT = ALST )
            ALLOCATE ( COLSX_PE( 2, NPROCS ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** COLSX_PE Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

!           ALLOCATE ( ROWSX_PE( 2, 0:NPCOL*NPROW-1 ), STAT = ALST )
            ALLOCATE ( ROWSX_PE( 2, NPROCS ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** ROWSX_PE Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

            ALLOCATE ( NCOLS_PE( NPROCS ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** NCOLS_PE Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

            ALLOCATE ( NROWS_PE( NPROCS ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** NROWS_PE Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

            ALLOCATE ( NCOLS_WE( NPCOL ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** NCOLS_WE Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

            ALLOCATE ( NROWS_SN( NPROW ), STAT = ALST )
            IF ( ALST .NE. 0 ) THEN
               XMSG = '*** NROWS_SN Memory allocation failed'
               CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
               SUCCESS = .FALSE.; RETURN
               END IF

C Construct the processor-to-subdomain map
            NCOLX = GL_NCOLS / NPCOL
            NROWX = GL_NROWS / NPROW
            DO I = 1, NPCOL
               NCOLS_WE( I ) = NCOLX
               END DO
            DO I = 1, NPROW
               NROWS_SN( I ) = NROWX
               END DO
            DO I = 1, GL_NCOLS - NPCOL*NCOLX     ! distribute remaining columns
               NCOLS_WE( I ) = NCOLS_WE( I ) + 1
               END DO
            DO I = 1, GL_NROWS - NPROW*NROWX
               NROWS_SN( I ) = NROWS_SN( I ) + 1 ! distribute remaining rows
               END DO

            DO I = 1, NPROCS

C Set NDX to the subdomain column index for processor I
               NDX = MOD ( I,NPCOL )
               IF ( NDX .EQ. 0 ) NDX = NPCOL

C Assign the number of columns in this PE
               NCOLS_PE( I ) = NCOLS_WE( NDX )

C Calculate column range of this PE in the global domain
               IF ( NDX .EQ. 1 ) THEN
                  COLSX_PE( 1,I ) = 1
                  COLSX_PE( 2,I ) = NCOLS_PE( I )
                  ELSE
                  COLSX_PE( 1,I ) = COLSX_PE( 2,I-1 ) + 1
                  COLSX_PE( 2,I ) = COLSX_PE( 2,I-1 ) + NCOLS_PE( I )
                  END IF

C Set NDX to the subdomain row number for processor I
               NDX = ( I - 1 ) / NPCOL + 1

C Assign the number of rows in this PE
               NROWS_PE( I ) = NROWS_SN( NDX )

C Calculate row range of this PE in the global domain
               IF ( I .LE. NPCOL ) THEN
               ROWSX_PE( 1,I ) = 1
               ROWSX_PE( 2,I ) = NROWS_PE( I )
               ELSE
               ROWSX_PE( 1,I ) = ROWSX_PE( 2,I-NPCOL ) + 1
               ROWSX_PE( 2,I ) = ROWSX_PE( 2,I-NPCOL ) + NROWS_PE( I )
               END IF

            END DO   ! 1, NPROCS

            MY_NCOLS = NCOLS_PE( MYPE+1 )
            MY_NROWS = NROWS_PE( MYPE+1 )
            MY_NBNDY = 2*NTHIK * ( MY_NCOLS + MY_NROWS + 2*NTHIK )
            GL_NBNDY = 2*NTHIK * ( GL_NCOLS + GL_NROWS + 2*NTHIK )

            NCOLS = MY_NCOLS
            NROWS = MY_NROWS
            NBNDY = MY_NBNDY

!           MXCELLS = NCOLS * NROWS * NLAYS
!           MXBLKS  = 1 + ( MXCELLS - 1 ) / BLKSIZE

            DEALLOCATE ( NCOLS_PE )
            DEALLOCATE ( NROWS_PE )
            DEALLOCATE ( NCOLS_WE )
            DEALLOCATE ( NROWS_SN )

            ELSE
            XMSG = 'Horizontal domain decomposition already defined'
            CALL M3WARN ( 'HGRD_INIT', 0, 0, XMSG )
            SUCCESS = .FALSE.; RETURN

            END IF   ! FIRSTIME

         RETURN
         END FUNCTION HGRD_INIT
 
      END MODULE HGRD_DEFN
