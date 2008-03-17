
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
C $Header: /project/work/rep/CCTM/src/phot/phot/phot.F,v 1.10 2002/04/05 18:23:19 yoj Exp $ 

C what(1) key, module and SID; SCCS file; date and time of last delta:
C @(#)phot.F    1.2 /project/mod3/CMAQ/src/phot/phot/SCCS/s.phot.F 04 Jul 1997 10:09:53

      SUBROUTINE PHOT ( MDATE, MTIME, JDATE, JTIME, NDARK, RJ )
C----------------------------------------------------------------------
C Function: 
C    PHOT, adapted from RADM, calculates the photolysis rate constants
C    to be used by the chemical solver.
C    It uses linear interpolation in time of day, height, and latitude
C    from file tabular values and optionally adjusts photolysis rates 
C    above, below and in cumulus clouds.
 
C Preconditions: HGRD_INIT() called from PAR_INIT, which is called from DRIVER
 
C Subroutines/Functions called: INIT3
 
C Revision history: 
C    prototype(adaptation from RADM), Rohit Mathur, April 1993.  
C    major mods, Jeff Young, May 1994 - annotated and/or "c" in col 1
C    Some argument data are interpolated data and have not been stride-
C    offset in their leading dimension (July, 1994).
C    Modified by Jerry Gipson in June, 1995 to be consistent with 
C    Gear solver code
C    Modified by Shawn Roselle (Sept/Oct 1995) to read new photolysis
C    table
C    Jeff - 22 Aug 96
C    modified by S. Roselle (10/16/97) to use a new formula for calculating
C    the optical depth
C    Jeff - 3 June 98 - generalize for phot. reactions tables
C    02 October, 1998 by Al Bourgeois at LM: 1 implementation
C    23 October, 1998 by Al Bourgeois to use SUM_CHK for 1 sum. 
C    30 Mar 01 J.Young: dyn alloc - Use HGRD_DEFN; allocatable arrays;
C    replace INTERP3 with INTERPX
C    28 Jan 05 R.Mathur - use ETA radiation to adjust for subcloud attenuation
C    31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                       domain specifications in one module
 
C Note:
C    assumes all latitudes within XLATJV(1)=10.0 and XLATJV(JVLAT)=60.0
C    assumes all layer heights within XZJV(1)=0.0 and 
C    XZJV(JVHT)=10000.0
 
C----------------------------------------------------------------------

      USE GRID_CONF           ! horizontal & vertical domain specifications
      USE SE_MODULES
!     USE SUBST_UTIL_MODULE

      IMPLICIT NONE
 
C include files:
 
!     INCLUDE SUBST_HGRD_ID    ! horizontal dimensioning params
!     INCLUDE SUBST_VGRD_ID    ! vertical dimensioning params
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"    ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/FDESC3.EXT"    ! file header data structuer
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"     ! I/O definitions and declarations
!     INCLUDE SUBST_COORD_ID   ! coordinate and domain definitions (req IOPARMS)
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/FILES_CTM.EXT"   ! file name parameters
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"      ! physical constants
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/RXCM.EXT"     ! chemical mechamism reactions COMMON

C arguments:
 
      INTEGER      MDATE             ! "centered" Julian date (YYYYDDD)
      INTEGER      MTIME             ! "centered" time (HHMMSS)
      INTEGER      JDATE             ! current Julian date (YYYYDDD)
      INTEGER      JTIME             ! current time (HHMMSS)
      INTEGER      NDARK             ! Number of level 1 cells in darkness
      
      REAL         RJ( NCOLS, NROWS, NLAYS, NPHOTAB )
                                     ! gridded J-values  (/min units)
 
C local parameters:
 
      INTEGER, PARAMETER :: NMHT = 7    ! number of vertical levels

      INTEGER, PARAMETER :: NMTMAX = 9  ! number of hour angles

      INTEGER, PARAMETER :: NMLAT = 6   ! number of latitudes

      INTEGER, PARAMETER :: ONE = 1.0E0 ! numerical 1.0
  
      REAL, PARAMETER :: MAOMW   = MWAIR / MWWAT ! m.w. of air over m.w. of H2O

      INTEGER, PARAMETER :: MXPHOT = 100 ! dimension for file no. of phot tables

C external functions:
 
      INTEGER      JUNIT              ! used to get next IO unit #
      INTEGER      SECSDIFF           !
      INTEGER, EXTERNAL :: INDEX1, SETUP_LOGDEV

C saved local variables:
 
      LOGICAL, SAVE :: FIRSTIME = .TRUE.  ! Flag for first call to PHOT

      INTEGER, SAVE :: STDATE             ! Julian date
      INTEGER, SAVE :: STTIME             ! current time
      INTEGER, SAVE :: JPHOT              ! # of photolytic reactions
      INTEGER, SAVE :: JVHT               ! number of vertical levels      
      INTEGER, SAVE :: JVTMAX             ! number of hour angles
      INTEGER, SAVE :: JVLAT              ! number of latitudes
      INTEGER, SAVE :: PHID( MXPHOT )     ! index of phot tab name in file list

      REAL, SAVE    :: STRTHR             ! starting GMT hour
      REAL, SAVE    :: JDSTRT             ! current Julian day (DDD)
!     REAL, SAVE    :: LAT ( NCOLS, NROWS ) ! north lat in deg (cross pt.)
!     REAL, SAVE    :: LON ( NCOLS, NROWS ) ! west long in deg (cross pt.)
!     REAL, SAVE    :: HT  ( NCOLS, NROWS ) ! ground elevation msl (meters)
      REAL, ALLOCATABLE, SAVE :: LAT( :,: ) ! north lat in deg (cross pt.)
      REAL, ALLOCATABLE, SAVE :: LON( :,: ) ! west long in deg (cross pt.)
      REAL, ALLOCATABLE, SAVE :: HT( :,: ) ! ground elevation msl (meters)
      REAL, SAVE    :: XJVAL( MXPHOT, NMTMAX, NMLAT, NMHT ) ! file jvalues 
      REAL, SAVE    :: XHAJV ( NMTMAX )   ! hours from noon
      REAL, SAVE    :: XLATJV( NMLAT )    ! latitudes of file photolytic rates
      REAL, SAVE    :: XZJV  ( NMHT )     ! vertical heights of file photolytic 
      REAL, SAVE    :: ACLD  ( MXPHOT )   ! ??????????
        
      INTEGER, SAVE :: LOGDEV
 
C scratch local variables:
 
      CHARACTER( 16 ) :: J2FILE = 'XJ_DATA'
      CHARACTER( 16 ) :: VARNM
      CHARACTER( 16 ) :: PHOTNM( MXPHOT )
      CHARACTER( 16 ) :: PNAME = 'PHOT'
      CHARACTER( 255 ) :: EQNAME
      CHARACTER( 120 ) :: XMSG = ' '

      INTEGER      JVUNIT
      INTEGER      JVDATE             ! Julian date on JVALUE file
      INTEGER   :: CLDATT = 1         ! flag for cloud attenuation; 1=on,0=off
      INTEGER      NDAYS              ! local day angle
      INTEGER      NT                 ! time loop index
      INTEGER      NHT                ! height loop index
      INTEGER      NLAT               ! latitude loop index
      INTEGER      NPHOT              ! photolysis rate loop index
      INTEGER      NHTO               ! dummy file height var
      INTEGER      NLATO              ! dummy file lat var
      INTEGER      NPHOTO             ! dummy file photolysis rate var
      INTEGER      ROW
      INTEGER      COL
      INTEGER      LEV
      INTEGER      JP                 ! loop indices
      INTEGER      JVTM               ! hour angle interpolation index
      INTEGER      JLATN              ! latitude interpolation index
      INTEGER      KHTA               ! altitude interpolation index
      INTEGER      IOST               ! i/o status code
      INTEGER      ALLOCSTAT

      REAL         CURRHR             ! current GMT hour
      REAL         THETA              ! function dummy argument
      REAL         INCANG             ! sun inclination angle
      REAL         FTIMO              ! hour angle interpolation weight
      REAL         OMFTIMO            ! 1 - FTIMO
      REAL         FLATS              ! latitude interpolation weight
      REAL         OMFLATS            ! 1 - FLATS
      REAL         ZHT                ! ht. of model layer above sea level 
      REAL         FHTA               ! altitude interpolation weight
      REAL         OMFHTA             ! 1 - FHTA
      REAL         LWP                ! liquid water path--lwc*dz (g/m2)
      REAL         JVAL               ! interpolated J-values
      REAL         CTOP               ! cloud top in single dimension
      REAL         CBASE              ! cloud base in single dimension
      REAL         ZLEV               ! height in single dimension
      REAL         CLDFR              ! total fractional cloud coverage  
      REAL         CLOD               ! cloud optical depth  
      REAL         ZEN                ! cosine of zenith angle
      REAL         TRANS              ! transmitivity
      REAL         FCLDA              ! above cloud top factor
      REAL         FCLDB              ! below cloud base factor
      REAL         ZREL               ! in cloud height
      REAL         X1                 ! cloud attenuation interpolation term
      REAL         X2                 ! cloud attenuation interpolation term
      REAL         FCLD               ! cloud photolytic atten factor
      REAL         JWT   ( 8 )        ! combined interpolation weight
      REAL         XLHA ( NCOLS, NROWS ) ! local hour angle
      REAL         WBAR ( NCOLS, NROWS ) ! avg cloud liq water cont (g/m**3)
      REAL         CLDT ( NCOLS, NROWS ) ! cloud top, as K index  
      REAL         CLDB ( NCOLS, NROWS ) ! cloud bottom, as K index 
      REAL         CFRAC( NCOLS, NROWS ) ! total fractional cloud coverage  
      REAL         ATTEN( NCOLS, NROWS ) ! Ratio of downward shortwave 
                                         ! radiation reaching surface to
                                         ! its clear-sky value
!     REAL         RADCLEAR, RADFAC
      REAL         ZM   ( NCOLS, NROWS, NLAYS ) ! Mid-layer ht. agl (m)
      REAL         DUMP                  ! dump unwanted data read

      INTEGER      GXOFF, GYOFF            ! global origin offset from file
C for INTERPX
      INTEGER       :: STRTCOLGC2, ENDCOLGC2, STRTROWGC2, ENDROWGC2
      INTEGER, SAVE :: STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3

C internal functions:
 
      REAL         SINE             ! sine of angle given in degrees
      REAL         COSINE           ! cosine of angle given in degrees

      SINE ( THETA )   = SIN ( PI180 * THETA )
      COSINE ( THETA ) = COS ( PI180 * THETA )
      
C----------------------------------------------------------------------
 
      IF ( FIRSTIME ) THEN
        FIRSTIME = .FALSE.
!       LOGDEV = INIT3()
        LOGDEV = SETUP_LOGDEV ()

        WRITE( LOGDEV, 1001 )
1001    FORMAT( // 5X, 'Using PHOT with subcloud attentuation derived',
     &             1X, 'from met model radiation' // )

        STDATE = JDATE
        STTIME = JTIME
        STRTHR = FLOAT ( JTIME / 10000 )
        JDSTRT = FLOAT ( MOD ( JDATE, 1000 ) )

        CALL NAMEVAL ( J2FILE, EQNAME )
        JVUNIT = JUNIT( )

        OPEN ( UNIT = JVUNIT, FILE = EQNAME, IOSTAT = IOST )
        XMSG = 'Error opening JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...read julian start date from the file..............................

        READ( JVUNIT, *, IOSTAT = IOST ) JVDATE

        XMSG = 'Error reading file header from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...note differences in start dates to the log

        XMSG = 'Date on JVALUE file differs from model start date'
        IF ( JVDATE .NE. STDATE ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )

C...read number of levels.............................................
        
        READ( JVUNIT, *, IOSTAT = IOST ) JVHT

        XMSG = 'Error reading number of LEVELS from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...make sure number of levels is correct

        XMSG = 'LEVELS on JVALUE file differ from expected value'
        IF ( JVHT .NE. NMHT )
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )

C...read levels

        READ( JVUNIT, *, IOSTAT = IOST ) ( XZJV( NHT ), NHT=1, JVHT )

        XMSG = 'Error reading LEVELS from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...read number of latitude bands.....................................
        
        READ( JVUNIT, *, IOSTAT = IOST ) JVLAT

        XMSG = 'Error reading number of LATITUDES from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...make sure number of latitudinal bands is correct

        XMSG = 'LATITUDES on JVALUE file differ from expected value'
        IF ( JVLAT .NE. NMLAT )
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )

