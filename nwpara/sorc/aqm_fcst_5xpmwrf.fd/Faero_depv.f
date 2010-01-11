
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/aero_depv/aero_depv2/aero_depv.F,v 1.1.1.1 2005/09/09 18:56:05 sjr Exp $


C what(1) key, module and SID; SCCS file; date and time of last delta:
C @(#)aero_depv.F       1.3 /project/mod3/CMAQ/src/ae_depv/aero_depv/SCCS/s.aero_depv.F 18 Jun 1997 12:55:48

C::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE AERO_DEPV ( JDATE, JTIME, TSTEP, VDEP_AE )

C----------------------------------------------------------------------
C aerosol dry deposition routine
C   written 4/9/97 by Dr. Francis S. Binkowski
C   uses code from modpar and vdvg from the aerosol module.
C   This routine uses a single block to hold information
C   for the lowest layer.
C NOTES: This version assumes that RA is available on the met file.
c        Array structure for vector optimization
C 26 Apr 97 Jeff - many mods
C 13 Dec 97 Jeff - expect uncoupled CGRID, concs as micro-g/m**3, #/m**3
C
C 1/11/99 David Wong at LM - change NUMCELLS to CELLNUM in the loop index
C FSB 3/17/99 changed to accommodate surface area/second moment and
C    encapsulated the actual drydep calculation into a subroutine which
C    is attached to this code
C Jeff - Dec 00 - move CGRID_MAP into f90 module
C FSB 12/11/2000. Logic added to allow deposition of particles at their
C     "wet" diameters; that is, accounting for the water on the particles.
C     This is done by adjusting the third and second moments for the
C     presence of water assuming that the geometric standard deviations
C     are not changed by this process. This appears to be a very good
C     assumption.
C 30 Aug 01 J.Young: Dyn alloc; Use HGRD_DEFN
C    Jan 03 J.Young: Change CGRID dimensions, eliminate re-allocations
C  6 Mar 03 J.Young: eliminate a lot of allocate/deallocates
C  7 Aug 03 S.Roselle: updated code for loading the min aero conc array
C 17 Dec 03 S.Roselle: Adjust 2nd and 3rd moments to include SOA,
C     without affecting the geometric standard deviations.
C  31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                     domain specifications in one module
C 07 Jun 05 P.Bhave: Added code to handle new species in the AE4
C     mechanism: ANAI, ANAJ, ANAK, ACLI, ACLJ, ACLK, ASO4K, AH2OK,
C     and ANO3K; look for ASEAS only when using AE3 mechanism
C----------------------------------------------------------------------

      USE CGRID_DEFN          ! inherits GRID_CONF and CGRID_SPCS

      IMPLICIT NONE

C Includes:

!     INCLUDE SUBST_HGRD_ID   ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID   ! vertical dimensioning parameters
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/RXCM.EXT"    ! to get mech name
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"    ! aerosol species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_DEPV.EXT"   ! aerosol dep vel surrogate names and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"     ! constants
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"   ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/FDESC3.EXT"   ! file header data structure
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"    ! I/O definitions and declarations
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/FILES_CTM.EXT"  ! file name parameters
!     INCLUDE SUBST_COORD_ID  ! coord. and domain definitions (req IOPARMS)

C Arguments

      INTEGER      JDATE        ! current model date , coded YYYYDDD
      INTEGER      JTIME        ! current model time , coded HHMMSS
      INTEGER      TSTEP        ! model time step, coded HHMMSS

C output:

C surrogate deposition velocities [ m s**-1 ]
!     REAL    VDEP_AE( NCOLS,NROWS,N_AE_DEPVD )
      REAL :: VDEP_AE( :,:,: )

C Local variables:

      REAL, PARAMETER :: CONMIN = 1.0E-30  ! concentration lower limit

      REAL, PARAMETER :: AEROCONCMIN_AC = 1.0E-6 ! minimum aerosol sulfate concentration
                                                 ! for acccumulation mode
                                                 ! 1 pg [ ug/m**3 ] changed 12/13/99 by FSB

C...This value is smaller than any reported tropospheric concentrations.

      REAL, PARAMETER :: AEROCONCMIN_AT = 1.0E-6 * AEROCONCMIN_AC ! minimum aerosol sulfate
                                                                  ! concentration for Aitken
                                                                  ! Aitken mode

      REAL, PARAMETER :: AEROCONCMIN_CO = 1.889544E-05 ! minimum coarse mode concentration.
                                                       ! Set to give NUMMIN_C = 1.0

C...factors to set minimum value for number concentrations

      REAL NUMMIN_AT   ! Aitken mode
      REAL NUMMIN_AC   ! accumulation mode
      REAL NUMMIN_C    ! coarse mode

C...factor to set minimum value for second moment

      REAL M2MIN_AT    ! Aitken  mode
      REAL M2MIN_AC    ! accumulation mode

      REAL, SAVE :: AECONMIN( N_AE_SPCD ) ! array of minimum concentrations
                                          ! for all aerosol species

C number of surrogates for aerosol dry deposition velocities
      INTEGER, PARAMETER :: N_AE_DEP_SPC = 8

      CHARACTER( 16 ) :: VDAE_NAME( N_AE_DEP_SPC )! dep vel surrogate name table
      DATA         VDAE_NAME( 1 ) / 'VNUMATKN        ' /
      DATA         VDAE_NAME( 2 ) / 'VNUMACC         ' /
      DATA         VDAE_NAME( 3 ) / 'VNUMCOR         ' /
      DATA         VDAE_NAME( 4 ) / 'VMASSI          ' /
      DATA         VDAE_NAME( 5 ) / 'VMASSJ          ' /
      DATA         VDAE_NAME( 6 ) / 'VMASSC          ' /
      DATA         VDAE_NAME( 7 ) / 'VSRFATKN        ' /
      DATA         VDAE_NAME( 8 ) / 'VSRFACC         ' /

      INTEGER, SAVE :: DEPV_SUR( N_AE_DEPVD )   ! pointer to surrogate
      INTEGER, SAVE :: LOGDEV                   ! unit number for the log file

C local variables:

      CHARACTER( 16 ), SAVE :: PNAME = 'AERO_DEPV'
      CHARACTER( 16 ) :: VNAME            ! varable name

      CHARACTER( 96 ) :: XMSG = ' '

      INTEGER   MDATE, MTIME, MSTEP   ! julian date, time and timestep in sec
      INTEGER   C, R, L, V, N         ! loop counters
      INTEGER   SPC                   ! species loop counter

C External Functions not previously declared in IODECL3.EXT:

      INTEGER, EXTERNAL :: SECSDIFF, SEC2TIME, TIME2SEC, INDEX1, TRIMLEN
      INTEGER, EXTERNAL :: SETUP_LOGDEV

C Variables interpolated using I/OAPI

C Meteorological variables

      REAL PRES    ( NCOLS,NROWS,NLAYS )  ! Atmospheric pressure [ Pa ]
      REAL TA      ( NCOLS,NROWS,NLAYS )  ! Air temperature [ K ]
      REAL DENS    ( NCOLS,NROWS,NLAYS )  ! Air density [ kg/m**3 ]
      REAL RA      ( NCOLS,NROWS )        ! aerodynamic resistance [ s/m ]
      REAL USTAR   ( NCOLS,NROWS )        ! friction velocity [m/s ]
      REAL WSTAR   ( NCOLS,NROWS )        ! convective velocity scale [m/s ]
      REAL HEATFLUX( NCOLS,NROWS )        ! surface heat flux [W/m**2]

C Information about blocks

!     INTEGER     BLKSIZE                  ! number of cells per block
!     PARAMETER ( BLKSIZE = NCOLS * NROWS ) ! set up for one layer

      INTEGER, SAVE :: NCELLS              ! number of cells per layer
      INTEGER, SAVE :: CELLNUM

      INTEGER     NCELL                    ! loop counter
      INTEGER     ALLOCSTAT

!     INTEGER     CCOL( BLKSIZE )   ! Column index of ordered cells
!     INTEGER     CROW( BLKSIZE )   ! Row index for ordered cells
      INTEGER, ALLOCATABLE, SAVE :: CCOL( : )   ! Column index of ordered cells
      INTEGER, ALLOCATABLE, SAVE :: CROW( : )   ! Row index for ordered cells

C Meteorological information in blocked arays:

!     REAL        BLKPRS ( BLKSIZE )       ! Air pressure in [ Pa ]
!     REAL        BLKTA  ( BLKSIZE )       ! Air temperature [ K ]
!     REAL        BLKDENS( BLKSIZE )       ! Air density  [ kg/m**3 ]
      REAL, ALLOCATABLE, SAVE :: BLKPRS ( : )  ! Air pressure in [ Pa ]
      REAL, ALLOCATABLE, SAVE :: BLKTA  ( : )  ! Air temperature [ K ]
      REAL, ALLOCATABLE, SAVE :: BLKDENS( : )  ! Air density  [ kg/m**3 ]

c Planetary boundary layer (PBL) variables:

!     REAL        BLKWSTAR( BLKSIZE ) ! convective velocity scale [ m/s ]
!     REAL        BLKUSTAR( BLKSIZE ) ! friction velocity [ m/s ]
!     REAL        BLKRA   ( BLKSIZE ) ! aerodynamic resistance [ s/m ]
      REAL, ALLOCATABLE, SAVE :: BLKWSTAR( : ) ! convective velocity scale [m/s]
      REAL, ALLOCATABLE, SAVE :: BLKUSTAR( : ) ! friction velocity [ m/s ]
      REAL, ALLOCATABLE, SAVE :: BLKRA   ( : ) ! aerodynamic resistance [ s/m ]

C Aerosol version name

      CHARACTER( 16 ), SAVE :: AE_VRSN

C internal aerosol  arrays

C ////////////////////////////////////////////////////////////////////////
C FSB This is information from APARMS3.EXT which has been directly
C      incorporated into this routine to make it more independent.

C Information for structure of CBLK

C number of species (gas + aerosol)
      INTEGER, PARAMETER :: NSPCSDA = N_AE_SPC + 3

!     REAL CBLK( BLKSIZE,NSPCSDA  ) ! main array of variables IN BLOCK
      REAL, ALLOCATABLE, SAVE :: CBLK( :,: ) ! main array of variables IN BLOCK

C *** set up indices for array  CBLK

      INTEGER, SAVE :: VSO4AJ  ! index for accumulation mode sulfate aerosol
                               !  concentration
      INTEGER, SAVE :: VSO4AI  ! index for Aitken mode sulfate concentraton
      INTEGER, SAVE :: VNH4AJ  ! index for accumulation mode aerosol ammonium
                               ! concentration
      INTEGER, SAVE :: VNH4AI  ! index for Aitken mode ammonium concentration
      INTEGER, SAVE :: VNO3AJ  ! index for accumulation mode aerosol nitrate
                               ! concentration
      INTEGER, SAVE :: VNO3AI  ! index for Aitken mode nitrate concentration
      INTEGER, SAVE :: VORGAJ  ! index for accumulation mode anthropogenic
                               ! organic aerosol concentration
      INTEGER, SAVE :: VORGAI  ! index for Aitken mode anthropogenic organic
                               ! aerosol concentration
      INTEGER, SAVE :: VORGPAJ ! index for accumulation mode primary
                               ! anthropogenic organic aerosol concentration
      INTEGER, SAVE :: VORGPAI ! index for Aitken mode primary anthropogenic
                               ! organic aerosol concentration
      INTEGER, SAVE :: VORGBAJ ! index for accumulation mode biogenic aerosol
                               ! concentration
      INTEGER, SAVE :: VORGBAI ! index for Aitken mode biogenic aerosol
                               ! concentration
      INTEGER, SAVE :: VECJ    ! index for accumulation mode aerosol elemental
                               ! carbon
      INTEGER, SAVE :: VECI    ! index for Aitken mode elemental carbon
      INTEGER, SAVE :: VP25AJ  ! index for accumulation mode primary PM2.5
                               ! concentration
      INTEGER, SAVE :: VP25AI  ! index for Aitken mode primary PM2.5
                               ! concentration
      INTEGER, SAVE :: VANTHA  ! index for coarse mode anthropogenic aerosol
                               ! concentration
      INTEGER, SAVE :: VSEAS   ! index for coarse mode marine aerosol
                               ! concentration
      INTEGER, SAVE :: VSOILA  ! index for coarse mode soil-derived aerosol
                               ! concentration
      INTEGER, SAVE :: VAT0    ! index for Aitken mode number
      INTEGER, SAVE :: VAC0    ! index for accumulation  mode number
      INTEGER, SAVE :: VCORN   ! index for coarse mode number
      INTEGER, SAVE :: VAT2    ! index for Aitken mode mode 2nd moment
      INTEGER, SAVE :: VAC2    ! index for accumulation mode 2nd moment
      INTEGER, SAVE :: VH2OAJ  ! index for accumulation mode aerosol water
                               ! concentration
      INTEGER, SAVE :: VH2OAI  ! index for Aitken mode aerosol water
                               ! concentration
      INTEGER, SAVE :: VNAJ    ! index for accumulation mode sodium
      INTEGER, SAVE :: VNAI    ! index for Aitken mode sodium
      INTEGER, SAVE :: VCLJ    ! index for accumulation mode chloride
      INTEGER, SAVE :: VCLI    ! index for Aitken mode chloride
      INTEGER, SAVE :: VNAK    ! index for coarse mode sodium
      INTEGER, SAVE :: VCLK    ! index for coarse mode chloride
      INTEGER, SAVE :: VSO4K   ! index for coarse mode sulfate
      INTEGER, SAVE :: VNO3K   ! index for coarse mode nitrate
      INTEGER, SAVE :: VH2OK   ! index for coarse mode water
      INTEGER, SAVE :: VAT3    ! index for Aitken mode 3rd moment
      INTEGER, SAVE :: VAC3    ! index for accumulation mode 3rd moment
      INTEGER, SAVE :: VCOR3   ! index for coarse mode 3rd moment

C *** special indices for surface area

      INTEGER, SAVE :: VSURFAT ! Index for Aitken mode surface area
      INTEGER, SAVE :: VSURFAC ! Index for accumulatin mode surface area

C set up species dimension and indices for deposition velocity internal
C array VDEP

!     REAL        VDEP( BLKSIZE,N_AE_DEP_SPC ) ! deposition  velocity [ m/s ]
      REAL, ALLOCATABLE, SAVE :: VDEP( :,: ) ! deposition  velocity [ m/s ]

      INTEGER, PARAMETER :: VDNATK = 1  ! Aitken mode number

      INTEGER, PARAMETER :: VDNACC = 2  ! accumulation mode number

      INTEGER, PARAMETER :: VDNCOR = 3  ! coarse mode number

      INTEGER, PARAMETER :: VDMATK = 4  ! Aitken mode mass

      INTEGER, PARAMETER :: VDMACC = 5  ! accumulation mode mass

      INTEGER, PARAMETER :: VDMCOR = 6  ! coarse mode mass

      INTEGER, PARAMETER :: VDSATK = 7  ! Aitken mode surface area

      INTEGER, PARAMETER :: VDSACC = 8  ! accumulation mode surface area

C arrays for getting size distribution information

C    mass concentration in Aitken mode [ ug / m**3 ]
!     REAL        PMASSAT( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PMASSAT( : )
C    mass concentration in accumulation mode [ ug / m**3 ]
!     REAL        PMASSAC( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PMASSAC( : )
C    mass concentration in coarse mode [ ug / m**3 ]
!     REAL        PMASSCO( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PMASSCO( : )

C    average particle density in Aitken mode [ kg / m**3 ]
!     REAL        PDENSAT( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PDENSAT( : )
C    average particle density in accumulation mode [ kg / m**3 ]
!     REAL        PDENSAC( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PDENSAC( : )
C    average particle density in coarse mode [ kg / m**3 ]
!     REAL        PDENSCO( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: PDENSCO( : )

C    atmospheric mean free path [ m]
!     REAL        XLM( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: XLM( : )
C    atmospheric dynamic viscosity ! [ kg/(m s) ]
!     REAL        AMU( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: AMU( : )

C *** modal diameters: [ m ]

C    Aitken mode geometric mean diameter [ m ]
!     REAL        DGATK( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: DGATK( : )
C    accumulation geometric mean diameter [ m ]
!     REAL        DGACC( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: DGACC( : )
C    coarse mode geometric mean diameter [ m ]
!     REAL        DGCOR( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: DGCOR( : )

c *** log of modal geometric standard deviation

C    Aitken mode
!     REAL        XXLSGAT( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: XXLSGAT( : )
C    accumulation mode
!     REAL        XXLSGAC( BLKSIZE )
      REAL, ALLOCATABLE, SAVE :: XXLSGAC( : )

      INTEGER     LCELL                    ! loop counter

      REAL        L2SGAT, L2SGAC           ! square of the log of geometric
                                           ! standard deviation
      REAL        ESAT36, ESAC36           ! see usage

      REAL, PARAMETER :: DGMIN = 1.0E-09   ! lowest particle diameter ( m )

      REAL, PARAMETER :: DENSMIN = 1.0E03  ! lowest particle density ( kg/m**3 )

      REAL, PARAMETER :: RADYNI_MIN = 1.0E-30 ! min inverse aerodynamic resistance

C *** ranges for acceptable values of LOG( sigma_g).

!     REAL, PARAMETER :: MINL2SG = 9.08403E-03   ! minimum value of L2SG
!                                                ! minimum sigma_g = 1.1

      REAL, PARAMETER :: MINL2SG = 2.38048048E-3 ! minimum value of L2SG
                                                 ! minimum sigma_g = 1.05

      REAL, PARAMETER :: MAXL2SG = 8.39588705E-1 ! maximum value of L2SG
                                                 ! maximum sigma_g = 2.5


C *** mathematical constants used in this code:

      REAL, PARAMETER :: PI6     = PI / 6.0

      REAL, PARAMETER :: THREEPI = 3.0 * PI

      REAL, PARAMETER :: F6DPI   = 6.0 / PI

      REAL, PARAMETER :: F6DPI9  = 1.0E+9 * F6DPI

      REAL, PARAMETER :: F6DPIM9 = 1.0E-9 * F6DPI

      REAL, PARAMETER :: ONE3    = 1.0 / 3.0

      REAL, PARAMETER :: TWO3    = 2.0 / 3.0

C *** physical constants used in this code:

C Boltzmann's Constant [ J/K ]
      REAL, PARAMETER :: BOLTZ = RGASUNIV / AVO

C dry air density at 1 atm, 273.16
      REAL, PARAMETER :: STDDENS = STDATMPA / ( RDGAS * STDTEMP )

      REAL, PARAMETER :: RHOCP = STDDENS * CPD

C component densities [ kg/m**3 ]:

C bulk density of aerosol sulfate
      REAL, PARAMETER :: RHOSO4 = 1.8E3

C bulk density of aerosol ammonium
      REAL, PARAMETER :: RHONH4 = 1.8E3

C bulk density of aerosol nitrate
      REAL, PARAMETER :: RHONO3 = 1.8E3

C bulk density of aerosol water
      REAL, PARAMETER :: RHOH2O = 1.0E3

C bulk density for aerosol organics
      REAL, PARAMETER :: RHOORG = 2.0E3

C bulk density for aerosol soil dust
      REAL, PARAMETER :: RHOSOIL = 2.6E3

C bulk density for marine aerosol
      REAL, PARAMETER :: RHOSEAS = 2.2E3

C bulk density for anthropogenic aerosol
      REAL, PARAMETER :: RHOANTH = 2.2E3

C Factors for converting aerosol mass concentration [ ug/m**3] to 3rd moment
C concentration [ m**3/m**3]

      REAL, PARAMETER :: SO4FAC = F6DPIM9 / RHOSO4

      REAL, PARAMETER :: NH4FAC = F6DPIM9 / RHONH4

      REAL, PARAMETER :: H2OFAC = F6DPIM9 / RHOH2O

      REAL, PARAMETER :: NO3FAC = F6DPIM9 / RHONO3

      REAL, PARAMETER :: ORGFAC = F6DPIM9 / RHOORG

      REAL, PARAMETER :: SOILFAC = F6DPIM9 / RHOSOIL

      REAL, PARAMETER :: SEASFAC = F6DPIM9 / RHOSEAS

      REAL, PARAMETER :: ANTHFAC = F6DPIM9 / RHOANTH

C standard surface pressure [ Pa ]
      REAL, PARAMETER :: P0 = 101325.0

C standard surface temperature [ K ]
      REAL, PARAMETER :: T0 = 288.15

C initial sigma-G for Aitken mode
      REAL, PARAMETER :: SGINIAT = 1.70

C initial sigma-G for accumulation mode
      REAL, PARAMETER :: SGINIAC = 2.00

C initial mean diameter for nuclei mode [ m ]
      REAL, PARAMETER :: DGINIAT = 0.01E-6

C initial mean diameter for accumulation mode [ m ]
      REAL, PARAMETER :: DGINIAC = 0.07E-6

C initial mean diameter for coarse mode [ m ]
      REAL, PARAMETER :: DGINICO = 1.0E-6

C fixed l sigma-G for coarse mode
!     REAL, PARAMETER :: SGINICO = 2.5
      REAL, PARAMETER :: SGINICO = 2.2    ! changed 5/13/98 FSB

      REAL        XXLSGCO          ! log(SGINICO )
      REAL, SAVE :: ESC36          ! exp( 4.5 * log( SGINICO ) ** 2 )

C *** Variables for adjustment of THIRD AND SECOND moments

      REAL        OLD_M3I, NEW_M3I ! Aitken mode
      REAL        OLD_M2I, NEW_M2I

      REAL        OLD_M3J, NEW_M3J ! accumulation mode
      REAL        OLD_M2J, NEW_M2J

      LOGICAL, SAVE :: FIRSTIME = .TRUE.

      INTEGER      GXOFF, GYOFF              ! global origin offset from file
C for INTERPX
      INTEGER, SAVE :: STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3

C.........begin body of subroutine  AERO_DEPV..........................

C Set-up to be performed the first time AERO_DEPV is called:

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
!        LOGDEV = INIT3()
         LOGDEV = SETUP_LOGDEV()

         IF ( N_AE_SPC .LE. 0 ) THEN
            CALL M3MESG ( 'WARNING: Model not compiled for aerosols!' )
            RETURN
         END IF

         IF ( INDEX ( MECHNAME, 'AE3' ) .GT. 0 ) THEN
            AE_VRSN  = 'AE3'
         ELSE IF ( INDEX ( MECHNAME, 'AE4' ) .GT. 0 ) THEN
            AE_VRSN  = 'AE4'
         ELSE
            XMSG = 'This program can only be used with the AE3 or '
     &          // 'AE4 aerosol mechanisms.'
                  CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
         END IF ! check on MECHNAME

         NCELLS = MY_NCOLS * MY_NROWS  ! set up for layer one only

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
C  Get number of cells in grid and store c,r indices of cells in
C  sequential order
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

         ALLOCATE ( CCOL( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( CROW( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating CCOL or CROW'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         CELLNUM = 0             ! only the first layer
         DO R = 1, MY_NROWS
            DO C = 1, MY_NCOLS
               CELLNUM = CELLNUM + 1
               CCOL( CELLNUM ) = C
               CROW( CELLNUM ) = R
            END DO
         END DO

         ALLOCATE ( BLKPRS ( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( BLKTA  ( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( BLKDENS( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating BLKPRS or BLKTA or BLKDENS'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( BLKWSTAR( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( BLKUSTAR( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( BLKRA   ( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating BLKWSTAR or BLKUSTAR or BLKRA'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( CBLK( NCELLS,NSPCSDA ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating CBLK'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( PMASSAT( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( PMASSAC( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( PMASSCO( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating PMASSAT or PMASSAC or PMASSCO'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( PDENSAT( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( PDENSAC( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( PDENSCO( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating PDENSAT or PDENSAC or PDENSCO'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( XLM( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( AMU( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating XLM or AMU'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( DGATK( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( DGACC( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( DGCOR( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating DGATK or DGACC or DGCOR'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( XXLSGAT( NCELLS ), STAT = ALLOCSTAT )
         ALLOCATE ( XXLSGAC( NCELLS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating XXLSGAT or XXLSGAC'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

         ALLOCATE ( VDEP( NCELLS,N_AE_DEP_SPC ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating VDEP'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

C *** Coarse mode has a constant geometric standard deviation
C     set up the exponential factor used below

         XXLSGCO = LOG ( SGINICO )
         ESC36 = EXP ( 4.5 * XXLSGCO * XXLSGCO )

C Set up names and indices.

C Initialize indices for CBLK

C Get CGRID offsets

         CALL CGRID_MAP( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )

C Determine CGRID species map from AE_SPC.EXT

         V = 0

         VNAME = 'ASO4J'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VSO4AJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ASO4I'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VSO4AI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANH4J'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VNH4AJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANH4I'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VNH4AI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANO3J'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VNO3AJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANO3I'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VNO3AI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGAJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGAJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGAI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGAI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGBJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGBAJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGBI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGBAI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGPAJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGPAJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGPAI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VORGPAI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AECJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VECJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AECI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VECI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'A25J'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VP25AJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'A25I'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VP25AI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ACORS'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VANTHA = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         IF ( AE_VRSN .EQ. 'AE3' ) THEN
            VNAME = 'ASEAS'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VSEAS = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF
         END IF

         VNAME = 'ASOIL'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VSOILA = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMATKN'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VAT0 = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMACC'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VAC0 = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMCOR'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VCORN = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'SRFATKN'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VSURFAT = N
            VAT2   = N ! The two indices are equal, space is shared
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'SRFACC'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VSURFAC = N
            VAC2   = N ! The two indices are equal, space is shared
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AH2OJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VH2OAJ = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AH2OI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            VH2OAI = N
            V = V + 1
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         IF ( AE_VRSN .EQ. 'AE4' ) THEN

            VNAME = 'ANAJ'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VNAJ = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ANAI'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VNAI = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ACLJ'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VCLJ = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ACLI'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VCLI = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ANAK'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VNAK = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ACLK'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VCLK = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ASO4K'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VSO4K = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ANO3K'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VNO3K = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'AH2OK'
            N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( N .NE. 0 ) THEN
               VH2OK = N
               V = V + 1
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

         END IF

C set additional species

         V = N_AE_SPC + 1
         VAT3 = V

         V = V + 1
         VAC3 = V

         V = V + 1
         VCOR3 = V

C Open the met files

         IF ( .NOT. OPEN3( MET_CRO_3D, FSREAD3, PNAME ) ) THEN
            XMSG = 'Could not open  MET_CRO_3D  file '
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

         IF ( .NOT. OPEN3( MET_CRO_2D, FSREAD3, PNAME ) ) THEN
            XMSG = 'Could not open  MET_CRO_2D file '
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

         IF ( .NOT. DESC3( MET_CRO_2D ) ) THEN
            XMSG = 'Could not get  MET_CRO_2D  file description '
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
         END IF

C Set the dep vel surrogate pointers

         DO V = 1, N_AE_DEPV
            N = INDEX1( AE_DEPV( V ), N_AE_DEP_SPC, VDAE_NAME )
            IF ( N .NE. 0 ) THEN
               DEPV_SUR( V ) = N
            ELSE
               XMSG = 'Could not find ' // AE_DEPV( V ) // ' in aerosol' //
     &                ' surrogate table. >>> Dep vel set to zero <<< '
               CALL M3WARN( PNAME, JDATE, JTIME, XMSG )
               DEPV_SUR( V ) = 0
            END IF
         END DO

C *** calculate minimum values for number and 2nd moment.

         NUMMIN_AT = SO4FAC * AEROCONCMIN_AT /
     &             ( DGINIAT ** 3 * EXP( 4.5 * LOG( SGINIAT )**2 ) )

         NUMMIN_AC = SO4FAC * AEROCONCMIN_AC /
     &             ( DGINIAC ** 3 * EXP( 4.5 * LOG( SGINIAC )**2 ) )

         M2MIN_AT = NUMMIN_AT * DGINIAT ** 2 *
     &              EXP( 2.0 * LOG( SGINIAT )**2 )

         M2MIN_AC = NUMMIN_AC * DGINIAC ** 2 *
     &              EXP( 2.0 * LOG( SGINIAC )**2 )

         NUMMIN_C = ANTHFAC * AEROCONCMIN_CO / ( DGINICO**3 * ESC36)

C create aerosol species pointers to distinguish micro-grams / m**3,
C # / m**3 (number density), and m**2 / m**3 (surface area) units

         DO V = 1, N_AE_SPC
            SELECT CASE ( AE_SPC( V )( 1:TRIMLEN( AE_SPC( V ) ) ) )
            CASE ( 'NUMATKN' )
               AECONMIN( V ) = NUMMIN_AT
            CASE ( 'NUMACC' )
               AECONMIN( V ) = NUMMIN_AC
            CASE ( 'NUMCOR' )
               AECONMIN( V ) = NUMMIN_C
            CASE ( 'SRFATKN' )
               AECONMIN( V ) = M2MIN_AT
            CASE ( 'SRFACC' )
               AECONMIN( V ) = M2MIN_AC
            CASE ( 'ASO4I' )
               AECONMIN( V ) = AEROCONCMIN_AT
            CASE ( 'ASO4J' )
               AECONMIN( V ) = AEROCONCMIN_AC
            CASE ( 'ACORS' )
               AECONMIN( V ) = AEROCONCMIN_CO
            CASE DEFAULT
               AECONMIN( V ) = CONMIN
            END SELECT
         END DO

C *** get file horizontal grid offsets

         CALL SUBHFILE ( MET_CRO_2D, GXOFF, GYOFF,
     &                   STRTCOLMC2, ENDCOLMC2, STRTROWMC2, ENDROWMC2 )
         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

      END IF    ! FIRSTIME

      IF ( N_AE_SPC .LE. 0 ) RETURN

C------------------ BEGIN INTERPOLATION -------------------------------
C Center of this model (advection) time-step  !!!! NO !!! CALLER DOES THIS !!!

      MDATE  = JDATE
      MTIME  = JTIME

C begin interpolation of  meteorological variables

C Interpolate time dependent one-layer and layered input variables

ccccccccccccccccccccc enable backward compatiblity ccccccccccccccccccccc
      VNAME = 'RADYNI'

      IF (       INTERPX( MET_CRO_2D, VNAME, PNAME,
     &                    STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                    MDATE, MTIME, RA ) ) THEN

         DO R = 1, MY_NROWS
            DO C = 1, MY_NCOLS
               RA( C,R ) = 1.0 / MAX( RA( C,R ), RADYNI_MIN )
            END DO
         END DO

      ELSE
         VNAME = 'RA'

         IF ( .NOT. INTERPX( MET_CRO_2D, VNAME, PNAME,
     &                       STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                       MDATE, MTIME, RA ) ) THEN
            XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_2D '
            CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
         END IF

      END IF
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      VNAME = 'USTAR'

      IF ( .NOT. INTERPX( MET_CRO_2D, VNAME, PNAME,
     &                    STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                    MDATE, MTIME, USTAR ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_2D '
         CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

      VNAME = 'WSTAR'
      IF ( .NOT. INTERPX( MET_CRO_2D, VNAME, PNAME,
     &                    STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                    MDATE, MTIME, WSTAR ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_2D '
         CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

      VNAME = 'HFX'
      IF ( .NOT. INTERPX( MET_CRO_2D, VNAME, PNAME,
     &                    STRTCOLMC2,ENDCOLMC2, STRTROWMC2,ENDROWMC2, 1,1,
     &                    MDATE, MTIME, HEATFLUX ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_2D '
         CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

C Layered variables TA, QV, DENS:

C Pressure (Pa)

      VNAME = 'PRES'
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, PRES ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_3D '
         CALL M3EXIT (PNAME, MDATE, MTIME, XMSG, XSTAT1)
      END IF

      VNAME = 'TA'
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, TA ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_3D '
         CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

      VNAME = 'DENS'
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, DENS ) ) THEN
         XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_3D '
         CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

C ----------End interpolation of meteorological variables -------------

C SET UP BLOCKS -  Jerry Gipson's code

C only one BLOCK is used and it contains the entire first layer

C load blocks and do computations

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
C  Put the grid cell physical data in the block arrays
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      L = 1
      DO NCELL = 1, CELLNUM
         C = CCOL( NCELL )
         R = CROW( NCELL )
!        L = CLEV( NCELL )
         BLKTA   ( NCELL ) = TA   ( C,R,L )
         BLKPRS  ( NCELL ) = PRES ( C,R,L )   ! Note pascals.
         BLKDENS ( NCELL ) = DENS ( C,R,L )
         BLKUSTAR( NCELL ) = USTAR( C,R )
         BLKWSTAR( NCELL ) = WSTAR( C,R )
         BLKRA   ( NCELL ) = RA   ( C,R )
      END DO

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c Put the grid cell concentrations in the block arrays (decoupled)
c L = 1 (set above)j
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      DO N = 1, N_AE_SPC
         V = N + AE_STRT - 1
         DO NCELL = 1, CELLNUM
            C = CCOL( NCELL )
            R = CROW( NCELL )
            CBLK( NCELL,N ) = MAX ( CGRID( C,R,L,V ), AECONMIN( N ) )
!           CBLK( NCELL,N ) = MAX ( CGRID( V,L,C,R ), AECONMIN( N ) )
         END DO
      END DO

      DO NCELL = 1, CELLNUM
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
C *** transform surface area to 2nd moment by dividing by PI
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

         CBLK( NCELL,VAT2 ) = CBLK( NCELL,VSURFAT ) / PI
         CBLK( NCELL,VAC2 ) = CBLK( NCELL,VSURFAC ) / PI

      END DO

C *** code from getpar

C *** set up  aerosol  3rd moment, mass, density [ mom/ m**3 s ]

C *** Adjust the 3rd and 2nd moments for H2O and SOA. ***
C       The transport codes post-AE2 consider the aerosol to be "dry",
C     that is not to have H2O in the 2nd moment. The approach here
C     is to calculate the 3rd moments without H2O (OLD_M3I and OLD_M3J),
C     then add the contribution of water (NEW_M3I AND NEW_M3J), and then
C     adjust the 2nd moments holding the geometric standard deviations
C     constant. To preserve the standard deviations, the ratio of
C     the NEW to OLD 2nd moments is equal to the ratio of NEW to OLD
C     3rd moments raised to the two thirds power.  The reason for this
C     adjustment is that aerosols are deposited at ambient conditions,
C     which includes particle-bound H2O.
C *** 12/17/03 revision --S.Roselle
C       SOA was removed from 2nd moment for transport (i.e., "dry"
C     is now defined as containing neither H2O nor SOA).  Therefore,
C     SOA must be added back for deposition in a manner analogous to
C     the treatment of H2O.

      IF ( AE_VRSN .EQ. 'AE3' ) THEN

         DO LCELL = 1, CELLNUM

C *** calculate third moments without contribution of H2O and SOA

            OLD_M3I = MAX( CONMIN,
     &          ( SO4FAC  * CBLK( LCELL,VSO4AI  ) +
     &            NH4FAC  * CBLK( LCELL,VNH4AI  ) +
     &            NO3FAC  * CBLK( LCELL,VNO3AI  ) +
     &            ORGFAC  * CBLK( LCELL,VORGPAI ) +
     &            ANTHFAC * CBLK( LCELL,VP25AI  ) +
     &            ANTHFAC * CBLK( LCELL,VECI    ) ) )

            OLD_M3J = MAX( CONMIN,
     &          ( SO4FAC  * CBLK( LCELL,VSO4AJ  ) +
     &            NH4FAC  * CBLK( LCELL,VNH4AJ  ) +
     &            NO3FAC  * CBLK( LCELL,VNO3AJ  ) +
     &            ORGFAC  * CBLK( LCELL,VORGPAJ ) +
     &            ANTHFAC * CBLK( LCELL,VP25AJ  ) +
     &            ANTHFAC * CBLK( LCELL,VECJ    ) ) )

C *** add contribution of water and SOA to third moment

            NEW_M3I = OLD_M3I + H2OFAC  * CBLK( LCELL,VH2OAI   )
     &                        + ORGFAC  * CBLK( LCELL,VORGAI )
     &                        + ORGFAC  * CBLK( LCELL,VORGBAI )
            CBLK( LCELL,VAT3 ) = NEW_M3I

            NEW_M3J = OLD_M3J + H2OFAC  * CBLK( LCELL,VH2OAJ   )
     &                        + ORGFAC  * CBLK( LCELL,VORGAJ )
     &                        + ORGFAC  * CBLK( LCELL,VORGBAJ )
            CBLK( LCELL,VAC3 ) = NEW_M3J

C *** fetch second moment for "dry" particles

            OLD_M2I = CBLK( LCELL,VAT2 )
            OLD_M2J = CBLK( LCELL,VAC2 )

C *** adjust second moment for "wet" particles

            NEW_M2I = OLD_M2I * ( NEW_M3I / OLD_M3I ) ** TWO3
            CBLK( LCELL,VAT2 ) = NEW_M2I

            NEW_M2J = OLD_M2J * ( NEW_M3J / OLD_M3J ) ** TWO3
            CBLK( LCELL,VAC2 ) = NEW_M2J

C *** coarse mode

            CBLK( LCELL, VCOR3 ) = MAX( CONMIN,
     &        ( SOILFAC * CBLK( LCELL,VSOILA ) +
     &          SEASFAC * CBLK( LCELL,VSEAS  ) +
     &          ANTHFAC * CBLK( LCELL,VANTHA ) ) )

C *** now get particle mass [ ug/m**3 ] ( including water )

C *** Aitken-mode:

            PMASSAT( LCELL ) = MAX( CONMIN,
     &         ( CBLK( LCELL,VSO4AI  ) +
     &           CBLK( LCELL,VNH4AI  ) +
     &           CBLK( LCELL,VNO3AI  ) +
     &           CBLK( LCELL,VORGAI  ) +
     &           CBLK( LCELL,VORGPAI ) +
     &           CBLK( LCELL,VORGBAI ) +
     &           CBLK( LCELL,VP25AI  ) +
     &           CBLK( LCELL,VECI    ) +
     &           CBLK( LCELL,VH2OAI  ) ) )

C *** Accumulation-mode:

            PMASSAC( LCELL ) = MAX( CONMIN,
     &          ( CBLK( LCELL,VSO4AJ  ) +
     &            CBLK( LCELL,VNH4AJ  ) +
     &            CBLK( LCELL,VNO3AJ  ) +
     &            CBLK( LCELL,VORGAJ  ) +
     &            CBLK( LCELL,VORGPAJ ) +
     &            CBLK( LCELL,VORGBAJ ) +
     &            CBLK( LCELL,VP25AJ  ) +
     &            CBLK( LCELL,VECJ    ) +
     &            CBLK( LCELL,VH2OAJ   ) ) )

C *** coarse mode:

            PMASSCO( LCELL ) = MAX( CONMIN,
     &         CBLK( LCELL,VSOILA ) +
     &         CBLK( LCELL,VSEAS  ) +
     &         CBLK( LCELL,VANTHA ) )

         END DO ! cell loop for aerosol 3rd moment and  mass

      ELSE IF ( AE_VRSN .EQ. 'AE4' ) THEN

         DO LCELL = 1, CELLNUM

C *** calculate third moments without contribution of H2O and SOA

            OLD_M3I = MAX( CONMIN,
     &          ( SO4FAC  * CBLK( LCELL,VSO4AI  ) +
     &            NH4FAC  * CBLK( LCELL,VNH4AI  ) +
     &            NO3FAC  * CBLK( LCELL,VNO3AI  ) +
     &            ORGFAC  * CBLK( LCELL,VORGPAI ) +
     &            ANTHFAC * CBLK( LCELL,VP25AI  ) +
     &            ANTHFAC * CBLK( LCELL,VECI    ) +
     &            SEASFAC * CBLK( LCELL,VNAI    ) +
     &            SEASFAC * CBLK( LCELL,VCLI    ) ) )

            OLD_M3J = MAX( CONMIN,
     &          ( SO4FAC  * CBLK( LCELL,VSO4AJ  ) +
     &            NH4FAC  * CBLK( LCELL,VNH4AJ  ) +
     &            NO3FAC  * CBLK( LCELL,VNO3AJ  ) +
     &            ORGFAC  * CBLK( LCELL,VORGPAJ ) +
     &            ANTHFAC * CBLK( LCELL,VP25AJ  ) +
     &            ANTHFAC * CBLK( LCELL,VECJ    ) +
     &            SEASFAC * CBLK( LCELL,VNAJ    ) +
     &            SEASFAC * CBLK( LCELL,VCLJ    ) ) )

C *** add contribution of water and SOA to third moment

            NEW_M3I = OLD_M3I + H2OFAC  * CBLK( LCELL,VH2OAI   )
     &                        + ORGFAC  * CBLK( LCELL,VORGAI )
     &                        + ORGFAC  * CBLK( LCELL,VORGBAI )
            CBLK( LCELL,VAT3 ) = NEW_M3I

            NEW_M3J = OLD_M3J + H2OFAC  * CBLK( LCELL,VH2OAJ   )
     &                        + ORGFAC  * CBLK( LCELL,VORGAJ )
     &                        + ORGFAC  * CBLK( LCELL,VORGBAJ )
            CBLK( LCELL,VAC3 ) = NEW_M3J

C *** fetch second moment for "dry" particles

            OLD_M2I = CBLK( LCELL,VAT2 )
            OLD_M2J = CBLK( LCELL,VAC2 )

C *** adjust second moment for "wet" particles

            NEW_M2I = OLD_M2I * ( NEW_M3I / OLD_M3I ) ** TWO3
            CBLK( LCELL,VAT2 ) = NEW_M2I

            NEW_M2J = OLD_M2J * ( NEW_M3J / OLD_M3J ) ** TWO3
            CBLK( LCELL,VAC2 ) = NEW_M2J

C *** coarse mode

            CBLK( LCELL, VCOR3 ) = MAX( CONMIN,
     &        ( SOILFAC * CBLK( LCELL,VSOILA ) +
     &          ANTHFAC * CBLK( LCELL,VANTHA ) +
     &          SEASFAC * CBLK( LCELL,VNAK   ) +
     &          SEASFAC * CBLK( LCELL,VCLK   ) +
     &          SO4FAC  * CBLK( LCELL,VSO4K  ) +
     &          NO3FAC  * CBLK( LCELL,VNO3K  ) +
     &          H2OFAC  * CBLK( LCELL,VH2OK  ) ) )

C *** now get particle mass [ ug/m**3 ] ( including water )

C *** Aitken-mode:

            PMASSAT( LCELL ) = MAX( CONMIN,
     &         ( CBLK( LCELL,VSO4AI  ) +
     &           CBLK( LCELL,VNH4AI  ) +
     &           CBLK( LCELL,VNO3AI  ) +
     &           CBLK( LCELL,VORGAI  ) +
     &           CBLK( LCELL,VORGPAI ) +
     &           CBLK( LCELL,VORGBAI ) +
     &           CBLK( LCELL,VP25AI  ) +
     &           CBLK( LCELL,VECI    ) +
     &           CBLK( LCELL,VNAI    ) +
     &           CBLK( LCELL,VCLI    ) +
     &           CBLK( LCELL,VH2OAI  ) ) )

C *** Accumulation-mode:

            PMASSAC( LCELL ) = MAX( CONMIN,
     &          ( CBLK( LCELL,VSO4AJ  ) +
     &            CBLK( LCELL,VNH4AJ  ) +
     &            CBLK( LCELL,VNO3AJ  ) +
     &            CBLK( LCELL,VORGAJ  ) +
     &            CBLK( LCELL,VORGPAJ ) +
     &            CBLK( LCELL,VORGBAJ ) +
     &            CBLK( LCELL,VP25AJ  ) +
     &            CBLK( LCELL,VECJ    ) +
     &            CBLK( LCELL,VNAJ    ) +
     &            CBLK( LCELL,VCLJ    ) +
     &            CBLK( LCELL,VH2OAJ  ) ) )

C *** coarse mode:

            PMASSCO( LCELL ) = MAX( CONMIN,
     &         CBLK( LCELL,VSOILA ) +
     &         CBLK( LCELL,VANTHA ) +
     &         CBLK( LCELL,VNAK   ) +
     &         CBLK( LCELL,VCLK   ) +
     &         CBLK( LCELL,VSO4K  ) +
     &         CBLK( LCELL,VNO3K  ) +
     &         CBLK( LCELL,VH2OK  ) )

         END DO ! cell loop for aerosol 3rd moment and  mass

      END IF ! check on AE_VRSN

C *** now get particle density, mean free path, and dynamic viscosity

      DO LCELL = 1, CELLNUM ! Density and mean free path

C *** density in [ kg m**-3 ]

         PDENSAT( LCELL ) = MAX( DENSMIN,
     &                  ( F6DPIM9 * PMASSAT( LCELL ) /
     &                                CBLK( LCELL,VAT3 ) ) )
         PDENSAC( LCELL ) = MAX( DENSMIN,
     &                  ( F6DPIM9 * PMASSAC( LCELL ) /
     &                                CBLK( LCELL,VAC3 ) ) )
         PDENSCO( LCELL ) = MAX( DENSMIN,
     &                  ( F6DPIM9 * PMASSCO( LCELL ) /
     &                                CBLK( LCELL,VCOR3 ) ) )

C *** Calculate mean free path [ m ]:

         XLM( LCELL ) = 6.6328E-8 * P0 * BLKTA( LCELL )
     &                / ( T0 * BLKPRS( LCELL) )

C *** 6.6328E-8 is the sea level values given in Table I.2.8
C *** on page 10 of U.S. Standard Atmosphere 1962

C *** Calcualte dynamic viscosity [ kg m**-1 s**-1 ]:

C *** U.S. Standard Atmosphere 1962 page 14 expression
C     for dynamic viscosity is:
c     dynamic viscosity =  beta * T * sqrt(T) / ( T + S)
c     where beta = 1.458e-6 [ kg sec^-1 K**-0.5 ], s = 110.4 [ K ].

         AMU( LCELL ) = 1.458E-6 * BLKTA( LCELL ) * SQRT( BLKTA( LCELL ) )
     &                / ( BLKTA( LCELL ) + 110.4 )

      END DO  ! cell loop for density and mean free path

C *** Calculate geometric standard deviations and geometric mean diameters
C     in Aitken and accumulation modes

      DO LCELL = 1, CELLNUM

C *** geometric standard deviations
C *** Aitken Mode:

         L2SGAT =
     &      ONE3 * LOG( CBLK( LCELL,VAT0 ) ) +
     &      TWO3 * LOG( CBLK( LCELL,VAT3 ) ) -
     &             LOG( CBLK( LCELL,VAT2 ) )

         L2SGAT = MAX( MINL2SG, L2SGAT )
         L2SGAT = MIN( MAXL2SG, L2SGAT )

         XXLSGAT( LCELL ) = SQRT( L2SGAT )
         ESAT36 = EXP( 4.5 * L2SGAT )

C *** accumulation mode:

         L2SGAC =
     &      ONE3 * LOG( CBLK( LCELL,VAC0 ) ) +
     &      TWO3 * LOG( CBLK( LCELL,VAC3 ) ) -
     &             LOG( CBLK( LCELL,VAC2 ) )

         L2SGAC = MAX( MINL2SG, L2SGAC )
         L2SGAC = MIN( MAXL2SG, L2SGAC )
         XXLSGAC( LCELL ) = SQRT( L2SGAC )
         ESAC36 = EXP( 4.5 * L2SGAC )

C *** Calculate geometric mean diameters [ m ]

         DGATK( LCELL ) = MAX( DGMIN, (  CBLK( LCELL,VAT3 ) /
     &              ( CBLK( LCELL,VAT0 ) * ESAT36 ) ) ** ONE3 )

         DGACC( LCELL )  = MAX( DGMIN, (   CBLK( LCELL,VAC3 ) /
     &              ( CBLK( LCELL,VAC0 ) * ESAC36 ) ) ** ONE3 )

         DGCOR( LCELL ) = MAX( DGMIN, (  CBLK( LCELL,VCOR3 ) /
     &              ( CBLK( LCELL,VCORN ) * ESC36 ) ) ** ONE3  )

      END DO  ! end loop for diameters and standard deviations

C *** end of code from getpar

ccccccccccccccccccccccccccccccccccccccccc
C *** now get dry deposition velocities:
ccccccccccccccccccccccccccccccccccccccccc

      CALL GETDEP_V ( CELLNUM, N_AE_DEP_SPC,
     &                BLKTA, BLKDENS,
     &                XLM, AMU,
     &                BLKWSTAR, BLKUSTAR, BLKRA,
     &                DGATK, DGACC, DGCOR,
     &                XXLSGAT, XXLSGAC,
     &                PDENSAT, PDENSAC, PDENSCO,
     &                VDEP )

C Return dry deposition velocities for aerosols.
C These variables are for the first layer (FL).

      DO NCELL = 1, CELLNUM
         C = CCOL( NCELL )
         R = CROW( NCELL )
         DO V = 1, N_AE_DEPV
            IF ( DEPV_SUR( V ) .GT. 0 ) THEN
               VDEP_AE( V,C,R ) = VDEP( NCELL, DEPV_SUR( V ) )
            ELSE
               VDEP_AE( V,C,R ) = 0.0
            END IF
         END DO
      END DO

      RETURN
      END SUBROUTINE AERO_DEPV

cccccccccccccccccccccccccccccccccccccccccccccccccc
C *** subroutine for deposition velocities follows
cccccccccccccccccccccccccccccccccccccccccccccccccc

C::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE GETDEP_V ( NUMCELLS, N_AE_DEP_SPC,
     &                      BLKTA, BLKDENS,
     &                      XLM, AMU,
     &                      BLKWSTAR, BLKUSTAR, BLKRA,
     &                      DGATK, DGACC, DGCOR,
     &                      XXLSGAT, XXLSGAC,
     &                      PDENSAT, PDENSAC, PDENSCO,
     &                      VDEP )

C *** Calculate deposition velocity for Aitken, accumulation, and
C     coarse modes.
C     Reference:
C     Binkowski F. S., and U. Shankar, The regional particulate
C     model 1. Model description and preliminary results.
C     J. Geophys. Res., 100, D12, 26191-26209, 1995.
C
C    May 05 D.Schwede: added impaction term to coarse mode dry deposition
C 25 May 05 J.Pleim:  Updated dry dep velocity calculation for aerosols
C                     to Venkatram and Pleim (1999)
C 20 Jul 05 J.Pleim:  Changed impaction term using modal integration of
C                     Stokes**2 / 400 (Giorgi, 1986, JGR)

      IMPLICIT NONE

C *** input argumets

      INTEGER NUMCELLS
      INTEGER N_AE_DEP_SPC

C     meteorological information in blocked arays:

      REAL BLKTA  ( NUMCELLS )  ! air temperature [ K ]
      REAL BLKDENS( NUMCELLS )  ! air density  [ kg/m**3 ]

C     atmospheric properties

      REAL XLM( NUMCELLS )      ! atmospheric mean free path [ m ]
      REAL AMU( NUMCELLS )      ! atmospheric dynamic viscosity [ kg/(m s) ]

C     Planetary boundary laryer (PBL) variables:

      REAL BLKWSTAR( NUMCELLS ) ! convective velocity scale [ m/s ]
      REAL BLKUSTAR( NUMCELLS ) ! friction velocity [ m/s ]
      REAL BLKRA   ( NUMCELLS ) ! aerodynamic resistance [ s/m ]

C     aerosol properties:

C     modal diameters: [ m ]

      REAL DGATK( NUMCELLS )    ! nuclei mode geometric mean diameter  [ m ]
      REAL DGACC( NUMCELLS )    ! accumulation geometric mean diameter [ m ]
      REAL DGCOR( NUMCELLS )    ! coarse mode geometric mean diameter  [ m ]

C     log of modal geometric standard deviations

      REAL XXLSGAT( NUMCELLS )  ! Aitken mode
      REAL XXLSGAC( NUMCELLS )  ! accumulation mode

C     average modal particle densities  [ kg/m**3 ]

      REAL PDENSAT( NUMCELLS )  ! average particle density in nuclei mode
      REAL PDENSAC( NUMCELLS )  ! average particle density in accumulation mode
      REAL PDENSCO( NUMCELLS )  ! average particle density in coarse mode

C *** output argument

      REAL VDEP( NUMCELLS,N_AE_DEP_SPC ) ! deposition  velocity [ m/s ]

C *** internal:

      INTEGER, PARAMETER :: VDNATK = 1  ! Aitken mode number
      INTEGER, PARAMETER :: VDNACC = 2  ! accumulation mode number
      INTEGER, PARAMETER :: VDNCOR = 3  ! coarse mode number
      INTEGER, PARAMETER :: VDMATK = 4  ! Aitken mode mass
      INTEGER, PARAMETER :: VDMACC = 5  ! accumulation mode mass
      INTEGER, PARAMETER :: VDMCOR = 6  ! coarse mode mass
      INTEGER, PARAMETER :: VDSATK = 7  ! Aitken mode surface area
      INTEGER, PARAMETER :: VDSACC = 8  ! accumulation mode surface area

C model Knudsen numbers

      REAL KNATK   ! Aitken mode Knudsen number
      REAL KNACC   ! accumulation "
      REAL KNCOR   ! coarse mode

C modal particle diffusivities for number and 3rd moment, or mass:

      REAL DCHAT0N, DCHAT0A, DCHAT0C
      REAL DCHAT2N, DCHAT2A
      REAL DCHAT3N, DCHAT3A, DCHAT3C

C modal sedimentation velocities for number and 3rd moment, or mass:

      REAL VGHAT0N, VGHAT0A, VGHAT0C
      REAL VGHAT2N, VGHAT2A
      REAL VGHAT3N, VGHAT3A, VGHAT3C

      INTEGER NCELL

      REAL DCONST1, DCONST1N, DCONST1A, DCONST1C
      REAL DCONST2, DCONST3N, DCONST3A, DCONST3C
      REAL SC0N, SC0A, SC0C     ! Schmidt numbers for number
      REAL SC2N, SC2A           ! Schmidt numbers for 2ND MOMENT
      REAL SC3N, SC3A, SC3C     ! Schmidt numbers for 3rd moment
      REAL STOKEN, STOKEA, STOKEC ! Stokes numbers for each mode
      REAL RD0N, RD0A, RD0C     ! canopy resistance for number
      REAL RD2N, RD2A           ! canopy resistance for 2nd moment
      REAL RD3N, RD3A, RD3C     ! canopy resisteance for 3rd moment
      REAL UTSCALE              ! scratch function of USTAR and WSTAR
      REAL NU                   ! kinematic viscosity [ m**2 s**-1 ]
      REAL USTFAC               ! scratch function of USTAR, NU, and GRAV

      REAL, PARAMETER :: BHAT = 1.246 ! Constant from Cunningham slip correction

      REAL, PARAMETER :: PI      = 3.141593 ! single precision

      REAL, PARAMETER :: PI6     = PI / 6.0

      REAL, PARAMETER :: THREEPI = 3.0 * PI

      REAL, PARAMETER :: ONE3    = 1.0 / 3.0

      REAL, PARAMETER :: TWO3    = 2.0 / 3.0

      REAL, PARAMETER :: AVO = 6.0221367 E23 ! Avogadro's Constant [ 1/mol ]

      REAL, PARAMETER :: RGASUNIV = 8.314510 ! universal gas const [ J/mol-K ]

      REAL, PARAMETER :: BOLTZ = RGASUNIV / AVO ! Boltzmann's Constant [ J/K ]

      REAL, PARAMETER :: GRAV = 9.80622 ! mean gravitational accel [ m/sec**2 ]
                                        ! FSB NOTE: Value is now mean of polar
                                        ! and equatorial values. Source: CRC
                                        ! Handbook (76th Ed) page 14-6.

C Scalar variables for fixed standard deviations.

      REAL    XXLSGCO         ! log(SGINICO )

      REAL    L2SGINICO       ! log(SGINICO ) ** 2

      REAL    EC1             ! coarse mode exp( log^2( sigmag )/8 )

      REAL, SAVE :: ESC04     ! coarse       "

      REAL, SAVE :: ESC08     ! coarse       "

      REAL, SAVE :: ESC16     ! coarse       "

      REAL, SAVE :: ESC20     ! coarse       "

      REAL, SAVE :: ESC28     ! coarse       "

      REAL, SAVE :: ESC32     ! coarse       "

      REAL, SAVE :: ESC36     ! coarse       "

      REAL, SAVE :: ESC64     ! coarse       "

      REAL, SAVE :: ESC128    ! coarse       "

      REAL, SAVE :: ESC160    ! coarse       "

      REAL, SAVE :: ESCM20    ! coarse       "

      REAL, SAVE :: ESCM32    ! coarse       "

!     REAL, PARAMETER :: SGINICO = 2.5     ! fixed l sigma-G for coarse mode
      REAL, PARAMETER :: SGINICO = 2.2     ! changed 8/4/03 to be consistent
                                           ! with aero_depv

      REAL, PARAMETER :: DGINIAT = 0.01E-6 ! initial mean diam. for Aitken
                                           ! mode [ m ]

C Scalar variables for  VARIABLE standard deviations.

      REAL    L2SGAT, L2SGAC    ! see usage

      REAL    EAT1             ! Aitken mode exp( log^2( sigmag )/8 )
      REAL    EAC1             ! accumulation mode exp( log^2( sigmag )/8 )

      REAL    ESAT04           ! Aitken       " **4
      REAL    ESAC04           ! accumulation "

      REAL    ESAT08           ! Aitken       " **8
      REAL    ESAC08           ! accumulation "

      REAL    ESAT12
      REAL    ESAC12

      REAL    ESAT16           ! Aitken       " **16
      REAL    ESAC16           ! accumulation "

      REAL    ESAT20           ! Aitken       " **20
      REAL    ESAC20           ! accumulation "

      REAL    ESAT28           ! Aitken       " **28
      REAL    ESAC28           ! accumulation "

      REAL    ESAT32           ! Aitken       " **32
      REAL    ESAC32           ! accumulation "

      REAL    ESAT36           ! Aitken       " **36
      REAL    ESAC36           ! accumulation "

      REAL    ESAT48
      REAL    ESAC48

      REAL    ESAT64           ! Aitken       " **64
      REAL    ESAC64           ! accumulation "

      REAL    ESAT128          ! Aitken       " **128
      REAL    ESAC128          ! accumulation "

      REAL    ESAT160          ! Aitken       " **160
      REAL    ESAC160          ! accumulation "

      REAL    ESATM12
      REAL    ESACM12

      REAL    ESATM16
      REAL    ESACM16

      REAL    ESATM20          ! Aitken       " **(-20)
      REAL    ESACM20          ! accumulation "

      REAL    ESATM32          ! Aitken       " **(-32)
      REAL    ESACM32          ! accumulation "

      REAL    EIM              ! Impaction efficiency

      LOGICAL, SAVE :: FIRSTIME = .TRUE.

C----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN

         FIRSTIME = .FALSE.

         XXLSGCO = LOG( SGINICO )
         L2SGINICO = XXLSGCO ** 2

         EC1   = EXP( 0.125 * L2SGINICO )

         ESC04  = EC1 ** 4

         ESC08  = ESC04 * ESC04

         ESC16  = ESC08 * ESC08

         ESC20  = ESC16 * ESC04

         ESC28  = ESC20 * ESC08

         ESC32  = ESC16 * ESC16

         ESC36  = ESC16 * ESC20

         ESC64  = ESC32 * ESC32

         ESC128 = ESC64 * ESC64

         ESC160 = ESC128 * ESC32

         ESCM20 = 1.0 / ESC20

         ESCM32 = 1.0 / ESC32

      END IF

      DO NCELL = 1, NUMCELLS ! Calculate Knudsen numbers

         KNATK = 2.0 * XLM( NCELL ) / DGATK( NCELL )
         KNACC = 2.0 * XLM( NCELL ) / DGACC( NCELL )
         KNCOR = 2.0 * XLM( NCELL ) / DGCOR( NCELL )

C *** Calculate functions of variable standard deviation.

         L2SGAT = XXLSGAT(NCELL) * XXLSGAT(NCELL)
         L2SGAC = XXLSGAC(NCELL) * XXLSGAC(NCELL)
         EAT1   = EXP( 0.125 * L2SGAT )
         EAC1   = EXP( 0.125 * L2SGAC )

         ESAT04  = EAT1 ** 4
         ESAC04  = EAC1 ** 4

         ESAT08  = ESAT04 * ESAT04
         ESAC08  = ESAC04 * ESAC04

         ESAT12  = ESAT04 * ESAT08
         ESAC12  = ESAC04 * ESAC08

         ESAT16  = ESAT08 * ESAT08
         ESAC16  = ESAC08 * ESAC08

         ESAT20  = ESAT16 * ESAT04
         ESAC20  = ESAC16 * ESAC04

         ESAT28  = ESAT20 * ESAT08
         ESAC28  = ESAC20 * ESAC08

         ESAT32  = ESAT16 * ESAT16
         ESAC32  = ESAC16 * ESAC16

         ESAT36  = ESAT16 * ESAT20
         ESAC36  = ESAC16 * ESAC20

         ESAT48  = ESAT36 * ESAT12
         ESAC48  = ESAC36 * ESAC12

         ESAT64  = ESAT32 * ESAT32
         ESAC64  = ESAC32 * ESAC32

         ESAT128 = ESAT64 * ESAT64
         ESAC128 = ESAC64 * ESAC64

         ESAT160 = ESAT128* ESAT32
         ESAC160 = ESAC128* ESAC32

C *** calculate inverses:

         ESATM12 = 1.0 / ESAT12
         ESACM12 = 1.0 / ESAC12

         ESATM16 = 1.0 / ESAT16
         ESACM16 = 1.0 / ESAC16

         ESATM20 = 1.0 / ESAT20
         ESACM20 = 1.0 / ESAC20

         ESATM32 = 1.0 / ESAT32
         ESACM32 = 1.0 / ESAC32

         DCONST1 = BOLTZ * BLKTA( NCELL ) /
     &              ( THREEPI * AMU( NCELL ) )
         DCONST1N = DCONST1 / DGATK( NCELL )
         DCONST1A = DCONST1 / DGACC( NCELL )
         DCONST1C = DCONST1 / DGCOR( NCELL )
         DCONST2  = GRAV / ( 18.0 * AMU( NCELL ) )
         DCONST3N = DCONST2 * PDENSAT( NCELL ) * DGATK( NCELL ) **2
         DCONST3A = DCONST2 * PDENSAC( NCELL ) * DGACC( NCELL ) **2
         DCONST3C = DCONST2 * PDENSCO( NCELL ) * DGCOR( NCELL ) **2

C i-mode

         DCHAT0N  = DCONST1N
     &                    * ( ESAT04  + BHAT * KNATK * ESAT16 )
         DCHAT2N  = DCONST1N
     &                    * ( ESATM12  + BHAT * KNATK * ESATM16 )
         DCHAT3N  = DCONST1N
     &                    * ( ESATM20 + BHAT * KNATK * ESATM32 )
         VGHAT0N  = DCONST3N
     &                    * ( ESAT16  + BHAT * KNATK * ESAT04 )
         VGHAT2N  = DCONST3N
     &                    * ( ESAT48  + BHAT * KNATK * ESAT20 )
         VGHAT3N  = DCONST3N
     &                    * ( ESAT64  + BHAT * KNATK * ESAT28 )

C j-mode

         DCHAT0A  = DCONST1A
     &                    * ( ESAC04  + BHAT * KNACC * ESAC16 )
         DCHAT2A  = DCONST1A
     &                    * ( ESACM12 + BHAT * KNACC * ESACM16 )
         DCHAT3A  = DCONST1A
     &                    * ( ESACM20 + BHAT * KNACC * ESACM32 )
         VGHAT0A  = DCONST3A
     &                    * ( ESAC16  + BHAT * KNACC * ESAC04 )
         VGHAT2A  = DCONST3A
     &                    * ( ESAC48  + BHAT * KNACC * ESAC20 )
         VGHAT3A  = DCONST3A
     &                    * ( ESAC64  + BHAT * KNACC * ESAC28 )

C coarse mode

         DCHAT0C  = DCONST1C
     &                    * ( ESC04  + BHAT * KNCOR * ESC16 )
         DCHAT3C  = DCONST1C
     &                    * ( ESCM20 + BHAT * KNCOR * ESCM32 )
         VGHAT0C  = DCONST3C
     &                    * ( ESC16  + BHAT * KNCOR * ESC04 )
         VGHAT3C  = DCONST3C
     &                    * ( ESC64  + BHAT * KNCOR * ESC28 )

C now calculate the deposition velocities

         NU = AMU( NCELL ) / BLKDENS( NCELL )
         USTFAC = BLKUSTAR( NCELL ) * BLKUSTAR( NCELL ) / ( GRAV * NU )
         STOKEN = DCONST3N * USTFAC
         STOKEA = DCONST3A * USTFAC
         STOKEC = DCONST3C * USTFAC
         UTSCALE = BLKUSTAR( NCELL )
     &           + 0.24 * BLKWSTAR( NCELL ) * BLKWSTAR( NCELL )
     &           /        BLKUSTAR( NCELL )

C first do 0th moment for the deposition of number number

C  Aitken mode

         SC0N = NU / DCHAT0N
         EIM = STOKEN**2 / 400.0 * ESAT64
         EIM = MIN( EIM, 1.0 )
         RD0N = 1.0 / ( UTSCALE *
     &                ( SC0N ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDNATK ) = VGHAT0N
     &           / ( 1.0 - EXP(-VGHAT0N * ( BLKRA( NCELL ) + RD0N ) ) )

C accumulation mode

         SC0A = NU / DCHAT0A
         EIM = STOKEA**2 / 400.0 * ESAC64
         EIM = MIN( EIM, 1.0 )
         RD0A = 1.0 / ( UTSCALE *
     &                ( SC0A ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDNACC ) = VGHAT0A
     &           / ( 1.0 - EXP(-VGHAT0A * ( BLKRA( NCELL ) + RD0A ) ) )

C coarse mode

         SC0C = NU / DCHAT0C
         EIM = STOKEC**2 / 400.0 * ESC64
         EIM = MIN( EIM, 1.0 )
         RD0C = 1.0 / ( UTSCALE *
     &                ( SC0C ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDNCOR ) = VGHAT0C
     &           / ( 1.0 - EXP(-VGHAT0C * ( BLKRA( NCELL ) + RD0C ) ) )

C now do 2nd moment for the deposition of surface area

C  Aitken mode

         SC2N = NU / DCHAT2N
         EIM = STOKEN**2 / 400.0 * ESAT128
         EIM = MIN( EIM, 1.0 )
         RD2N = 1.0 / ( UTSCALE *
     &                ( SC2N ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDSATK ) = VGHAT2N
     &           / ( 1.0 - EXP(-VGHAT2N * ( BLKRA( NCELL ) + RD2N ) ) )

C accumulation mode

         SC2A = NU / DCHAT2A
         EIM = STOKEA**2 / 400.0 * ESAC128
         EIM = MIN( EIM, 1.0 )
         RD2A = 1.0 / ( UTSCALE *
     &                ( SC2A ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDSACC ) = VGHAT2A
     &           / ( 1.0 - EXP(-VGHAT2A * ( BLKRA( NCELL ) + RD2A ) ) )

C now do 3rd moment for the deposition of mass

C  Aitken mode

         SC3N = NU / DCHAT3N
         EIM = STOKEN**2 / 400.0 * ESAT160
         EIM = MIN( EIM, 1.0 )
         RD3N = 1.0 / ( UTSCALE *
     &                ( SC3N ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDMATK ) = VGHAT3N
     &           / ( 1.0 - EXP(-VGHAT3N * ( BLKRA( NCELL ) + RD3N ) ) )

C accumulation mode

         SC3A = NU / DCHAT3A
         EIM = STOKEA**2 / 400.0 * ESAC160
         EIM = MIN( EIM, 1.0 )
         RD3A = 1.0 / ( UTSCALE *
     &                ( SC3A ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDMACC ) = VGHAT3A
     &           / ( 1.0 - EXP(-VGHAT3A * ( BLKRA( NCELL ) + RD3A ) ) )

C coarse mode

         SC3C = NU / DCHAT3C
         EIM = STOKEC**2 / 400.0 * ESC160
         EIM = MIN( EIM, 1.0 )
         RD3C = 1.0 / ( UTSCALE *
     &                ( SC3C ** ( -TWO3 ) + EIM ) )

         VDEP( NCELL,VDMCOR ) = VGHAT3C
     &           / ( 1.0 - EXP(-VGHAT3C * ( BLKRA( NCELL ) + RD3C ) ) )

      END DO ! end loop on deposition velocities

      RETURN
      END SUBROUTINE GETDEP_V