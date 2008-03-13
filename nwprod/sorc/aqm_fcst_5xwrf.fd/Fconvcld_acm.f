
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/cloud/cloud_acm/convcld_acm.F,v 1.1.1.1 2005/09/09 18:56:05 sjr Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE CONVCLD_ACM ( JDATE, JTIME, TSTEP )

C-----------------------------------------------------------------------
C
C  FUNCTION: Convective cloud processor Models-3 science process:
C       MAIN ROUTINE calculates cloud characteristics, and uses them
C       to generate cumulative and net timestep deposition, cloud top,
C       cloud bottom, and pressure at the lifting level.
C
C       ICLDTYPE = 1 => computes raining cloud physics, mixing, chemistry,
C                       wet dep
C       ICLDTYPE = 2 => does the same for non-precip clouds utilizing saved
C                       info from RNCLD in the case of co-existing clouds
C
C  PRECONDITIONS REQUIRED:
C       Dates and times represented YYYYDDD:HHMMSS.
C
C  IDEA:   Aqueous chemistry operates on the half-hour for an internal
C          time step of one hour.
C
C  REVISION  HISTORY:
C       Adapted 3/93 by CJC from science module template
C       Version 3/3/93 with complete LCM aqueous chem by JNY.
C       Modified 6/3-7/93 by CJC & JNY to correct treatment of half layers
C       vs. full layers in loop 255:  calculation of DTDP centered at
C       quarter-layers using PSTAR; corresponding revisions to TLCL, TSAT.
C       Uses 4th order R-K solver there.
C       Version 6/5/93 by CJC using relative rainout rates.
C       Version 7/6/93 by CJC using INTERP3()
C       Adapted from LCM aqueous chemistry, initial version, 9/93
C              by JNY and CJC
C       Completion of EM cloud mixing, JNY 12/93
C       Inclusion of EM aqueous chemistry JNY 12/93
C       UPGRADE TO FULL RADM CLOUD MODULE EMULATION, JNY 4/94
C       8/16/94 by Dongming Hwang Configuration management template
C       Adapted 10/96 by S.Roselle for Models-3
C       1/97 s.roselle added McHenry's well mixed assumption code
C       8/97 S.Roselle revised cgrid units, pressure units, rainfall
C              to hourly amounts, built indices for wet dep species,
C              scavenged species, and aqueous species, built wrapper
C              around aqueous chemistry module
C       10/97 S.Roselle removed McHenry's well mixed assumption code
C              and put back the below cloud concentration scaling
C       11/97 S.Roselle moved the wet deposition output to the calling
C              routine--CLDPROC
C       01/98 S.Roselle moved indexing code to AQINTER, also
C              moved scavenging to SCAVWDEP
C       03/98 S.Roselle read sub-hourly rainfall data
C       12/98 David Wong at LM:
C             -- changed division of 8000, 2, 1000 to its corresponding
C                reciprocal
C              -- added INT in the expression STEP * 0.5 when calling SEC2TIME
C       03/99 David Wong at LM:
C             -- replaced "/ FRAC * .001" by "/ ( FRAC * 1000.0 )" to minimize
C                lost of significant digits in calculation
C       Jeff - Dec 00 - move CGRID_MAP into f90 module
C       Jeff - Sep 01 - Dyn Alloc - Use HGRD_DEFN
C       4/02 S.Roselle changed minimum horizontal resolution for subgrid
C             clouds from 12km to 8km.
C       1/05 J.Young: dyn alloc - establish both horizontal & vertical
C                     domain specifications in one module
C       5/05 J.Pleim Replaced cloud mixing algorithm with ACM
C       6/05 S.Roselle added new cloud diagnostic variables
C       7/05 J.Young: clean up and mod for CMAQ-F
C-----------------------------------------------------------------------

      USE CGRID_DEFN          ! inherits GRID_CONF and CGRID_SPCS
      USE WDEP_DEFN

      IMPLICIT NONE

C...........INCLUDES

!     INCLUDE SUBST_HGRD_ID             ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID             ! vertical dimensioning parameters

      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/GC_SPC.EXT"              ! gas chemistry species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/AE_SPC.EXT"              ! aerosol species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/NR_SPC.EXT"              ! non-reactive species table
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/TR_SPC.EXT"              ! tracer species table

      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/CONST.EXT"               ! constants
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/FILES_CTM.EXT"            ! file name parameters
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/PARMS3.EXT"             ! I/O parameters definitions
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/FDESC3.EXT"             ! file header data structuer
      INCLUDE "/nwpara/sorc/aqm_fcst_5xwrf.fd/IODECL3.EXT"              ! I/O definitions and declarations

!     INCLUDE SUBST_COORD_ID            ! coordinate and domain definitions (req IOPARMS)

      INCLUDE 'AQ_PARAMS.EXT'           ! aqueous chemistry shared parameters

C...........ARGUMENTS

!     REAL          CGRID( NCOLS,NROWS,NLAYS,* )  ! concentrations
!     REAL       :: CGRID( :,:,:,: )              ! concentrations
!     REAL, POINTER :: CGRID( :,:,:,: )           ! concentrations
      INTEGER       JDATE               ! current model date, coded YYYYDDD
      INTEGER       JTIME               ! current model time, coded HHMMSS
      INTEGER       TSTEP( 2 )          ! model time step, coded H*MMSS

C...........PARAMETERS

C critical rel humidity, lower bound (fraction)
      REAL, PARAMETER :: RCRIT1 = 0.7

C critical rel humidity, upper bound (fraction)
      REAL, PARAMETER :: RCRIT2 = 0.9

C param contlng sidewall entrainment function for raining clouds
      REAL, PARAMETER :: SIDEFAC = 0.5

C storm rainout efficiency
      REAL, PARAMETER :: STORME  = 0.3

C emp sat vapor press constant from RADM
      REAL, PARAMETER :: C303 = 19.83

C emp sat vapor press constant from RADM
      REAL, PARAMETER :: C302 = 5417.4

C g/kg
      REAL, PARAMETER :: GPKG = 1.0E+03

C 1 hectare = 1.0e4 m**2
      REAL, PARAMETER :: M2PHA = 1.0E+04

C subgrid scale temp perturb (deg K)
      REAL, PARAMETER :: PERT = 1.5

C " wvp mix ratio perturb (dimensionless)
      REAL, PARAMETER :: PERQ = 1.5E-3

C rainfall threshold in mm/hr (mm/hr)
      REAL, PARAMETER :: RTHRESH = 0.1

C vapor press of water at 0 C (Pa)
      REAL, PARAMETER :: VP0PA = 611.2

C 1.0 / (vapor press of water @ 0 C) (1/Pa)
      REAL, PARAMETER :: VPINV = 1.0 / VP0PA

C converg. crit. for entrainment solver
      REAL, PARAMETER :: TST = 0.01

C cloud lifetime (s)
      REAL, PARAMETER :: TAUCLD = 3600.0

C ratio of mol wt of water vapor to mol wt of air
      REAL, PARAMETER :: MVOMA = MWWAT / MWAIR

C ratio of dry gas const to specific heat
      REAL, PARAMETER :: ROVCP = RDGAS / CPD

C ratio of latent heat of vap to specific heat
      REAL, PARAMETER :: LVOCP = LV0 / CPD

C dry adiabatic lapse rate (deg K/m)
      REAL, PARAMETER :: DALR = GRAV / CPD

C Number of species in CGRID
      INTEGER, PARAMETER :: MXSPCS = N_GC_SPCD
     &                             + N_AE_SPC
     &                             + N_NR_SPC
     &                             + N_TR_SPC

C...........LOCAL VARIABLES

      INTEGER       ICLDTYPE            ! 1: raining, 2: either CNP or PFW
!     INTEGER       N_SPC_WDEP          ! # of wet deposition species
!     INTEGER       WDEP_MAP( * )       ! wet deposition map to CGRID
!     INTEGER       WDEP_MAP( : )       ! wet deposition map to CGRID
!     REAL          CONV_DEP( NCOLS, NROWS, * )  ! depositions (etc.)
!     REAL       :: CONV_DEP( :,:,: )   ! depositions (etc.)

C-------for ACM version - jp 2/05
      REAL, ALLOCATABLE, SAVE :: SIGF( : )
      REAL CCR( MXSPCS,NLAYS ), CONC( MXSPCS,NLAYS ), CBELOW( MXSPCS )