C...read latitude bands

        READ( JVUNIT, *, IOSTAT = IOST ) ( XLATJV( NLAT ),
     &                                     NLAT=1, JVLAT )

        XMSG = 'Error reading LATITUDES from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...read hour number angles...........................................

        READ( JVUNIT, *, IOSTAT = IOST ) JVTMAX

        XMSG = 'Error reading number of HOURS from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...make sure number of hour angles is correct

        XMSG = 'HOURS on JVALUE file differ from expected value'
        IF ( JVTMAX .NE. NMTMAX )
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )

C...read hour angles

        READ( JVUNIT, *, IOSTAT = IOST ) ( XHAJV( NT ), NT=1, JVTMAX )

        XMSG = 'Error reading HOURS from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...read number of reactions..........................................
 
        READ( JVUNIT, *, IOSTAT = IOST ) JPHOT

        XMSG = 'Error reading number of REACTIONS from JVALUE file'
        IF ( IOST .NE. 0 ) 
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

C...make sure number of reactions is correct

        XMSG = 'Photolysis reactions on JVALUE file do not '
     &          //'match the expected list (NPHOTAB)'
        IF ( JPHOT .LT. NPHOTAB )
     &    CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )

C...read reaction id's and ACLD array

        XMSG = 'Error reading REACTIONS and ACLD from JVALUE file'
        DO NPHOT = 1, JPHOT
          READ( JVUNIT, *, IOSTAT = IOST ) PHOTNM( NPHOT ),
     &                                     ACLD( NPHOT )
          IF ( IOST .NE. 0 )
     &      CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END DO