C-------------------------------------------

      INTEGER, SAVE :: LOGDEV

      CHARACTER( 120 ) :: XMSG = ' '    ! Exit status message
      LOGICAL, SAVE :: FIRSTIME = .TRUE. ! flag for first pass thru
      LOGICAL, SAVE :: CONVCLD = .TRUE.  ! flag for modeling convective clds

      CHARACTER( 16 ) :: PNAME = 'CONVCLD_ACM' ! prcess name
      CHARACTER( 16 ) :: VARNM      ! variable name for IOAPI to get

      INTEGER          ATIME        ! time diff from half-hour
      INTEGER          CLTOP        ! model LAY containing cloud top
      INTEGER          COL          ! column loop counter
      INTEGER          ROW          ! row loop counter
      INTEGER          CTOP         ! dummy variable for cloud top layer
      INTEGER          FINI         ! ending position
      INTEGER          I599C        ! entrainment solver iteration counter
      INTEGER          LAY          ! layer loop counter
      INTEGER          MDATE        ! process date
      INTEGER          MTIME        ! process time (half-hour)
      INTEGER, SAVE :: MSTEP        ! met file time step (hhmmss)
      INTEGER, SAVE :: SDATE        ! met file start date
      INTEGER          SPC          ! liquid species loop counter
      INTEGER          STEP         ! step loop counter
      INTEGER          STRT         ! starting position
      INTEGER, SAVE :: STIME        ! met file start time
      INTEGER          VAR          ! variable loop counter

!     INTEGER          CLBASE    ( NCOLS,NROWS ) ! cld base layer
!     SAVE             CLBASE
!     INTEGER          CLTOPUSTBL( NCOLS,NROWS ) ! unstable cld top layer
!     SAVE             CLTOPUSTBL
!     INTEGER          IRNFLAG   ( NCOLS,NROWS ) ! 0: no raining cld 1: raining cloud
!     SAVE             IRNFLAG
!     INTEGER          ISOUND    ( NCOLS,NROWS ) ! flag for sounding stability
!     SAVE             ISOUND
!     INTEGER          SRCLAY    ( NCOLS,NROWS ) ! cloud source level vert index
!     SAVE             SRCLAY
!     INTEGER, ALLOCATABLE, SAVE :: CLBASE    ( :,: ) ! cld base layer
      INTEGER       CLBASE                            ! cld base layer
!     INTEGER, ALLOCATABLE, SAVE :: CLTOPUSTBL( :,: ) ! unstable cld top layer
      INTEGER       CLTOPUSTBL                        ! unstable cld top layer
!     INTEGER, ALLOCATABLE, SAVE :: IRNFLAG   ( :,: ) ! 0: no raining cld 1: raining cloud
!     INTEGER, ALLOCATABLE, SAVE :: ISOUND    ( :,: ) ! flag for sounding stability
      INTEGER          ISOUND              ! flag for sounding stability
!     INTEGER, ALLOCATABLE, SAVE :: SRCLAY    ( :,: ) ! cloud source level vert index
      INTEGER          SRCLAY       ! cloud source level vert index

      REAL             AIRM         ! total air mass (moles/m2) in cloudy air
      REAL             AIRMB0       ! moles/m2 air below cloud
      REAL             AIRMBI       ! inverse moles/m2 air below cloud
      REAL             ALFA0        ! aitken mode number scavenging coef
      REAL             ALFA2        ! aitken mode sfc area scavenging coef
      REAL             ALFA3        ! aitken mode mass scavenging coef
      REAL             ARPRES       ! ave cloud pres in atm
      REAL             CONDIS       !
      REAL             CTHK         ! cloud thickness (m)
      REAL             CTHK1        ! aq chem calc cloud thickness
      REAL             DAMDP        ! dry adiabatic minus dew point lapse rate
      REAL             DP           ! pressure increment along moist adiabat
      REAL             DPLR         ! dew point lapse rate
      REAL             DQI          ! change in ice mix ratio due to melting caused by entrainment
      REAL             DQL          ! change in liq wat mix ratio due to evap caused by entrainment
      REAL             DTDP         ! moist adiabatic lapse rate
      REAL             DZLCL        ! height increment to LCL above source level
      REAL             EMAX         ! water vapor pressure at source level
      REAL             EQTH         ! parcel equivalent potential temperature
      REAL             EQTHM        ! parcel equivalent potential temp
      REAL             FA           ! entrainment functional value at TEMPA
      REAL             FB           ! entrainment functional value at TEMPB
      REAL             FRAC         ! cloud fractional coverage
      REAL             FTST         ! functional product in Walcek bisection solver
      REAL             HTST         ! temp diff in Walcek bisection solver
      REAL, SAVE    :: METSTEP      ! timestep on the met file
      REAL             P1           ! intermediate pressure used in calculating WL
      REAL             P2           ! intermediate pressure used in calculating WL
      REAL             P3           ! intermediate pressure used in calculating WL
      REAL             PBAR         ! mean pressure in vertical increments up from LCL along moist adiabat
      REAL             PBARC        ! mean cloud pressure (Pa)
      REAL             PMAX         ! parcel pressure
      REAL             PP           ! scratch pressure variable
      REAL             PRATE        ! total rainfall (mm/hr)
      REAL             PRATE1       ! storm rainfall rate (mm/hr)
      REAL             QENT         ! wat vap mix ratio due to cld sidewall entrainmt
      REAL             QP           ! perturbed water vap mix ratio of parcel
      REAL             QXS          ! int. excess wat ov grid cell needed for rainout
      REAL             REMOVAC      ! variable storing H+ deposition
      REAL             RHOAIR       ! air density in kg/m3
      REAL             RLH          ! relative humidity
      REAL             RLHSRC       ! relative humidity at cld src level
      REAL             RTCH         ! chemical gas const times temp
      REAL             T1           ! perturbed temp to calc neutral buoyancy also used as max temp in cell comparing cloud with environment
      REAL             TBAR         ! mean temp in vertical increments up from LCL along moist adiabat
      REAL             TBARC        ! mean cloud temp (K)
      REAL             TBASE        ! iterative temp along moist adiabat
      REAL             TDMAX        ! dew point at source level
      REAL             TEMPA        ! lower limit on temp for entrainment solver
      REAL             TEMPB        ! upper limit on temp for entrainment solver
      REAL             TEMPC        ! scratch temp solved for cloudy air parcel
      REAL             TENT         ! temp accounting for cld sidewall entrainment
      REAL             THMAX        ! parcel potential temperature
      REAL             TI           ! init temp of cloud air before evap of water
      REAL             TLCL         ! temp at LCL
      REAL             TMAX         ! perturbed temp of parcel
      REAL             TP           ! perturbed temp of parcel
      REAL             TTOP         ! scr vbl used in application of Eq. 7, W&T
      REAL             TWC          ! tot wat cont in cloud (kg H2O/m3 air)
      REAL             WCBAR        ! liq water content of cloud (kg/m3)
      REAL             WL           ! Warner profile (an earlier version appears appears in Walcek and Taylor (JAS, 1986)
      REAL             WTBAR        ! total wat cont (kg/m2) int. thru cloud depth
      REAL             X1           ! intermediate vbles in lapse rate calculation X1 also reused as scratch vble in mixing
      REAL             XXXX         ! scratch vbl used in entrainment solver
      REAL, SAVE    :: AECONCMIN( N_AE_SPCD ) ! array of minimum concentrations
      REAL             BMOL   ( MXSPCS ) ! moles/m2 species below cloud
      REAL             CBASE0 ( MXSPCS ) ! initial ave trace gas mix rat below cld
      REAL             CBASEF ( MXSPCS ) ! final ave trac gas mix rat blw cld (moles/mole)
      REAL             CEND   ( MXSPCS ) ! ending equiv gas phase conc (moles/mole)
      REAL             POLC   ( MXSPCS ) ! ave vert conc incloud moles sp/m2 and moles sp/ mole air
      REAL             REMOV  ( MXSPCS ) ! moles/m2 or mm*mol/lit scavenged
      REAL             DENSL( NLAYS )    ! air density (kg/m3)
      REAL             F    ( NLAYS )    ! cloud entrainment fraction to be solved for
      REAL             FSIDE( NLAYS )    ! sidewall entrainment vertical profile
      REAL             LWC  ( NLAYS )    ! liq wat cont of cloud in kg H2O/m3 air
      REAL             QICE ( NLAYS )    ! ice mixing ratio in cloud
      REAL             QLQD ( NLAYS )    ! actual liq. wat. mix ratio in cloud
      REAL             QVC  ( NLAYS )    ! saturation wat vap mix ratio at T1
      REAL             QWAT ( NLAYS )    ! liq wat mix rat, taken as total condensed water (ice + liq) profile (Eq.4, W&T)
      REAL             RHOM2( NLAYS )    ! moles/m2 air
      REAL             TCLD ( NLAYS )    ! temp of cloudy air parcel
!     REAL             ACTRNMA( NCOLS,NROWS ) ! actual fraction of below cld layer mass convected into raining cloud
!     SAVE             ACTRNMA
!     REAL             FRACMAX( NCOLS,NROWS ) !  max frac cov for NP cld
!     SAVE             FRACMAX
!     REAL             FWXFRAC( NCOLS,NROWS ) ! storage array for actual NP cld frac
!     SAVE             FWXFRAC
!     REAL             PLCL   ( NCOLS,NROWS ) ! pressure at LCL
!     SAVE             PLCL
!     REAL             QMAX   ( NCOLS,NROWS ) ! pertbd w.. mix rat of parcel
!     SAVE             QMAX
!     REAL             TOTFRAC( NCOLS,NROWS ) !  total frac cloud cover
!     SAVE             TOTFRAC
!     REAL, ALLOCATABLE, SAVE :: ACTRNMA( :,: ) ! actual fraction of below cld layer mass convected into raining cloud
!     REAL, ALLOCATABLE, SAVE :: FRACMAX( :,: ) !  max frac cov for NP cld
      REAL             FRACMAX                  !  max frac cov for NP cld
!     REAL, ALLOCATABLE, SAVE :: PLCL   ( :,: ) ! pressure at LCL
      REAL             PLCL                     ! pressure at LCL
!     REAL, ALLOCATABLE, SAVE :: QMAX   ( :,: ) ! pertbd w.. mix rat of parcel
      REAL             QMAX                     ! pertbd w.. mix rat of parcel
!     REAL, ALLOCATABLE, SAVE :: TOTFRAC( :,: ) !  total frac cloud cover
      REAL             RAIN   ( NCOLS,NROWS ) !  this timestep rainfall (mm/hr)

      REAL             BCLDWT  ( MXSPCS,NLAYS ) ! below cloud weighting function
      REAL             CONCMINL( MXSPCS,NLAYS ) ! minimum concentrations for each species and layer
      REAL             INCLOUD ( MXSPCS,NLAYS ) ! fin. in cloud conc. after mix and chem moles/mole
      REAL             OUTCLOUD( MXSPCS,NLAYS ) ! fin. outside cld conc. "   "   "   " moles/mole
      REAL             PCLD    ( MXSPCS,NLAYS ) ! moles sp/mole air in cloud

      REAL             RC   ( NCOLS,NROWS ) ! hourly convective rainfall (cm)
      REAL             DZZ  ( NCOLS,NROWS,NLAYS )  ! computed gridded vble
      REAL             DZZL ( NLAYS )              ! grid cell delta Z
      REAL             PRES ( NCOLS,NROWS,NLAYS )  ! file gridded vble
      REAL             PRESL( NLAYS )              ! grid cell pressure
!     REAL             QAD  ( NCOLS,NROWS,NLAYS )  ! moist adiab. sat. mix ratio
!     SAVE             QAD
!     REAL, ALLOCATABLE, SAVE :: QAD  ( :,:,: )  ! moist adiab. sat. mix ratio
      REAL             QAD  ( NLAYS )              ! moist adiab. sat. mix ratio
      REAL             QV   ( NCOLS,NROWS,NLAYS )  ! input gridded vble
      REAL             QVL  ( NLAYS )              ! grid cell sp. hum.
      REAL             TA   ( NCOLS,NROWS,NLAYS )  ! input gridded vble
      REAL             TAL  ( NLAYS )              ! grid cell temp
!     REAL             TSAT ( NCOLS,NROWS,NLAYS )  ! parcel temp along moist adiabat @ half levels
!     SAVE             TSAT
!     REAL, ALLOCATABLE, SAVE :: TSAT ( :,:,: )  ! parcel temp along moist adiabat @ half levels
      REAL             TSAT ( NLAYS )            ! parcel temp along moist adiabat @ half levels
      REAL             ZH   ( NCOLS,NROWS,NLAYS )  ! mid-layer height (m)
      REAL             ZF   ( NCOLS,NROWS,NLAYS )  ! level/layer-face height (m)

      INTEGER      ALLOCSTAT

      INTEGER      GXOFF, GYOFF              ! global origin offset from file
C for INTERPX
      INTEGER, SAVE :: STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3

C...........EXTERNAL FUNCTIONS

      LOGICAL, EXTERNAL :: CURRSTEP
      INTEGER, EXTERNAL :: SEC2TIME, SECSDIFF, TIME2SEC, SETUP_LOGDEV

C...........STATEMENT FUNCTIONS

      REAL          ESAT                ! sat vap pres (Pa) as fn of T (deg K)
      REAL          QSAT                ! sat water vapor mixing ratio

      REAL          T                   ! temperature dummy arg
      REAL          E                   ! sat vapor pressure dummy arg
      REAL          P                   ! pressure dummy arg

      ESAT( T ) = VP0PA * EXP( C303 - ( C302 / T ) )

      QSAT( E, P ) = MVOMA * ( E / ( P - E ) )

C-----------------------------------------------------------------------
C  begin body of subroutine CONVCLD_ACM

C...INITIALIZATION for the CONVCLD_ACM module:
C...  event-statistics variables.

      IF ( FIRSTIME ) THEN

        FIRSTIME = .FALSE.
!       LOGDEV = INIT3()
        LOGDEV = SETUP_LOGDEV()

        CALL CGRID_MAP( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )

        IF ( N_AE_SPC .GT. 0 ) CALL SET_AECONCMIN ( AECONCMIN )

C...check the grid resolution from the MET_CRO_2D and set an appropriate
C...  flag as to whether convective clouds should be run for the given
C...  resolution

C...open MET_CRO_3D

        IF ( .NOT. OPEN3( MET_CRO_3D, FSREAD3, PNAME ) ) THEN
          XMSG = 'Could not open '// MET_CRO_3D // ' file'
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...get description from the met file

        IF ( .NOT. DESC3( MET_CRO_2D ) ) THEN
          XMSG = 'Could not get ' // MET_CRO_2D //' file description'
          CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

C...set flag to false if grid scale is less than 8 km

        IF ( ( XCELL3D .LT. 8000.0 ) .OR.
     &       ( YCELL3D .LT. 8000.0 ) ) THEN
          CONVCLD = .FALSE.
          XMSG = 'Grid resolution too small to run a sub-grid-scale '//
     &           'convective cloud scheme.'
          CALL M3WARN ( PNAME, JDATE, JTIME, XMSG )
          XMSG = 'An explicit cloud scheme should be used.'
          CALL M3MESG ( XMSG )
        END IF

C...store met file time, date, and step information and compute
C...  the met timestep in hours

        SDATE = SDATE3D
        STIME = STIME3D
        MSTEP = TSTEP3D

        METSTEP = FLOAT( TIME2SEC( MSTEP ) ) / 3600.0

C...get horizontal domain window from met data

        CALL SUBHFILE ( MET_CRO_2D, GXOFF, GYOFF,
     &                  STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2 )

        CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                  STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

C...allocate saved arrays

!       ALLOCATE ( FRACMAX   ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( TOTFRAC   ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( IRNFLAG   ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       IF ( ALLOCSTAT .NE. 0 ) THEN
!          XMSG = 'Failure allocating FRACMAX or TOTFRAC or IRNFLAG'
!          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!       END IF
!       ALLOCATE ( ACTRNMA   ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( CLBASE    ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( CLTOPUSTBL( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       IF ( ALLOCSTAT .NE. 0 ) THEN
!          XMSG = 'Failure allocating ACTRNMA or CLBASE or CLTOPUSTBL'
!          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!       END IF
!       ALLOCATE ( QMAX      ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( PLCL      ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( SRCLAY    ( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       IF ( ALLOCSTAT .NE. 0 ) THEN
!          XMSG = 'Failure allocating QMAX or PLCL or SRCLAY'
!          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!       END IF
!       ALLOCATE ( ISOUND( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       ALLOCATE ( QAD   ( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!       ALLOCATE ( TSAT  ( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!       IF ( ALLOCSTAT .NE. 0 ) THEN
!          XMSG = 'Failure allocating ISOUND or QAD or TSAT'
!          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!       END IF

        ALLOCATE ( SIGF( 0:NLAYS ), STAT = ALLOCSTAT )
        IF ( ALLOCSTAT .NE. 0 ) THEN
          XMSG = 'Failure allocating SIGF'
          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
        END IF

        DO LAY = 1, NLAYS
          SIGF( LAY ) = 1 - X3FACE_GD( LAY )
        END DO
        SIGF( 0 ) = 1.0

      END IF   ! Firstime

C...Check to see if this time step contains the half-hour
C...  if it does not, then return

      MDATE = JDATE
      MTIME = 10000 * ( JTIME / 10000 )      ! on the current hour
      STEP  = TIME2SEC( TSTEP( 2 ) )         ! syncronization timestep

C...  set mdate:mtime to one-half step before the half-hour

      CALL NEXTIME ( MDATE, MTIME, SEC2TIME( 1800 - ( STEP / 2 ) ) )

      ATIME = SECSDIFF( MDATE, MTIME, JDATE, JTIME )

      IF ( ( ( ATIME .LT. 0 ) .OR. ( ATIME .GE. STEP ) ) .OR.
     &     ( .NOT. CONVCLD ) ) RETURN

C...the current timestep overlaps the half hour point
C...  set the time to the half hour for data interpolation

      MTIME = 10000 * ( JTIME / 10000 ) + 3000

C...ACTUAL SCIENCE PROCESS (loop on internal process time steps):
C...  Interpolate time dependent layered input variables
C...  (reading those variables for which it is necessary)

C...  Get ambient temperature (K)

!     ALLOCATE ( TA( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating TA'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'TA'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VARNM, PNAME, MDATE, MTIME,
!    &                    NCOLS * NROWS * NLAYS, TA ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, TA ) ) THEN
        XMSG = 'Could not read TA from' // MET_CRO_3D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...Get specific humidity (kg H2O / kg air)

!     ALLOCATE ( QV( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating QV'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'QV'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VARNM, PNAME, MDATE, MTIME,
!    &                    NCOLS * NROWS * NLAYS, QV ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, QV ) ) THEN
        XMSG = 'Could not read QV from ' // MET_CRO_3D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...Get level heights / layer faces (m)

!     ALLOCATE ( ZF( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating ZF'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'ZF'
!     IF ( .NOT. INTERP3 ( MET_CRO_3D, VARNM, PNAME, MDATE, MTIME,
!    &                     NCOLS * NROWS * NLAYS, ZF ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, ZF ) ) THEN
        XMSG = 'Could not read ZF from ' // MET_CRO_3D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...Get mid-layer heights (m)

!     ALLOCATE ( ZH( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating ZH'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'ZH'
!     IF ( .NOT. INTERP3 ( MET_CRO_3D, VARNM, PNAME, MDATE, MTIME,
!    &                     NCOLS * NROWS * NLAYS, ZH ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, ZH ) ) THEN
        XMSG = 'Could not read ZH from ' // MET_CRO_3D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...Get pressure (Pa)

!     ALLOCATE ( PRES( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating PRES'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'PRES'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VARNM, PNAME, MDATE, MTIME,
!    &                    NCOLS * NROWS * NLAYS, PRES ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VARNM, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, PRES ) ) THEN
        XMSG = 'Could not read PRES from ' // MET_CRO_3D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...compute layer thicknesses (m)

!     ALLOCATE ( DZZ( MY_NCOLS,MY_NROWS,NLAYS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating DZZ'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      DO ROW = 1, MY_NROWS
        DO COL = 1, MY_NCOLS
          DZZ( COL, ROW, 1 ) = ZF( COL, ROW, 1 )
          DO LAY = 2, NLAYS
            DZZ( COL, ROW, LAY ) = ZF( COL, ROW, LAY )
     &                           - ZF( COL, ROW, LAY - 1 )
          END DO
        END DO
      END DO

C...advance the MDATE and MTIME to the next time on the met file
C...  to get ready to read the precipitation amounts.
C...  Precipitation data WILL NOT BE INTERPOLATED!  Precipitation data
C...  on the input file are amounts within the metfiles timestep.

      IF ( .NOT. CURRSTEP( JDATE, JTIME, SDATE, STIME, MSTEP,
     &                     MDATE, MTIME ) ) THEN
        XMSG = 'Cannot get step-starting date and time'
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
      END IF

      CALL NEXTIME ( MDATE, MTIME, MSTEP )  ! set mdate:mtime to the hour

C...Get convective precipitation amount (cm)

!     ALLOCATE ( RC( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!     IF ( ALLOCSTAT .NE. 0 ) THEN
!        XMSG = 'Failure allocating RC'
!        CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      VARNM = 'RC'
!     IF ( .NOT. READ3( MET_CRO_2D, VARNM, ALLAYS3, MDATE, MTIME,
!    &                  RC ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_2D, VARNM, PNAME,
     &                    STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                    MDATE, MTIME, RC ) ) THEN
        XMSG = 'Could not read RC from ' // MET_CRO_2D
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

C...Convert the rainfall rate into mm/hr, then set a flag noting the
C...  presence of raining clouds if the rainfall is above the specified
C...  threshold

!      IF ( ICLDTYPE .EQ. 1 ) THEN

!       ALLOCATE ( RAIN( MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
!       IF ( ALLOCSTAT .NE. 0 ) THEN
!          XMSG = 'Failure allocating RAIN'
!          CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!       END IF

        DO ROW = 1, MY_NROWS
          DO COL = 1, MY_NCOLS

            RAIN( COL, ROW ) = 10.0 * RC( COL, ROW ) / METSTEP

            IF ( RAIN( COL, ROW ) .LT. 0.0 ) THEN
              XMSG = 'NEGATIVE RAIN...PROBABLE BAD MET DATA...'
     &                // MET_CRO_2D
              CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF

            IF ( RAIN( COL, ROW ) .GE. RTHRESH ) THEN
              CONV_DEP( COL, ROW, N_SPC_WDEP + 6 ) = 1.0
            END IF

          END DO
        END DO

!      END IF

C...Loop through all grid cells

      DO 311 ROW = 1, MY_NROWS
        DO 301 COL = 1, MY_NCOLS

!d        TOTFRAC( COL, ROW ) = 0.0
!d        ACTRNMA( COL, ROW ) = 0.0
!         CLBASE ( COL, ROW ) = NLAYS
!         CLTOPUSTBL( COL, ROW ) = NLAYS
!         QMAX  ( COL, ROW ) = 0.0
!         PLCL  ( COL, ROW ) = 0.0
!         SRCLAY( COL, ROW ) = NLAYS
          CLBASE = NLAYS
          CLTOPUSTBL = NLAYS
          QMAX  = 0.0
          PLCL  = 0.0
          SRCLAY = NLAYS

          DO LAY = 1, NLAYS
!           QAD( COL, ROW, LAY ) = 0.0
            QAD( LAY ) = 0.0
            PRESL( LAY ) = PRES( COL,ROW,LAY )
            TAL( LAY ) = TA( COL,ROW,LAY )
            QVL( LAY ) = QV( COL,ROW,LAY )
            DZZL( LAY ) = DZZ( COL,ROW,LAY )
            DENSL( LAY ) = PRESL( LAY )
     &                   / ( RDGAS * TAL( LAY ) )
          END DO

C...load aerosol minimum concentrations into the "CONCMINL" array
C...  initialize all species to CMIN

!         CONCMINL = CMIN
          CONCMINL =  1.0E-25

C...  set minimum for aerosol species

          SPC = 0
          STRT = AE_STRT
          FINI = AE_STRT - 1 + N_AE_SPC
          DO VAR = STRT, FINI
            SPC = SPC + 1
            DO LAY = 1, NLAYS
              CONCMINL( VAR, LAY ) = AECONCMIN( SPC ) / DENSL( LAY )
            END DO
          END DO

          DO LAY = 1, NLAYS
            DO SPC = 1, NSPCSD
!             CONC( SPC,LAY ) = CGRID( COL,ROW,LAY,SPC )
              CONC( SPC,LAY ) = MAX( CGRID( COL,ROW,LAY,SPC ),
     &                               CONCMINL( SPC, LAY ) )
            END DO
          END DO

C...first test for raining clouds
          IF ( RAIN( COL, ROW ) .GE. RTHRESH ) THEN
            ICLDTYPE = 1
          ELSE
            ICLDTYPE = 2
          END IF

          IF ( ICLDTYPE .EQ. 1 ) THEN

C...if the rainfall amount is below the specified threshold, then set
C...  values for some of the parameters which will be used when the
C...  routine is called again for non-precipitating clouds...then
C...  skip to the next grid cell.

            PRATE  = RAIN( COL, ROW )
!           FRACMAX( COL, ROW ) = 0.0
!d          IRNFLAG( COL, ROW ) = 1
            FRACMAX = 0.0

          ELSE

!           FRACMAX( COL, ROW ) = 0.5
!d          IRNFLAG( COL, ROW ) = 0
            FRACMAX = 0.5

          END IF              ! end of cld type test

C...Determine cloud source level by determining equivalent
C...   potential temperature profile given perturbed temperature
C...   and water vapor to account for local hot spots which
C...   initiate convection.  Layer with maximum equivalent
C...   potential temperature is cloud source layer.

          SRCLAY = 1
          TMAX  = TAL( 1 ) + PERT
          QMAX  = QVL( 1 ) + PERQ
          PMAX  = PRESL( 1 )
          THMAX = TMAX * ( 100000.0 / PMAX ) ** ROVCP
!         EQTHM = THMAX * EXP( LVOCP * QMAX( COL, ROW ) / TMAX )
          EQTHM = THMAX + ( LVOCP * QMAX * THMAX / TMAX )
!         WRITE( LOGDEV,* ) ' THMAX,EQTHM=',THMAX,EQTHM

          DO 222 LAY = 2, NLAYS

            PP = PRESL( LAY )

            IF ( PP .LT. 65000.0 ) GO TO 223  !  loop exit

            TP = TAL( LAY ) + PERT
            QP = QVL( LAY ) + PERQ
            THMAX = TP * ( 100000.0 / PP )**ROVCP
            EQTH = THMAX * EXP( LVOCP * QP / TP )
!           EQTH = THMAX + ( LVOCP * QP *THMAX/ TP )
!           WRITE( LOGDEV,* ) ' PP,TP,QP,THMAX,EQTH=',PP,TP,QP,THMAX,EQTH

            IF ( EQTH .GT. EQTHM ) THEN

              TMAX = TP
              SRCLAY = LAY
              QMAX  = QP
              PMAX = PP
              EQTHM = EQTH

            END IF

222       CONTINUE

223       CONTINUE    !  loop exit target

C...Equivalent potential temp max is now known  between LAY 1
C...   and 650 mb. We now proceed to compute lifting condensation
C...   level.  First,  compute vapor pressure at the source level.
C...   Find dewpoint using empirical relationship, avoiding
C...   supersaturation.   Then compute dew point lapse rate -
C...   see Walcek and Taylor, 1986.

          EMAX  = QMAX * PMAX / ( MVOMA + QMAX )
          TDMAX = C302 / ( C303 - ALOG( EMAX * VPINV ) )            !??????
          TDMAX = MIN( TDMAX, TMAX )
          DPLR  = ( GRAV * TDMAX * TDMAX ) / ( MVOMA * LV0 * TMAX )
!         WRITE( LOGDEV,* ) ' SLAY,EQTHM,TDMAX,DPLR=',
!    &                  SRCLAY, EQTHM, TDMAX, DPLR

C...Compute difference between dry adiabatic and dew point lapse
C...   rate, height increment above source level to reach LCL,
C...   then calculate value of pressure at LCL.  Save result
C...   in DEP( *,*,N_SPC_WDEP+2 ).

          DAMDP = DALR - DPLR

          IF ( DAMDP .LE. 0.0 ) THEN

            DZLCL = 0.0
            PLCL = PMAX
C...walcek formula
            TLCL = TMAX
C...walcek formula

          ELSE

            DZLCL = ( TMAX - TDMAX ) / DAMDP
C...walcek formula
            TLCL = TMAX - DALR * DZLCL
C...walcek formula
            TBAR = TMAX - 0.5 * DALR * DZLCL   !  midpt of TMAX, TLCL
            TBAR = MAX( TBAR , 150.0 )
            PLCL = PMAX * EXP( -( GRAV / RDGAS ) * DZLCL / TBAR )

          END IF

!         WRITE( LOGDEV,* ) ' SRCLAY=', SRCLAY

          CONV_DEP( COL, ROW, N_SPC_WDEP + 2 ) = PLCL

C...Determine cloud base at LAY in  which LCL resides,
C...  but not below layer 2.

C...plcl above middle of top layer

          IF ( PRESL( NLAYS ) .GE. PLCL ) THEN
            PLCL = PRESL( NLAYS )
            CLBASE = NLAYS
            CLTOP = CLBASE
            WRITE( LOGDEV,* ) ' WARNING: PLCL above top: Continuing'

C...search loop to find CLBASE

          ELSE

            DO LAY = 2, NLAYS
              IF ( PRESL( LAY ) .LE. PLCL ) THEN
                CLBASE = LAY
                GO TO 245
              END IF
            END DO

            CLBASE = NLAYS   ! if you get here base never found

245         CONTINUE

          END IF      ! if plcl < ptop or , or ...

C...CLBASE is LAY of LCL. Now, determine cloud top by following
C...   moist adiabat up from CLBASE. Assume a stable sounding
C...   (ISOUND=0) at first.  Moist adiabat solver calculates
C...   saturation temperatures TF at the full levels and TSAT( COL, ROW, LAY )
C...   at the half-levels, using a 2nd order Runge method employing
C...   temperatures and pressures at the quarter-levels.

          ISOUND = 0
          DO 255 LAY = CLBASE, NLAYS

c...walcek formulas

            DP   = PRESL( LAY - 1 ) - PRESL( LAY )
            PBAR = PRESL( LAY - 1 ) - DP * 0.5
            IF ( LAY .EQ. CLBASE ) THEN
              DP    = PLCL - PRESL( LAY )
              PBAR  = PLCL - DP * 0.5
              TBASE = TLCL
            END IF

            TBAR = MAX( TBASE - 0.00065 * DP, 150.0 )
            X1 = LV0 * QSAT( ESAT( TBAR ), PBAR ) / ( RDGAS * TBAR ) ! Walcek's
            DTDP = ( ( RDGAS * TBAR ) / ( PBAR * CPD ) )            ! original
     &           * ( ( 1.0 + X1 )                                   ! formulas
     &           / ( 1.0 + ( 0.622 * LVOCP / TBAR ) * X1 ) )
            TSAT( LAY ) = MAX( TBASE - DP * DTDP, 150.0 )
            QAD ( LAY ) = QSAT( ESAT( TSAT( LAY ) ), PRESL( LAY ) )
            TBASE = TSAT( LAY )

C...end Walcek formulas

C...QAD is the moist adiabatic saturation mixing ratio, needed
C...  for the entrainment solver
C...  Now make choice on stability of sounding, comparing parcel
C...  temperature TSAT with environmental temperature TA.
C...  ISOUND is index for sounding stability. If ISOUND=0,
C...  moist adiabat never warmer than environment (stable).
C...  ISOUND=1, moist adiabat becomes warmer than environment
C...  (unstable).

            IF ( ISOUND .EQ. 0 ) THEN
              IF ( TSAT( LAY ) .GT. TAL( LAY ) ) THEN
                ISOUND = 1
              END IF
            ELSE           ! cloud top determined by neutral bouyancy
              T1 = TSAT( LAY ) - 0.5 * PERT
              IF ( T1 .LT. TAL( LAY ) ) THEN
                CLTOP = LAY - 1
                GO TO 256
              END IF
            END IF

255       CONTINUE            !  end loop following moist adiabat

          CLTOP = NLAYS - 1   !  if you get to here:  cloud stable or no top
256       CONTINUE

C...At this point, if ISOUND has not been set to 1, we have a
C...  "stable" cloud. In this case, we find cloud top by relative
C...   humidity criterion, or, not let cloud top go above 600mb.

!         IF ( ISOUND .EQ. 0 ) THEN
          IF ( ISOUND .EQ. 0 ) GO TO 301

!           DO 265 LAY = CLBASE + 1, NLAYS
!             IF ( PRESL( LAY ) .LE. 60000.0 ) THEN
!               CLTOP = LAY - 1
!               GO TO 267        !  loop exit
!             END IF
!             RLH = QVL( LAY )
!    &            / QSAT( ESAT( TAL( LAY ) ), PRESL( LAY ) )
!             IF ( RLH .LT. 0.65 ) THEN
!               CLTOP = LAY - 1
!               GO TO 267        !  to loop exit
!             END IF
265         CONTINUE

!           CLTOP = NLAYS - 1   !  if you get to here:  top never found

!         ELSE

            CLTOPUSTBL = CLTOP  ! store unstable cloud top

!         END IF

267         CONTINUE    !  loop exit target

          CONV_DEP( COL, ROW, N_SPC_WDEP + 3 ) = FLOAT( CLBASE )

          IF ( ICLDTYPE .EQ. 1 ) THEN    !  store raining cloud top and proceed
            CONV_DEP( COL, ROW, N_SPC_WDEP + 4 ) = FLOAT( CLTOP )
          ELSE                      !  get cloud top for either CNP or PFW

            IF ( ZH( COL, ROW, CLBASE ) .GT. 1500.0 ) GO TO 301

C...compute relative humidity at the cloud source level

            RLHSRC = QVL( SRCLAY )
     &             / QSAT( ESAT( TAL( SRCLAY ) ), PRESL( SRCLAY ) )

            IF ( RLHSRC .LE. RCRIT1 ) GO TO 301

C...If all tests pass, then a CNP or PFW cloud exists
C...  Proceed to find CLTOP for CNP or PFW; don't allow
C...  cloud top to exceed 500mb, or, when RH falls below
C...  65%, cloud top found

            DO LAY = CLBASE + 1, NLAYS
              CLTOP = LAY - 1
              RLH = QVL( LAY )
     &            / QSAT( ESAT( TAL( LAY ) ), PRESL( LAY ) )
              IF ( RLH .LT. 0.65 ) GO TO 285
              IF ( PRESL( LAY ) .LE. 50000.0 ) GO TO 285
            END DO

285         CONTINUE   ! loop exit target, INITIAL cloud top found

C...Distiguish between CNP and PFW by whether rain is falling
C...  in the cell; if PFW, limit depth and find new CLTOP,
C...  else leave CLTOP alone

            IF ( CLTOP .EQ. CLBASE ) THEN
              GO TO 322
            ELSE                   ! confine PFW to 1500 meters
              CTOP = CLTOP

              DO LAY = CTOP, CLBASE, -1
                IF ( ZH( COL, ROW, LAY ) .LE. 3000.0 ) THEN
                  CLTOP = LAY
                  GO TO 322
                END IF
              END DO

            END IF

322         CONTINUE     ! exit target for PFW cloud

C...If unstable CNP or PFW, limit CLTOP to CLTOPUSTBL so that
C...  QAD profile is known through cloud depth for entrainment
C...  solver

            IF ( ISOUND .EQ. 1 )
     &        CLTOP = MIN( CLTOP, CLTOPUSTBL )

C...Now compute fractional coverage for either CNP or PFW:

            IF ( RLHSRC .GE. RCRIT2 ) THEN
              FRAC = FRACMAX
            ELSE
              FRAC = FRACMAX * ( ( RLHSRC - RCRIT1 ) / ( RCRIT2 - RCRIT1 ) )
            END IF
            IF(FRAC.LT.0.01) GO TO 301

            CONV_DEP( COL, ROW, N_SPC_WDEP + 5 ) = FLOAT( CLTOP ) ! store NP cloud top
            CONV_DEP( COL, ROW, N_SPC_WDEP + 8 ) = FRAC

          END IF  !! end of existence, depth and frac cov calc for
                  !! either PFW or CNP clouds

C...Now cloud existence is established, initialize various
C...  variables needed for rest of computations

C...First, get moles air/m2 at each layer, initialize FSIDE

          DO LAY = 1, NLAYS
            RHOM2( LAY ) = PRESL( LAY ) * DZZL( LAY )
     &                   * 1.0E3
     &                   / ( RDGAS * MWAIR * TAL( LAY ) )
            FSIDE( LAY ) = 0.0
          END DO

          DO SPC = 1, NSPCSD
            REMOV   ( SPC ) = 0.0  ! moles/m2 or mm*mol/lit scavenged
            CEND    ( SPC ) = 0.0  ! ending equiv gas phase conc (moles/mole)
            BMOL    ( SPC ) = 0.0  ! moles/m2 species below cloud
            POLC    ( SPC ) = 0.0  ! moles/m2 species in cloud

            DO LAY = 1, NLAYS
              BCLDWT( SPC, LAY ) = 0.0 ! below cloud weighting function
              PCLD  ( SPC, LAY ) = 0.0  ! moles sp/mole air in cloud
            END DO

          END DO

C...compute no. of moles air below cloud base and inverse

          AIRMB0 = 0.0
          DO LAY = 1, CLBASE - 1
            AIRMB0 = AIRMB0 + RHOM2( LAY )
          END DO

C...take the inverse

          AIRMBI = 1.0 / AIRMB0

C...below cloud base

          DO LAY = 1, CLBASE - 1

C...   determine no. of moles/m2 of trace gas

            DO SPC = 1, NSPCSD
              BMOL( SPC ) = BMOL( SPC )
     &                    + CONC( SPC,LAY ) * RHOM2( LAY )
            END DO

          END DO

C...determine average trace gas mixing ratio below cloud level

          DO SPC = 1, NSPCSD
            CBASE0( SPC ) = BMOL( SPC ) * AIRMBI
            CBASEF( SPC ) = CBASE0( SPC )
          END DO

C...Initialize variables needed for entrainment and in-cloud properties solver

          QXS =   0.0  ! integrated excess water over grid cell nec. for rnout
          AIRM =  0.0  ! total air mass (moles/m2) in cloudy layers
          PBARC = 0.0  ! in-cloud average pressure
          CTHK  = 0.0  ! cloud thickness (meters)
          WCBAR = 0.0  ! condensed wat cont (kg/m2) integ. thru cloud depth
          WTBAR = 0.0  ! total wat cont (kg/m2) integrated thru cloud depth
          TBARC = 0.0  ! cloud mean temp (K)

C...Determine condensed water content and entrainment at each cloud level
C...  Determine FSIDE profile for raining clouds; side entrainment
C...  only for PFW and CNP clouds

          IF ( ICLDTYPE .EQ. 1 ) THEN  !! raining cloud

            IF ( CLBASE .EQ. CLTOP ) THEN
              FSIDE( CLBASE ) = 1.0
            ELSE

              DO LAY = CLBASE, CLTOP
!               FSIDE( LAY ) = SIDEFAC * ( CLTOP - LAY )
!     &                      / ( CLTOP - CLBASE )
                FSIDE( LAY ) = 1.0
              END DO

            END IF

          ELSE                    !! then CNP or PFW

            DO LAY = CLBASE, CLTOP
              FSIDE( LAY ) = 1.0
            END DO

          END IF

C...Use Warner profile to close system of conservation and
C...  thermodynamic equations solved iteratively, using Secant solver

          DO LAY = CLBASE, CLTOP
            WL = 0.7 * EXP( ( PRESL( LAY ) - PLCL ) * 0.000125 ) + 0.2

            IF ( LAY .EQ. CLBASE ) THEN
              P1 = 0.5 * ( PRESL( LAY ) + PRESL( LAY - 1 ) )

              IF ( PLCL .LT. P1 ) THEN
                P2 = 0.5 * ( PRESL( LAY + 1 ) + PRESL( LAY ) )
                P3 = ( P2 + PLCL ) * 0.5
                WL = 0.7 * EXP( ( P3 - PLCL ) * 0.000125 ) + 0.2
              END IF

            END IF

c...original Walcek bisection solver

            QWAT( LAY ) = WL * ( QMAX - QAD( LAY ) )
            QWAT( LAY ) = MAX( QWAT( LAY ), 1.0E-20 )

            TEMPA = TSAT( LAY ) - 20.0
            TEMPB = TSAT( LAY ) + 10.0

            QENT = FSIDE( LAY ) * QVL( LAY )
     &           + ( 1.0 - FSIDE( LAY ) ) * QVL( CLTOP )
            XXXX = QENT - QMAX
            IF ( XXXX .EQ. 0.0 ) XXXX = 1.0E-10
            F( LAY ) = ( QSAT( ESAT( TEMPA ), PRESL( LAY ) )
     &               + QWAT( LAY ) - QMAX ) / XXXX
            F( LAY ) = MIN( F( LAY ), 1.0 )
            F( LAY ) = MAX( F( LAY ), 0.0 )

            TTOP = TAL( CLTOP ) * ( PRESL( LAY )
     &           / PRESL( CLTOP ) ) ** ROVCP
            TENT = TTOP * ( 1.0 - FSIDE( LAY ) )
     &           + TAL( LAY ) * FSIDE( LAY )

            TI = TSAT( LAY ) * ( 1.0 - F( LAY ) )
     &         + TENT * F( LAY )
            DQL = ( QMAX - QAD( LAY ) )
     &          * ( 1.0 - F( LAY ) - WL )
            DQI = 0.0

            IF ( TEMPA .LT. 273.15 ) THEN
              DQI = -QWAT( LAY ) * ( TEMPA - 273.15 ) / 18.0
              IF ( TEMPA .LE. 255.15 ) DQI = QWAT( LAY )
            END IF

            FA = CPD * ( TEMPA - TI ) + LV0 * DQL + LF0 * DQI

C...test for convergence, then cut the interval in half

            I599C = 0

599         CONTINUE

            HTST = TEMPB - TEMPA
            IF ( HTST .LT. TST ) GO TO 595
            I599C = I599C + 1

            IF ( I599C .GT. 1000 ) THEN
              WRITE( XMSG, 91010 )
     &             'NO CONVERGENCE IN ENTRAINMENT SOLVER AT COL= ',
     &             COL, ' ROW= ',  ROW, ' ICLDTYPE= ', ICLDTYPE
              CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
            END IF

            TEMPC = ( TEMPA + TEMPB ) * 0.5
            QENT = FSIDE( LAY ) * QVL( LAY )
     &           + ( 1.0 - FSIDE( LAY ) ) * QVL( CLTOP )
            XXXX = QENT - QMAX
            IF ( XXXX .EQ. 0.0 ) XXXX = 1.0E-10
            F( LAY ) = ( QSAT( ESAT( TEMPC ), PRESL( LAY ) )
     &               + QWAT( LAY ) - QMAX ) / XXXX
            F( LAY ) = MIN( F( LAY ), 0.99 )
            F( LAY ) = MAX( F( LAY ), 0.01 )
            TTOP = TAL( CLTOP )
     &           * ( PRESL( LAY ) / PRESL( CLTOP ) ) ** ROVCP
            TENT = TTOP * ( 1.0 - FSIDE( LAY ) )
     &           + TAL( LAY ) * FSIDE( LAY )
            TI = TSAT( LAY ) * ( 1.0 - F( LAY ) )
     &         + TENT * F( LAY )
            DQL = ( QMAX - QAD( LAY ) )
     &          * ( 1.0 - F( LAY ) - WL )
            DQI = 0.0

            IF ( TEMPC .LT. 273.15 ) THEN
              DQI = -QWAT( LAY ) * ( TEMPC - 273.15 ) / 18.0
              IF ( TEMPC .LE. 255.15 ) DQI = QWAT( LAY )
            END IF

            FB = CPD * ( TEMPC - TI ) + LV0 * DQL + LF0 * DQI

            FTST = FA * FB

C...if fa*fb < 0 then zero lies between ta & tc
C...  if fa*fb > 0 then zero lies between tc & tb

            IF ( FTST ) 590, 590, 591
590           TEMPB = TEMPC
              GO TO 599
591           TEMPA = TEMPC
              FA = FB
              GO TO 599

595         CONTINUE   ! exit from iterator, convergence achieved

C...we have obtained parcel temp TEMPC at layer LAY
C...  and entrainment fraction F(LAY)

C...end of Walcek bisection solver

            TCLD( LAY ) = MAX( TEMPC, 150.0 )

C...ice load in cloud is a function of temperature below freezing

            QICE( LAY ) = 0.0
            IF ( TCLD( LAY ) .LT. 273.15 ) THEN
              QICE( LAY ) = -QWAT( LAY ) * ( TCLD( LAY ) - 273.15 )
     &                    / 18.0
              IF ( TCLD( LAY ) .LE. 255.15 ) QICE( LAY ) = QWAT( LAY )
            END IF

C...After determining the ice fraction, compute the actual
C...  liquid water mixing ratio:

            QLQD( LAY ) = QWAT( LAY ) - QICE( LAY )

C...compute the Liquid Water Content (LWC) by taking the
C...  product of the liquid wat mix ratio and the air density
C...  LWC in kg H2O per m**3 air:

            RHOAIR = PRESL( LAY ) / ( RDGAS * TCLD( LAY ) )
            LWC( LAY ) = QLQD( LAY ) * RHOAIR
            LWC( LAY ) = MAX( 5.0E-6, LWC( LAY ) )  ! lower limit
            TWC = QWAT( LAY ) * RHOAIR         ! total water content

C...Now perform vertical integration, weighting by liquid water
C...  content so that averaged quantities (used in Aqueous
C...  Chemistry) get the greatest weight where the liquid
C...  water content is greatest.

C...weighted cloud temp

            TBARC = TBARC + TCLD( LAY ) * DZZL( LAY ) * LWC( LAY )

C...weighted cloud pres

            PBARC = PBARC + PRESL( LAY ) * DZZL( LAY ) * LWC( LAY )

C...integrated liquid water content (kg/m3)

            WCBAR = WCBAR + DZZL( LAY ) * LWC( LAY )

C...integrated total water content

            WTBAR = WTBAR + DZZL( LAY ) * TWC
            CTHK = CTHK + DZZL( LAY )   ! Cloud thickness

C...Now compute integrated excess water over grid cell
C...  average necessary for rainout, through cloud depth.
C...  First, get max temp in the cell (either in cloud or env.)

            T1 = MAX( TCLD( LAY ), TAL( LAY ) )

C...get saturation water vapor mixing ratio at that temp:

            QVC( LAY ) = QSAT( ESAT( T1 ), PRESL( LAY ) )

C...excess water is the sum of total condensed and saturated
C...  vapor minus grid cell average mixing ratio: QXS in kg/m2:
C...  integrated through cloud depth

            QXS = QXS
     &          + ( QWAT( LAY ) + QVC( LAY ) - QVL( LAY ) )
     &          * RHOAIR * DZZL( LAY )

C...get total air mass in cloudy layers:

            AIRM = AIRM + RHOM2( LAY )

          END DO

C...Now begin to split calculations for non-raining and raining
C...  clouds depending on inner loop index ICLDTYPE (1 = raining,
C...  2 = nonraining: either CNP of PFW:)

          IF ( ICLDTYPE .EQ. 2 ) THEN   ! no precip or excess water
            PRATE1 = 1.0E-30
            PRATE  = 1.0E-30
            QXS    = 1.0E-30
            GO TO 7000       ! branch for further CNP or PFW calculations
          END IF

C...continue here for raining cloud...

C...get PRATE1, storm rainout rate in mm/hour, noting that 1kg
C...  of water occupies a 1mm thick layer of water in a square meter
C...  of ground (accounts for density of water = 1000kg/m3)

          PRATE1 = STORME * QXS * 3600.0 / TAUCLD
          IF ( PRATE1 .LE. 1.001*PRATE ) THEN
            FRAC = 0.999                ! Changed back to .999 - jp 6/05
            PRATE1 = PRATE / FRAC
          ELSE
            FRAC = PRATE / PRATE1
          END IF
          IF ( FRAC .LT. 0.01 ) GO TO 301

C...for raining cloud, compute water properties of interest
C...  below cloud base. First, parameterize total water content

          TWC = ( 0.067 * PRATE**( 0.846 ) ) / ( FRAC * 1000.0 ) ! tot wat cont kg/m3

          DO LAY = 1, CLBASE - 1
            TCLD( LAY ) = TAL( LAY )
            RHOAIR = PRESL( LAY ) / ( RDGAS * TCLD( LAY ) )
            QWAT( LAY ) = TWC / RHOAIR    ! kg H2O / kg air

C...again partition into ice and liquid

            QICE( LAY ) = 0.0

            IF ( TCLD( LAY ) .LT. 273.15 ) THEN
              QICE( LAY) = -QWAT( LAY ) * ( TCLD( LAY ) - 273.15 )
     &                   / 18.0
              IF ( TCLD( LAY ) .LE. 255.15 ) QICE( LAY ) = QWAT( LAY )
            END IF

            QLQD( LAY ) = QWAT( LAY ) - QICE( LAY )
            LWC ( LAY ) = QLQD( LAY ) * RHOAIR
            LWC ( LAY ) = MAX( 0.000005, LWC( LAY ) )         ! lower limit
            PBARC = PBARC + PRESL( LAY ) * DZZL( LAY ) * LWC( LAY )
            TBARC = TBARC + TCLD( LAY ) * DZZL( LAY ) * LWC( LAY )
            WCBAR = WCBAR + DZZL( LAY ) * LWC( LAY )
            WTBAR = WTBAR + DZZL( LAY ) * TWC
            CTHK = CTHK + DZZL( LAY )

C...excess water is all rain

            QXS = QXS + QWAT( LAY ) * RHOAIR * DZZL( LAY )

          END DO

C...Final calc of storm rainfall rate and frac area (RAINING CLDS)

          PRATE1 = STORME * QXS * 3600.0 / TAUCLD

          IF ( PRATE1 .LE. 1.001*PRATE ) THEN
            FRAC = 0.999        ! Changed back to .999 - jp 6/05
            PRATE1 = PRATE / FRAC
          ELSE
            FRAC = PRATE / PRATE1
          END IF
          IF ( FRAC .LT. 0.01 ) GO TO 301
          CONV_DEP( COL, ROW, N_SPC_WDEP + 7 ) = FRAC

7000      CONTINUE                        ! target of cloudtype split

C...Begin mixing section, perform first for raining clouds using
C...  modified form of original Walcek mixing for RADM: mixing
C...  limited to 1 layer above cloud top; next for CNP or PFW clouds
C...  using direct exchange mixing mechanism by McHenry.

          DO SPC = 1, MXSPCS
            DO LAY = 1, NLAYS
              CCR( SPC, LAY ) = CONC( SPC,LAY )
            END DO
            CBELOW( SPC ) = CBASE0( SPC )
          END DO

!         IF ( ROW .EQ. 46 .AND. COL .EQ. 62 ) THEN
!           WRITE( LOGDEV, * ) ' BASE,TOP=',CLBASE,CLTOP,
!    &                         ' frac=',FRAC
!           WRITE( LOGDEV, * ) ' CB=',CBELOW(9),' PRATE,PRATE1=',PRATE,PRATE1
!           DO LAY = NLAYS, 1, -1
!             WRITE( LOGDEV, * ) LAY, TAL( LAY ),
!    &                           QVL( LAY ), PRESL( LAY ),
!    &                           ZH(COL, ROW, LAY ), ZF(COL, ROW, LAY ), CCR( 9, LAY )
!           END DO
!         END IF

          CALL ACMCLD ( F, CCR, SIGF, CBELOW, CLBASE, CLTOP,
     &                  FRAC, NSPCSD, NLAYS )

!         IF ( ROW .EQ. 46 .AND. COL .EQ. 62 ) THEN
!           WRITE( LOGDEV, * ) ' CBELOW=',CBELOW( 9 )
!           DO LAY = NLAYS, 1, -1
!             WRITE( LOGDEV, * ) ' Lay,c=',LAY, CCR( 9,LAY )
!           END DO
!         END IF

          DO SPC = 1, MXSPCS
            CBASEF( SPC ) =  CBELOW( SPC ) 
          END DO

          DO LAY = CLTOP, CLBASE, -1
            DO SPC = 1, NSPCSD
              CONDIS = CONC( SPC,LAY )
              PCLD( SPC, LAY ) = F( LAY ) * ( FSIDE( LAY ) * CONDIS )
     &                         + ( 1.0 - F( LAY ) ) * CBASE0( SPC )
              PCLD( SPC, LAY ) = MIN( PCLD( SPC, LAY ), CCR( SPC, LAY ) / FRAC )

C...POLC in moles sp/m2

              POLC( SPC ) = POLC( SPC )
     &                    + PCLD( SPC, LAY ) * RHOM2( LAY )
            END DO
          END DO

C...Now compute for raining region below cloud which is also considered
C...  to be part of the aqueous reaction chamber

            DO LAY = 1, CLBASE - 1
              AIRM = AIRM + RHOM2( LAY )

              DO SPC = 1, NSPCSD
                IF ( CBASE0( SPC ) .EQ. 0.0 ) THEN
                  BCLDWT( SPC, LAY ) = 1.0 / CLBASE
                ELSE
                  BCLDWT( SPC, LAY ) = CONC( SPC, LAY )
     &                               / MAX( CBASE0( SPC ), 1.0E-30 )
                END IF
                PCLD( SPC, LAY ) = CBASEF( SPC ) * BCLDWT( SPC, LAY )
         
C...Necessary because CBASEF and CBASE0 are the ending vertical averages
C...  below cloud concentrations in moles sp/mole air

                IF ( ICLDTYPE .EQ. 1 ) THEN
                  POLC( SPC ) = POLC( SPC )
     &                        + PCLD( SPC, LAY ) * RHOM2( LAY )
                END IF
              END DO
            END DO

C...Compute cloud mean quantities

          AIRM  = MAX( AIRM, 1.0E-30 )  ! tot. air mass in cloudy layers
                                        ! moles/m2
          WCBAR = MAX( WCBAR, 1.0E-30 ) ! liq.wat. content in kg/m3 * CTHK

          WTBAR = MAX( WTBAR, 1.0E-30 ) ! condensed wat cnt: kg/m3 * CTHK

          CTHK  = MAX( CTHK, 1.0E-30 )  ! cloud thickness, meters

          TBARC = TBARC / WCBAR         ! deg K (note WCBAR has hidden
                                        ! factor CTHK in it)
          PBARC = PBARC / WCBAR         ! ave cloud pres, Pa

          WCBAR = WCBAR / CTHK          ! ave liq wat content in kg/m3

          WTBAR = WTBAR / CTHK          ! ave con wat content in kg/m3

C...Finally, get in cloud pollutant concentrations in moles sp
C...  per mole air

          DO SPC = 1, NSPCSD
!           POLC ( SPC ) = MAX( POLC( SPC ) / AIRM, 1.0E-30 )
            POLC ( SPC ) = POLC( SPC ) / AIRM
            CEND ( SPC ) = POLC( SPC )
            REMOV( SPC ) = 0.0
          END DO

          REMOVAC = 0.0

          ARPRES = PBARC / STDATMPA
          RTCH = ( MOLVOL / STDTEMP ) * TBARC
          CTHK1 = AIRM * RTCH / ( ARPRES * 1000.0 )

          CALL SCAVWDEP ( JDATE, JTIME, WTBAR,
     &                    WCBAR, TBARC, PBARC,
     &                    CTHK1, AIRM, PRATE1, TAUCLD, POLC, CEND,
     &                    REMOV, REMOVAC, ALFA0, ALFA2, ALFA3 )

C...if the liquid water content is above the specified threshold
C...  then perform the aqueous chemistry within the cloud and
C...  re-adjust the ending and removed amounts for those species
C...  that participated in cloud chemistry

          IF ( WCBAR .GT. 0.00001 ) THEN
            CALL AQ_MAP ( JDATE, JTIME, WTBAR, WCBAR, TBARC, PBARC,
     &                    CTHK1, AIRM, PRATE1, TAUCLD, POLC, CEND,
     &                    REMOV, REMOVAC, ALFA0, ALFA2, ALFA3 )
          END IF

          DO SPC = 1, NSPCSD
            IF ( CEND( SPC ) .LT. 0.0 ) WRITE( LOGDEV,* ) ' CEND,R,C,SP=',
     &                                  CEND( SPC ), ROW, COL, SPC
          END DO

C...weight the removed amount by the cloud fraction and convert
C...  from moles/m**2 to kg/m**2 and kg/m**2 to kg/hectare

C...  for gases

          SPC = 0
          STRT = GC_STRT
          FINI = GC_STRT - 1 + N_GC_SPC
          DO VAR = STRT, FINI
            SPC = SPC + 1
            REMOV( VAR ) = REMOV( VAR ) * GC_MOLWT( SPC )
     &                   * M2PHA / GPKG * FRAC
          END DO

C...  for aerosols

          SPC = 0
          STRT = AE_STRT
          FINI = AE_STRT - 1 + N_AE_SPC
          DO VAR = STRT, FINI
            SPC = SPC + 1
            IF ( ( INDEX( AE_SPC( SPC ), 'NUM' ) .EQ. 0 ) .AND.
     &           ( INDEX( AE_SPC( SPC ), 'SRF' ) .EQ. 0 ) ) THEN
              REMOV( VAR ) = REMOV( VAR ) * AE_MOLWT( SPC )
     &                     * M2PHA / GPKG * FRAC
            ELSE
              REMOV( VAR ) = REMOV( VAR ) * M2PHA * FRAC
            END IF
          END DO

C...  for non-reactives

          SPC = 0
          STRT = NR_STRT
          FINI = NR_STRT - 1 + N_NR_SPC
          DO VAR = STRT, FINI
            SPC = SPC + 1
            REMOV( VAR ) = REMOV( VAR ) * NR_MOLWT( SPC )
     &                   * M2PHA / GPKG * FRAC
          END DO

C...  for tracers

          SPC = 0
          STRT = TR_STRT
          FINI = TR_STRT - 1 + N_TR_SPC
          DO VAR = STRT, FINI
            SPC = SPC + 1
            REMOV( VAR ) = REMOV( VAR ) * TR_MOLWT( SPC )
     &                   * M2PHA / GPKG * FRAC
          END DO

C...add deposition amounts into the DEP array

          DO VAR = 1, N_SPC_WDEP
            CONV_DEP( COL, ROW, VAR ) = CONV_DEP( COL, ROW, VAR )
     &                                + REMOV( WDEP_MAP( VAR ) )
          END DO

C...  and load H+ concentration into the deposition array as well

          CONV_DEP( COL,ROW,N_SPC_WDEP+1 ) = CONV_DEP( COL,ROW,N_SPC_WDEP+1 )
     &                                     + REMOVAC

C...Compute concentration changes in the grid column resulting
C...  from subgrid scale vertical mixing:

C...first, below cloud base,
C...   include raining region below cld base

          DO LAY = 1, CLBASE - 1
            DO SPC = 1, NSPCSD
              IF ( ICLDTYPE .EQ. 1 ) THEN ! raining cloud:
                INCLOUD ( SPC, LAY ) = PCLD( SPC, LAY ) * CEND( SPC )
     &                               / MAX( POLC( SPC ), CONCMINL( SPC, LAY ) )
                OUTCLOUD( SPC, LAY ) = PCLD( SPC, LAY )
                IF ( SPC .NE. N_GC_SPCD ) THEN
                  CGRID( COL, ROW, LAY, SPC ) =
     &                                    INCLOUD ( SPC, LAY ) * FRAC
     &                                  + OUTCLOUD( SPC, LAY ) * ( 1.0 - FRAC )
                END IF
              ELSE
                CGRID( COL, ROW, LAY, SPC ) = PCLD( SPC, LAY )
              ENDIF
            END DO
          END DO

C...Now do changes in cloudy layers :

          DO LAY = CLBASE, CLTOP
            DO SPC = 1, NSPCSD
              INCLOUD( SPC, LAY ) = PCLD( SPC, LAY ) * CEND( SPC )
     &                            / MAX( POLC( SPC ), CONCMINL( SPC, LAY ) )
              OUTCLOUD( SPC, LAY ) = ( CCR( SPC, LAY ) - PCLD( SPC,LAY ) * FRAC )
     &                             / ( 1.0 - FRAC )
              OUTCLOUD( SPC, LAY ) = MAX( OUTCLOUD( SPC,LAY ), CONCMINL( SPC, LAY ) )
              IF ( SPC .NE. N_GC_SPCD ) THEN
                CGRID( COL, ROW, LAY, SPC ) =
     &                                    INCLOUD ( SPC, LAY ) * FRAC
     &                                  + OUTCLOUD( SPC, LAY ) * ( 1.0 - FRAC )
              END IF
            END DO
          END DO
301     CONTINUE        !  end loop on columns COL
311   CONTINUE        !  end loop on rows    ROW

!     DEALLOCATE ( TA )
!     DEALLOCATE ( QV )
!     DEALLOCATE ( ZF )
!     DEALLOCATE ( ZH )
!     DEALLOCATE ( PRES )
!     DEALLOCATE ( DZZ )
!     DEALLOCATE ( RC )
!     IF ( ALLOCATED ( RAIN ) ) DEALLOCATE ( RAIN )

      RETURN          !  from main routine CLDPROC

91010 FORMAT( 3( A, :, I3, : ) )

      END