C...check the file list

        DO NPHOT = 1, JPHOT
           PHID( NPHOT ) = 0
           END DO
        XMSG = 'File data does not have all required phot tables'
        DO NPHOT = 1, NPHOTAB
           PHID( NPHOT ) = INDEX1( PHOTAB( NPHOT ), JPHOT, PHOTNM )
           IF ( PHID( NPHOT ) .LE. 0 )
     &        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END DO

C...read the j-values

        XMSG = 'Error reading jvalues from JVALUE file'
        DO NHT = 1, JVHT
          DO NLAT = 1, JVLAT
            DO NPHOT = 1, JPHOT

              READ( JVUNIT, *, IOSTAT = IOST ) NHTO, NLATO, NPHOTO

              IF ( IOST .NE. 0 ) 
     &          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

              IF ( PHID( NPHOT ) .NE. 0 ) THEN

                 READ( JVUNIT, *, IOSTAT = IOST )
     &               ( XJVAL( PHID( NPHOT ), NT, NLAT, NHT ), NT = 1, JVTMAX )

                 IF ( IOST .NE. 0 ) 
     &             CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

                 ELSE

                 READ( JVUNIT, *, IOSTAT = IOST ) DUMP

                 IF ( IOST .NE. 0 ) 
     &             CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )

                 END IF

            END DO
          END DO
        END DO

C...close the jvalue file

        CLOSE ( JVUNIT )

C...Get met file offsets

        CALL SUBHFILE ( GRID_CRO_2D, GXOFF, GYOFF,
     &                  STRTCOLGC2, ENDCOLGC2, STRTROWGC2, ENDROWGC2 )
        CALL SUBHFILE ( MET_CRO_2D, GXOFF, GYOFF,
     &                  STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2 )
        CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                  STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

C...Get latitudes

        ALLOCATE ( LAT( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
        IF ( ALLOCSTAT .NE. 0 ) THEN
          XMSG = 'Failure allocating LAT'
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

        VARNM = 'LAT'
        XMSG = 'Could not read LAT from ' // GRID_CRO_2D
!       IF ( .NOT. INTERP3 ( GRID_CRO_2D, VARNM, PNAME,
!    &                       JDATE, JTIME, NCOLS * NROWS, LAT ) )
        IF ( .NOT. INTERPX( GRID_CRO_2D, VARNM, PNAME,
     &                      STRTCOLGC2,ENDCOLGC2, STRTROWGC2,ENDROWGC2, 1,1,
     &                      JDATE, JTIME, LAT ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...Get longitudes

        ALLOCATE ( LON( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
        IF ( ALLOCSTAT .NE. 0 ) THEN
          XMSG = 'Failure allocating LON'
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

        VARNM = 'LON'
        XMSG = 'Could not read LON from ' // GRID_CRO_2D
!       IF ( .NOT. INTERP3 ( GRID_CRO_2D, VARNM, PNAME,
!    &                       JDATE, JTIME, NCOLS * NROWS, LON ) )
        IF ( .NOT. INTERPX( GRID_CRO_2D, VARNM, PNAME,
     &                      STRTCOLGC2,ENDCOLGC2, STRTROWGC2,ENDROWGC2, 1,1,
     &                      JDATE, JTIME, LON ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...get height

        ALLOCATE ( HT( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
        IF ( ALLOCSTAT .NE. 0 ) THEN
          XMSG = 'Failure allocating HT'
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

        VARNM = 'HT'
        XMSG = 'Could not read HT from ' // GRID_CRO_2D
!       IF ( .NOT. INTERP3 ( GRID_CRO_2D, VARNM, PNAME,
!    &                       JDATE, JTIME, NCOLS * NROWS, HT ) )
        IF ( .NOT. INTERPX( GRID_CRO_2D, VARNM, PNAME,
     &                      STRTCOLGC2,ENDCOLGC2, STRTROWGC2,ENDROWGC2, 1,1,
     &                      JDATE, JTIME, HT ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

      END IF  ! FIRSTIME
 
C...compute XLHA (local hr angle) deviation from noon
C...  correct for current *positive* West longitude convention
 
      CURRHR = STRTHR 
     &       + FLOAT ( SECSDIFF ( STDATE, STTIME, JDATE, JTIME ) )
     &       / 3600.0 
      NDARK = 0
      DO ROW = 1, MY_NROWS
        DO COL = 1, MY_NCOLS
          XLHA( COL, ROW ) = CURRHR + LON( COL, ROW ) / 15.0 - 12.0
          NDAYS = NINT ( XLHA( COL, ROW ) / 24.0 )
          XLHA( COL, ROW ) = ABS ( XLHA( COL, ROW ) - NDAYS * 24.0 )
          IF ( XLHA( COL, ROW ) .GT.
     &         XHAJV( JVTMAX ) ) NDARK = NDARK + 1
        END DO
      END DO
 
C...If sun below horizon at all cells, zero photolysis rates & exit
C...  (assumes sun below horizon at *all* levels!)
 
      IF ( SE_SUM_CHK( NDARK, 'EQ', GL_NCOLS * GL_NROWS ) ) THEN
        DO JP = 1, NPHOTAB
          DO LEV = 1, NLAYS
            DO ROW = 1, MY_NROWS
              DO COL =1, MY_NCOLS
                RJ( COL, ROW, LEV, JP ) = 0.0
              END DO
            END DO
          END DO
        END DO
        WRITE( LOGDEV, 1003) JDATE, JTIME
1003    FORMAT( 8X, 'In darkness at ', I8.7, ':', I6.6,
     &          1X, 'GMT - no photolysis')
        RETURN
      END IF
 
C...Get heights of each level
 
      VARNM = 'ZH'
      XMSG = 'Could not read ZH from ' // MET_CRO_3D
!     IF( .NOT. INTERP3 ( MET_CRO_3D, VARNM, PNAME,
!    &                    MDATE, MTIME, NCOLS * NROWS * NLAYS, ZM ) )
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, ZM ) ) THEN
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF
 
C...compute clear-sky photolysis rates
 
      DO ROW = 1, MY_NROWS
        DO COL = 1, MY_NCOLS

C...Compute interpolation indices and weighting factors
 
C...  hr angle interpolation indices
 
          JVTM = 2
          DO NT = 2, JVTMAX - 1
            IF ( XLHA( COL, ROW ) .GT. XHAJV( NT ) )
     &        JVTM = NT + 1
          END DO
 
C...hr angle weighting factors
 
          FTIMO = ( XHAJV( JVTM ) - XLHA( COL, ROW ) )
     &          / ( XHAJV( JVTM ) - XHAJV( JVTM - 1 ) )
          OMFTIMO = ONE - FTIMO
 
c...latitude interpolation indices
 
          JLATN = 2
                
          DO NLAT = 2, JVLAT - 1
            IF ( LAT( COL, ROW ) .GT. XLATJV( NLAT ) )
     &        JLATN = NLAT + 1
          END DO
 
C...latitude weighting factors
 
          FLATS = ( XLATJV( JLATN ) - LAT( COL, ROW ) )
     &          / ( XLATJV( JLATN ) - XLATJV( JLATN - 1 ) )
          OMFLATS = ONE - FLATS
 
C...height interpolation indices 
 
          DO LEV = 1, NLAYS
            ZHT = ZM( COL, ROW, LEV ) + HT( COL, ROW )
            ZHT = MIN ( MAX ( ZHT,  XZJV( 1 ) ), XZJV( JVHT ) )
            KHTA = 2
        
            DO NHT = 2, JVHT - 1
              IF ( ZHT .GT. XZJV( NHT ) ) KHTA = NHT + 1
            END DO
  
C...height weighting factors
 
            FHTA = ( XZJV( KHTA ) - ZHT )
     &           / ( XZJV( KHTA ) - XZJV( KHTA - 1 ) )
            OMFHTA = ONE - FHTA
 
C...linear interpolation weighting factors
 
            JWT( 1 ) = OMFTIMO * OMFLATS * OMFHTA
            JWT( 2 ) =   FTIMO * OMFLATS * OMFHTA
            JWT( 3 ) = OMFTIMO *   FLATS * OMFHTA
            JWT( 4 ) =   FTIMO *   FLATS * OMFHTA
            JWT( 5 ) = OMFTIMO * OMFLATS * FHTA
            JWT( 6 ) =   FTIMO * OMFLATS * FHTA
            JWT( 7 ) = OMFTIMO *   FLATS * FHTA
            JWT( 8 ) =   FTIMO *   FLATS * FHTA
 
C...Interpolate all photolysis rates at each COL, ROW
 
            DO JP = 1, NPHOTAB
              JVAL = JWT( 1 ) * XJVAL( JP, JVTM, JLATN, KHTA )
     &             + JWT( 2 ) * XJVAL( JP, JVTM - 1, JLATN, KHTA )
     &             + JWT( 3 ) * XJVAL( JP, JVTM, JLATN - 1, KHTA )
     &             + JWT( 4 ) * XJVAL( JP, JVTM - 1, JLATN - 1, KHTA )
     &             + JWT( 5 ) * XJVAL( JP, JVTM, JLATN, KHTA - 1 )
     &             + JWT( 6 ) * XJVAL( JP, JVTM - 1, JLATN, KHTA - 1 )
     &             + JWT( 7 ) * XJVAL( JP, JVTM, JLATN - 1, KHTA - 1 )
     &             + JWT( 8 ) * XJVAL( JP, JVTM - 1, JLATN - 1,
     &                                 KHTA - 1 )
              RJ( COL, ROW, LEV, JP ) = MAX ( JVAL, 0.0 )
            END DO

          END DO     ! LEV
        END DO     ! COL
      END DO     ! ROW
      
C...At this point, clear sky photolysis rates have been calculated.
C...  Only proceed if interested in cloud effects on RJ
 
      IF ( CLDATT .NE. 0 ) THEN
 
C...Get time dependent non-layered data
 
C...Read & Interpolate WBAR
 
        VARNM = 'WBAR'
        XMSG = 'Could not read WBAR from ' // MET_CRO_2D
!       IF ( .NOT. INTERP3 ( MET_CRO_2D, VARNM, PNAME,
!    &                       MDATE, MTIME, NCOLS * NROWS, WBAR ) )
        IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                      STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                      MDATE, MTIME, WBAR ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF
 
C..Read & Interpolate CLDT
 
        VARNM = 'CLDT'
        XMSG = 'Could not read CLDT from ' // MET_CRO_2D
!       IF ( .NOT. INTERP3 ( MET_CRO_2D, VARNM, PNAME,
!    &                       MDATE, MTIME, NCOLS * NROWS, CLDT ) )
        IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                      STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                      MDATE, MTIME, CLDT ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF
 
C..Read & Interpolate CLDB
 
        VARNM = 'CLDB'
        XMSG = 'Could not read CLDB from ' // MET_CRO_2D
!       IF ( .NOT. INTERP3 ( MET_CRO_2D, VARNM, PNAME,
!    &                       MDATE, MTIME, NCOLS * NROWS, CLDB ) )
        IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                      STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                      MDATE, MTIME, CLDB ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF
 
C...Read & Interpolate CFRAC
 
        VARNM = 'CFRAC'
        XMSG = 'Could not read CFRAC from ' // MET_CRO_2D
!       IF ( .NOT. INTERP3 ( MET_CRO_2D, VARNM, PNAME,
!    &                       MDATE, MTIME, NCOLS * NROWS, CFRAC ) )
        IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                      STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                      MDATE, MTIME, CFRAC ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...Read & Interpolate RGRND
        VARNM = 'ATTEN'
        XMSG = 'Could not read ATTEN from ' // MET_CRO_2D
        IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                      STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                      MDATE, MTIME, ATTEN ) ) THEN
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...inclination angle used for zenith angle calculation

        INCANG = 23.5 * SINE ( ( JDSTRT + CURRHR / 24.0 - 81.1875 )
     &                       * ( 90.0 / 91.3125 ) )

C...loop through all cell and make the cloud correction

        DO ROW = 1, MY_NROWS
          DO COL = 1, MY_NCOLS

            CLDFR = CFRAC( COL, ROW )

            IF ( CLDFR .GE. 1.0E-05 ) THEN

C...calculate cloud correction factors
C...  first compute the liquid water path in g/m2

              CTOP  = CLDT( COL, ROW )
              CBASE = CLDB( COL, ROW )
              LWP   = ( CTOP - CBASE ) * WBAR( COL, ROW )

C...Calculate the cloud optical depth using a formula derived from
C...  Stephens (1978), JAS(35), pp2111-2132.
C...  only calculate the cloud optical depth when the liquid water
C...  path is >= 10 g/m2

              IF ( LWP .GE. 10.0 ) THEN
                CLOD = 10.0**( 0.2633 + 1.7095 * LOG( LOG10( LWP ) ) )
              ELSE
                CLOD = 0.0
              END IF

C...If no cloud or optical depth < 5, set clear sky values.
C...  (i.e. don't do anything)

              IF ( CLOD .GE. 5.0 ) THEN

                DO LEV = 1, NLAYS
                  ZLEV  = ZM( COL, ROW, LEV )
                  ZREL = ( ZLEV - CBASE ) / ( CTOP - CBASE )

C...cos of the zenith angle, ( <= cos 60 degrees )

                  ZEN = MAX ( SINE ( LAT( COL, ROW ) ) * SINE ( INCANG )
     &                      + COSINE ( LAT( COL, ROW ) )
     &                      * COSINE ( INCANG )
     &                      * COSINE ( XLHA( COL, ROW ) * 15.0 ), 
     &                      0.5
     &                      )
                  TRANS = ( 5.0 - EXP ( -CLOD ) ) / ( 4.0 + 0.42 * CLOD )

C...calculate cloud correction factors

C...  below cloud base

CRMM
!                 RADCLEAR = 1370.0 * ZEN ! solar const x cosine zenith angle
!                 RADFAC   = MIN( 1.0, ( RGRND( COL,ROW ) / RADCLEAR ) )
                  
!                 FCLDB = 1.0 + CLDFR * ( 1.6 * ZEN * TRANS - 1.0 )
                  FCLDB = MAX( MIN( 1.0, ATTEN( COL,ROW ) ), 0.0 )
CRMM
                  X1 = CLDFR * ZEN * ( 1.0 - TRANS )
                  X2 = FCLDB * ( 1.0 - ZREL )

C...  above cloud top

                  DO JP = 1, NPHOTAB
                    FCLDA = 1.0 + X1 * ACLD( PHID( JP ) )

C...  in cloud - linearly interpolate between base and top value

                    FCLD = FCLDA * ZREL + X2
                    IF ( ZLEV .LT. CBASE ) FCLD = FCLDB
                    IF ( ZLEV .GT.  CTOP ) FCLD = FCLDA

                    RJ( COL, ROW, LEV, JP ) = FCLD 
     &                                      * RJ( COL, ROW, LEV, JP )

                  END DO
                END DO
              END IF
            END IF
          END DO
        END DO

      END IF

      RETURN
      END SUBROUTINE PHOT
