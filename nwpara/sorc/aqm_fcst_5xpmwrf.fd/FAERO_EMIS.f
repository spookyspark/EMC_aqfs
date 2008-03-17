
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/vdiff/eddy/AERO_EMIS.F,v 1.1.1.1 2005/09/09 18:56:06 sjr Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
C  MODULE AERO_EMIS contains emissions code required for the modal
C     aerosol module in CMAQ
C                                 Coded by Dr. Francis S. Binkowski
C                                      and Dr. Jeffrey O. Young
C
C  CONTAINS: SUBROUTINE RDEMIS_AE
C            Variable declarations needed for other subroutines in CMAQ's
C             vertical diffusion module
C
C  DEPENDENT UPON:  NONE
C
C  REVISION HISTORY:
C
C   30 Aug 01 J.Young:  dyn alloc - Use HGRD_DEFN
C   09 Oct 03 J.Gipson: added MW array for AE emis species to module contents
C   31 Jan 05 J.Young:  dyn alloc - establish both horizontal & vertical
C                       domain specifications in one module, GRID_CONF
C   26 Apr 05 P.Bhave:  removed code supporting the "old type" of emission 
C                        files that had unspeciated PM10 and PM2.5 only
C                       removed need for 'AERO_SPC.EXT' by declaring the 
C                        required variables locally
C   13 Jun 05 P.Bhave:  added vars needed for sea-salt emission processing
C                       inherit N_AE_EMIS,AE_EMIS,AE_EMIS_MAP from AE_EMIS.EXT
C                       moved RHO* parameters from RDEMIS_AE to this module
C                        for use by SSEMIS routine
C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

      MODULE AERO_EMIS

      USE GRID_CONF           ! horizontal & vertical domain specifications
       
      IMPLICIT NONE
      
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_EMIS.EXT"   ! aerosol emission surrogate names and map table
            
C Array dimensions
      INTEGER, PARAMETER :: NAEMISMAX = 6  ! maximum number of PM species
                                           ! in emission input file
      INTEGER, PARAMETER :: NSSDIAG = 11   ! number of species in sea-salt
                                           ! diagnostic emission file
      INTEGER, PARAMETER :: NSSSPC = 4     ! number of chemical species in
                                           ! fresh sea-salt aerosol
      INTEGER, PARAMETER :: NSSMOD = 3     ! number of lognormal modes in
                                           ! sea-salt aerosol

C Aerosol species names
      CHARACTER( 16 ), SAVE :: AEMIS( NAEMISMAX )   ! in emission input files
      CHARACTER( 16 ), SAVE :: WRSS_SPC( NSSDIAG )  ! in sea-salt output file

C Molar masses of each aerosol species
      REAL, SAVE :: AE_EM_MW( N_AE_EMIS ) 

C Indices in the PM_EM array
      INTEGER, SAVE :: VPSO4   ! primary fine sulfate
      INTEGER, SAVE :: VPNO3   ! primary fine nitrate
      INTEGER, SAVE :: VPEC    ! primary fine elemental carbon
      INTEGER, SAVE :: VPOA    ! primary fine organic carbon 
      INTEGER, SAVE :: VPMF    ! unspeciated fine aerosol
      INTEGER, SAVE :: VPMC    ! primary coarse aerosol

C     Bulk component densities [ kg/m3 ]
      REAL, PARAMETER :: RHOSO4 = 1.8E3   ! density of sulfate aerosol
      REAL, PARAMETER :: RHONO3 = 1.8E3   ! density of nitrate aerosol
      REAL, PARAMETER :: RHOORG = 2.0E3   ! density of organic aerosol
      REAL, PARAMETER :: RHOSOIL = 2.6E3  ! density of soil dust
      REAL, PARAMETER :: RHOSEAS = 2.2E3  ! density of marine aerosol
      REAL, PARAMETER :: RHOANTH = 2.2E3  ! density of elemental carbon and
                                          !  unspeciated anthropogenic aerosol
      REAL, PARAMETER :: RHOH2O = 1.0E3   ! density of water
                                             
C Species names in the sea-salt-emissions diagnostic file
      DATA WRSS_SPC( 1 ) / 'ANAJ'  /   ! accumulation mode sodium
      DATA WRSS_SPC( 2 ) / 'ACLJ'  /   ! accumulation mode chloride
      DATA WRSS_SPC( 3 ) / 'ASO4J' /   ! accumulation mode sulfate
      DATA WRSS_SPC( 4 ) / 'AH2OJ' /   ! accumulation mode water
      DATA WRSS_SPC( 5 ) / 'ANAK'  /   ! coarse mode sodium
      DATA WRSS_SPC( 6 ) / 'ACLK'  /   ! coarse mode chloride
      DATA WRSS_SPC( 7 ) / 'ASO4K' /   ! coarse mode sulfate 
      DATA WRSS_SPC( 8 ) / 'AH2OK' /   ! coarse mode water   
      DATA WRSS_SPC( 9 ) / 'ANUMJ' /   ! accumulation mode number
      DATA WRSS_SPC( 10) / 'ANUMK' /   ! coarse mode number
      DATA WRSS_SPC( 11) / 'ASRFJ' /   ! accumulation mode surface area

C Indices to sea-salt species in mass-emission arrays
      INTEGER, PARAMETER :: KNA  = 1   ! position of sodium
      INTEGER, PARAMETER :: KCL  = 2   ! position of chloride
      INTEGER, PARAMETER :: KSO4 = 3   ! position of sulfate
      INTEGER, PARAMETER :: KH2O = 4   ! position of water

      CONTAINS

C ///////////////////////////////////////////////////////////////////////////
C  SUBROUTINE RDEMIS_AE reads aerosol emissions from gridded input file and
C   converts into molar-mixing-ratio units, as required by the vertical 
C   diffusion routines
C
C  KEY SUBROUTINES/FUNCTIONS CALLED:  SSEMIS
C
C  REVISION HISTORY:
C
C   30 Aug 01 J.Young:  dynamic allocation - Use INTERPX
C   29 Jul 03 P.Bhave:  added compatibility with emission files that contain 
C                       PM10, PEC, POA, PNO3, PSO4, and PMF, but do not 
C                       contain PMC
C   20 Aug 03 J.Young:  return aero emissions in molar mixing ratio, ppm units
C   09 Oct 03 J.Gipson: added MW array for AE emis species to module contents
C   01 Sep 04 P.Bhave:  changed MW for primary organics from 120 to 220 g/mol,
C                       to match MWPOA in subroutine ORGAER3.
C   31 Jan 05 J.Young:  dyn alloc - removed HGRD_ID, VGRID_ID, and COORD_ID 
C                       include files because those parameters are now 
C                       inherited from the GRID_CONF module
C   26 Apr 05 P.Bhave:  removed code supporting the "old type" of emission 
C                        files that had unspeciated PM10 and PM2.5 only
C                       removed need for 'AERO_CONST.EXT' by declaring the
C                        required variables locally
C                       simplified the CONVM, CONVN, CONVS calculations
C                       updated and enhanced in-line documentation
C   03 May 05 P.Bhave:  fixed bug in the H2SO4 unit conversion, initially
C                        identified by Jinyou Liang of CARB
C   13 Jun 05 P.Bhave:  calculate sea-salt emissions; execute if MECHNAME = AE4
C                        read input fields from new OCEAN_1 file
C                        read extra input fields from MET_CRO_2D and MET_CRO_3D
C                        write diagnostic sea-salt emission file
C                        added TSTEP to call vector for diagnostic output file
C                       inherit MWs from AE_SPC.EXT instead of hardcoding
C                       find pointers to CGRID indices instead of hardcoding
C
C  REFERENCES:
C    CRC76,        "CRC Handbook of Chemistry and Physics (76th Ed)",
C                   CRC Press, 1995
C    Hobbs, P.V.   "Basic Physical Chemistry for the Atmospheric Sciences",
C                   Cambridge Univ. Press, 206 pp, 1995.
C    Snyder, J.P.  "Map Projections-A Working Manual, U.S. Geological Survey
C                   Paper 1395 U.S.GPO, Washington, DC, 1987.
c    Binkowski & Roselle  Models-3 Community Multiscale Air Quality (CMAQ)
C                   model aerosol component 1: Model Description.  
C                   J. Geophys. Res., Vol 108, No D6, 4183 
C                   doi:10.1029/2001JD001409, 2003

         SUBROUTINE RDEMIS_AE ( JDATE, JTIME, TSTEP, EMISLYRS, RJACM,
     &                          VDEMIS, VDEMIS_AE )
     
         INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/RXCM.EXT"    ! to get mech name
         INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"    ! aerosol species names and molecular weights
         INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_EMIS.EXT"   ! gas chem emis surrogate names and map table
         INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"   ! I/O parameters definitions

!.........................................................................
! Version "@(#)$Header$"
!    EDSS/Models-3 I/O API.  Copyright (C) 1992-2002 MCNC
!    Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
!    See file "LGPL.txt" for conditions of use.
!....................................................................
!  INCLUDE FILE  IODECL3.EXT
!
!
!  DO NOT EDIT !!
!
!       The EDSS/Models-3 I/O API depends in an essential manner
!       upon the contents of this INCLUDE file.  ANY CHANGES are
!       likely to result in very obscure, difficult-to-diagnose
!       bugs caused by an inconsistency between standard "libioapi.a"
!       object-libraries and whatever code is compiled with the
!       resulting modified INCLUDE-file.
!
!       By making any changes to this INCLUDE file, the user
!       explicitly agrees that in the case any assistance is 
!       required of MCNC or of the I/O API author, Carlie J. Coats, Jr.
!       as a result of such changes, THE USER AND/OR HIS PROJECT OR
!       CONTRACT AGREES TO REIMBURSE MCNC AND/OR THE I/O API AUTHOR,
!       CARLIE J. COATS, JR., AT A RATE TRIPLE THE NORMAL CONTRACT
!       RATE FOR THE SERVICES REQUIRED.
!
!  CONTAINS:  declarations and usage comments for the Models-3 (M3)
!             Interprocess Communication Applications Programming
!             Interface (API)
!
!  DEPENDENT UPON:  consistency with the API itself.
!
!  RELATED FILES:  PARM3.EXT, FDESC3.EXT
!
!  REVISION HISTORY:
!       prototype 3/1992 by Carlie J. Coats, Jr., MCNC Environmental
!       Programs
!
!       Modified  2/2002 by CJC:  updated dates, license, compatibility
!       with both free and fixed Fortran 9x source forms
!
!....................................................................

        LOGICAL         CHECK3  !  is JDATE:JTIME available for FNAME?
        LOGICAL         CLOSE3  !  close FNAME
        LOGICAL         DESC3   !  Puts M3 file descriptions into FDESC3.EXT
        LOGICAL         FILCHK3 ! check file type and dimensions
        INTEGER         INIT3   !  Initializes M3 API and returns unit for log
        LOGICAL         SHUT3   !  Shuts down API
        LOGICAL         OPEN3   !  opens an M3 file
        LOGICAL         READ3   !  read M3 file for variable,layer,timestep
        LOGICAL         WRITE3  !  write timestep to M3 file
        LOGICAL         XTRACT3 !  extract window from timestep in a M3 file
        LOGICAL         INTERP3 !  do time interpolation from a M3 file
        LOGICAL         DDTVAR3 !  do time derivative from M3 file

        LOGICAL         INTERPX !  time interpolation from a window
                                !  extraction from an M3 gridded file
!!        LOGICAL      PINTERPB !  1 time interpolation from an
                                !  M3 boundary file

        LOGICAL         INQATT3 !  inquire attributes in M3 file
        LOGICAL         RDATT3  !  read numeric attributes by name from M3 file
        LOGICAL         WRATT3  !  add new numeric attributes "
        LOGICAL         RDATTC  !  read CHAR attributes       "
        LOGICAL         WRATTC  !  add new CHAR attributes    "

        LOGICAL         SYNC3   !  flushes file to disk, etc.

        EXTERNAL        CHECK3 , CLOSE3,  DESC3  , FILCHK3, INIT3  ,
     &                  SHUT3  , OPEN3  , READ3  , WRITE3 , XTRACT3,
     &                  INTERP3, DDTVAR3, INQATT3, RDATT3 , WRATT3 ,
     &                  RDATTC , WRATTC,  SYNC3,   INTERPX ! , PINTERPB

!.......................................................................
!..................  API FUNCTION USAGE AND EXAMPLES  ..................
!.......
!.......   In the examples below, names (FILENAME, PROGNAME, VARNAME)
!.......   should be CHARACTER*16, STATUS and RDFLAG are LOGICAL, dates
!.......   are INTEGER, coding the Julian date as YYYYDDD, times are
!.......   INTEGER, coding the time as HHMMSS, and LOGDEV is the FORTRAN
!.......   INTEGER unit number for the program's log file; and layer,
!.......   row, and column specifications use INTEGER FORTRAN array
!.......   index conventions (in particular, they are based at 1, not
!.......   based at 0, as in C).
!.......   Parameter values for "ALL...", for grid and file type IDs,
!.......   and for API dimensioning values are given in PARMS3.EXT;
!.......   file descriptions are passed via commons BDESC3 and CDESC3
!.......   in file FDESC3.EXT.
!.......
!.......   CHECK3():  check whether timestep JDATE:JTIME is available 
!.......   for variable VNAME in file FILENAME.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = CHECK3 ( FILENAME, VNAME, JDATE, JTIME )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (data-record not available in file FNAME)
!.......       END IF
!.......
!.......   CLOSE3():  check whether timestep JDATE:JTIME is available 
!.......   for variable VNAME in file FILENAME.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = CLOSE3 ( FILENAME )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... could not flush file to disk successfully,
!.......           or else file not currently open.
!.......       END IF
!.......
!.......   DESC3():   return description of file FILENAME to the user
!.......   in commons BDESC3 and CDESC3, file FDESC3.EXT.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = DESC3 ( FILENAME )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (file not yet opened)
!.......       END IF
!.......       ...
!.......       (Now common FDESC3 (file FDESC3.EXT) contains the descriptive
!.......       information for this file.)
!.......
!.......   FILCHK3():   check whether file type and dimensions for file 
!.......   FILENAME match the type and dimensions supplied by the user.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = FILCHK3 ( FILENAME, FTYPE, NCOLS, NROWS, NLAYS, NTHIK )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (file type and dimensions do not match
!.......                the supplied FTYPE, NCOLS, NROWS, NLAYS, NTHIK)
!.......       END IF
!.......       ...
!.......
!.......   INIT3():  set up the M3 API, open the program's log file, and
!.......   return the unit FORTRAN number for log file.  May be called
!.......   multiple times (in which case, it always returns the log-file's
!.......   unit number).  Note that block data INITBLK3.FOR must also be
!.......   linked in.
!.......   FORTRAN usage is:
!.......
!.......       LOGDEV = INIT3 ( )
!.......       IF ( LOGDEV .LT. 0 ) THEN
!.......           ... (can't proceed:  probably can't open the log.
!.......                Stop the program)
!.......       END IF
!.......
!.......   OPEN3():  open file FILENAME from program PROGNAME, with
!.......   requested read-write/old-new status.  For files opened for WRITE,
!.......   record program-name and other history info in their headers.
!.......   May be called multiple times for the same file (in which case,
!.......   it returns true unless the request is for READ-WRITE status
!.......   for a file already opened READ-ONLY).  Legal statuses are:
!.......   FSREAD3: "old read-only"
!.......   FSRDWR3: "old read-write"
!.......   FSNEW3:  "new (read-write)"
!.......   FSUNKN3: "unknown (read_write)"
!.......   FORTRAN usage is:
!.......
!.......       STATUS = OPEN3 ( FILENAME, FSTATUS, PROGNAME )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (process the error)
!.......       END IF
!.......
!.......   READ3():  read data from FILENAME for timestep JDATE:JTIME,
!.......   variable VNAME, layer LAY, into location  ARRAY.
!.......   If VNAME==ALLVARS3=='ALL         ', reads all variables;
!.......   if LAY==ALLAYS3==-1, reads all layers.
!.......   Offers random access to the data by filename, date&time, variable,
!.......   and layer.  For DICTIONARY files, logical name for file being
!.......   requested maps into the VNAME argument.  For time-independent
!.......   files (including DICTIONARY files), JDATE and JTIME are ignored.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = READ3 ( FILENAME, VNAME, LAY, JDATE, JTIME, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (read failed -- process this error.)
!.......       END IF
!.......
!.......   SHUT3():  Flushes and closes down all M3 files currently open.
!.......   Must be called before program termination; if it returns FALSE
!.......   the run must be considered suspect.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = SHUT3 ( )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (Flush of files to disk probably didn't work;
!.......                look at netCDF error messages)
!.......       END IF
!.......
!.......   WRITE3():  write data from ARRAY to file FILENAME for timestep
!.......   JDATE:JTIME.  For GRIDDED, BUONDARY, and CUSTOM files, VNAME
!.......   must be a variable found in the file, or else ALLVARS3=='ALL'
!.......   to write all variables from ARRAY.  For other file types,
!.......   VNAME _must_ be ALLVARS3.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = WRITE3 ( FILENAME, VNAME, JDATE, JTIME, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (write failed -- process this error.)
!.......       END IF
!.......
!.......   XTRACT3():  read/extract gridded data into location  ARRAY
!.......   from FILENAME for time step JDATE:JTIME, variable VNAME
!.......   and the data window defined by
!.......       LOLAY  <=  layer   <=  HILAY,
!.......       LOROW  <=  row     <=  HIROW,
!.......       LOCOL  <=  column  <=  HICOL
!.......   FORTRAN usage is:
!.......
!.......       STATUS = XTRACT3 ( FILENAME, VNAME,
!.......   &                      LOLAY, HILAY,
!.......   &                      LOROW, HIROW,
!.......   &                      LOCOL, HICOL,
!.......   &                      JDATE, JTIME, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (extract failed -- process this error.)
!.......       END IF
!.......
!.......   INTERP3():  read/interpolate gridded, boundary, or custom data 
!.......   into location  ARRAY from FILENAME for time JDATE:JTIME, variable 
!.......   VNAME, and all layers.  Note use of ASIZE = transaction size =
!.......   size of ARRAY, for error-checking.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = INTERPX ( FILENAME, VNAME, CALLER, JDATE, JTIME,
!.......   &                      ASIZE, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (interpolate failed -- process this error.)
!.......       END IF
!.......
!.......   INTERPX():  read/interpolate/window gridded, boundary, or custom
!.......   data into location  ARRAY from FILENAME for time JDATE:JTIME, 
!.......   variable VNAME, and all layers.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = INTERPX ( FILENAME, VNAME, CALLER, 
!.......   &                      COL0, COL1, ROW0, ROW1, LAY0, LAY1,
!.......   &                      JDATE, JTIME, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (windowed interpolate failed -- process this error.)
!.......       END IF
!.......
!.......   DDTVAR3():  read and calculate mean time derivative (per second) 
!.......   for gridded, boundary, or custom data.  Put result into location  
!.......   ARRAY from FILENAME for time JDATE:JTIME, variable VNAME, and all 
!.......   layers.  Note use of ASIZE = transaction size = size of ARRAY, 
!.......   for error-checking.  Note  d/dt( time-independent )==0.0
!.......   FORTRAN usage is:
!.......
!.......       STATUS = DDTVAR3 ( FILENAME, VNAME, JDATE, JTIME,
!.......   &                      ASIZE, ARRAY )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!.......
!.......   INQATT():  inquire how many attributes there are for a
!.......   particular file and variable (or for the file globally,
!.......   if the variable-name ALLVAR3 is used)), and what the 
!.......   names, types, and array-dimensions of these attributes are.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = INQATT3( FNAME, VNAME, MXATTS, 
!.......   &                     NATTS, ANAMES, ATYPES, ASIZES )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!....... 
!.......   RDATT3():  Reads an INTEGER, REAL, or DOUBLE attribute by name
!.......   for a specified file and variable into a user-specified array.
!.......   If variable name is ALLVAR3, reads the file-global attribute.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = RDATT3( FNAME, VNAME, ANAME, ATYPE, AMAX,
!.......   &                    ASIZE, AVAL )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!.......
!.......   WRATT3():  Writes an INTEGER, REAL, or DOUBLE attribute by name
!.......   for a specified file and variable.  If variable name is ALLVAR3, 
!.......   reads the file-global attribute.
!.......
!.......       STATUS =  WRATT3( FNAME, VNAME, 
!.......   &                     ANAME, ATYPE, AMAX, AVAL )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!.......   
!.......   RDATTC():  Reads a CHARACTER string attribute by name
!.......   for a specified file and variable into a user-specified array.
!.......   If variable name is ALLVAR3, reads the file-global attribute.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = RDATTC( FNAME, VNAME, ANAME, CVAL )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!.......
!.......   WRATT3():  Writes a CHARACTER string attribute by name
!.......   for a specified file and variable.  If variable name is ALLVAR3, 
!.......   reads the file-global attribute.
!.......
!.......       STATUS =  WRATTC( FNAME, VNAME, ANAME, CVAL )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (operation failed -- process this error.)
!.......       END IF
!.......
!.......   SYNC3():   Synchronize FILENAME with disk (flush output;
!.......   re-read header and invalidate data-buffers for input.
!.......   FORTRAN usage is:
!.......
!.......       STATUS = SYNC3 ( FILENAME )
!.......       IF ( .NOT. STATUS ) THEN
!.......           ... (file not yet opened, or disk-synch failed)
!.......       END IF
!.......       ...
!.......
!................   end   IODECL3.EXT   ....................................

!        INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"    ! I/O definitions and declarations
         INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/FILES_CTM.EXT"  ! file name parameters
         INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/FDESC3.EXT"   ! file header data structure


C *** ARGUMENTS
     
         INTEGER JDATE           ! current model date, coded YYYYDDD
         INTEGER JTIME           ! current model time, coded HHMMSS
         INTEGER TSTEP( 2 )      ! time step vector (HHMMSS)
                                 ! TSTEP(1) = local output step
                                 ! TSTEP(2) = sciproc sync. step (chem)
         INTEGER EMISLYRS        ! number of vertical layers on emissions file
         REAL    RJACM( NCOLS,NROWS,NLAYS ) ! recip of mid-layer Jacobian [1/m]
         REAL :: VDEMIS   ( :,:,:,: )       ! gas emissions [ppmv/s]
         REAL :: VDEMIS_AE( :,:,:,: )       ! aerosol emissions 
                                            ! [ppmv/s] for mass & number spcs
                                            ! [m2/mol/s] for surface area spcs

C *** LOCAL VARIABLES

C     Geometric Constants
         REAL( 8 ), PARAMETER :: PI = 3.14159265358979324 
         REAL, PARAMETER :: PI180 = PI / 180.0      ! degrees-to-radians
         REAL, PARAMETER :: F6DPI = 6.0 / PI
         REAL, PARAMETER :: F6DPIM9 = 1.0E-9 * F6DPI

C     Aerosol version name
         CHARACTER( 16 ), SAVE :: AE_VRSN

C     Indices in the VDEMIS_AE array
         INTEGER, SAVE :: VSO4AJ    ! accumulation mode sulfate
         INTEGER, SAVE :: VSO4AI    ! Aitken mode sulfate
         INTEGER, SAVE :: VNO3AJ    ! accumulation mode nitrate
         INTEGER, SAVE :: VNO3AI    ! Aitken mode nitrate
         INTEGER, SAVE :: VORGPAJ   ! accumulation mode primary anthropogenic
                                    ! organic aerosol
         INTEGER, SAVE :: VORGPAI   ! Aitken mode primary anthropogenic
                                    ! organic aerosol
         INTEGER, SAVE :: VECJ      ! accumulation mode elemental carbon
         INTEGER, SAVE :: VECI      ! Aitken mode elemental carbon
         INTEGER, SAVE :: VP25AJ    ! accumulation mode unspeciated PM2.5
         INTEGER, SAVE :: VP25AI    ! Aitken mode unspeciated PM2.5
         INTEGER, SAVE :: VANTHA    ! coarse mode anthropogenic aerosol
         INTEGER, SAVE :: VSEAS     ! coarse mode marine aerosol
         INTEGER, SAVE :: VSOILA    ! coarse mode soil-derived aerosol
         INTEGER, SAVE :: VAT0      ! Aitken mode number
         INTEGER, SAVE :: VAC0      ! accumulation mode number
         INTEGER, SAVE :: VCOR0     ! coarse mode number
         INTEGER, SAVE :: VSURFAT   ! Aitken mode surface area
         INTEGER, SAVE :: VSURFAC   ! accumulation mode surface area
         INTEGER, SAVE :: VH2OAJ    ! accumulation mode water 
         INTEGER, SAVE :: VH2OAI    ! Aitken mode water
         INTEGER, SAVE :: VNAJ      ! accumulation mode sodium
         INTEGER, SAVE :: VNAI      ! Aitken mode sodium
         INTEGER, SAVE :: VCLJ      ! accumulation mode chloride
         INTEGER, SAVE :: VCLI      ! Aitken mode chloride
         INTEGER, SAVE :: VNAK      ! coarse mode sodium
         INTEGER, SAVE :: VCLK      ! coarse mode chloride
         INTEGER, SAVE :: VSO4K     ! coarse mode sulfate
         INTEGER, SAVE :: VH2OK     ! coarse mode water

C     Geometric mean diameter by volume (or mass) of emitted particles in 
C     each mode [ m ].  See paragraph #14 of Binkowski & Roselle (2003)
         REAL, PARAMETER :: DGVEM_AT = 0.03E-6 ! Aitken mode
         REAL, PARAMETER :: DGVEM_AC = 0.3E-6  ! accumulation mode
         REAL, PARAMETER :: DGVEM_CO = 6.0e-6  ! coarse mode

C     Geometric standard deviation of emitted particles in each mode, as
C     described in paragraph #14 of Binkowski & Roselle (2003)
         REAL, PARAMETER :: SGEM_AT = 1.7      ! Aitken mode       
         REAL, PARAMETER :: SGEM_AC = 2.0      ! accumulation mode 
         REAL, PARAMETER :: SGEM_CO = 2.2      ! coarse mode       

C     Variables for converting mass emissions rate to number emissions rate
         REAL, SAVE :: FACTNUMAT               ! Aitken mode
         REAL, SAVE :: FACTNUMAC               ! accumulation mode
         REAL, SAVE :: FACTNUMC                ! Coarse mode

C     Variables for converting mass emissions rate to 2nd moment emissions rate
         REAL, SAVE :: FACTM2AT                ! Aitken mode
         REAL, SAVE :: FACTM2AC                ! acumulation mode

C     Variables for calculating the volume of each grid cell
         REAL, PARAMETER :: REARTH = 6370997.0 ! radius of sphere with same 
                                 ! surface area as Clarke ellipsoid of 1866
                                 ! (Source: Snyder, 1987) [ m ]
         REAL, PARAMETER :: DG2M = REARTH * PI180 ! converts LAT degs to meters
         REAL  DX1, DX2                          ! grid-cell width and length [ m ]
         REAL  GRDAREA                           ! grid area [m2]
         REAL, ALLOCATABLE, SAVE :: GRDHGT( : )  ! grid height [sigma]
         REAL, ALLOCATABLE, SAVE :: GRDVOL( : )  ! grid volume [m2*sigma]

C     Descriptive variables from the emission input file
         CHARACTER( 16 ) :: UNITSCK              ! units of 1st aero species
         CHARACTER( 16 ) :: UNITSAE( NAEMISMAX ) ! units of all aero species
         INTEGER, SAVE :: NAESPCEMIS             ! number of input aero spcs

C     Emission rate of all aerosol species interpolated to current time
         REAL, ALLOCATABLE, SAVE :: EMBUFF( :,:,:,: )  ! in all grid cells
         REAL, ALLOCATABLE, SAVE :: PM_EM( : )         ! in one grid cell
         
C     Factor for converting aerosol emissions from input units ...
         REAL CONVEM_AE_MASS                       ! into [ug/sec]
         REAL, ALLOCATABLE, SAVE :: CONVEM_AE( : ) ! into [ug/m2/sec]
         REAL GSFAC                                ! into [ug/m3/sec]

C     Variables interpolated from the meteorological input files
         REAL PRES( NCOLS,NROWS )              ! atmospheric pressure [ Pa ]
         REAL TA  ( NCOLS,NROWS )              ! air temperature [ K ]
         REAL QV  ( NCOLS,NROWS )              ! H2O mass mixing ratio [ kg/kg ]
         REAL DENS( NCOLS,NROWS,NLAYS )        ! air density [ kg/m3 ]
         REAL WSPD10( NCOLS,NROWS )            ! wind speed at 10m [ m/s ]

C     Variables for converting emission rates into molar-mixing-ratio units
         REAL, PARAMETER :: GPKG = 1.0E+03     ! g/kg
         REAL, PARAMETER :: MGPG = 1.0E+06     ! ug/g
         REAL, PARAMETER :: MWAIR = 28.9628    ! molar mass of dry air [g/mol]
                                               ! assuming 78.06% N2, 21% O2, 
                                               ! and 0.943% Ar 
                                               ! (Source : Hobbs, 1995) pp 69-70
         REAL, PARAMETER :: AVO = 6.0221367E23 ! Avogadro's number [ 1/mol ]
                                               ! (Source: CRC76, pp 1-1 to 1-6)
         REAL, PARAMETER :: RAVO = 1.0 / AVO   ! reciprocal of Avogadro
         REAL  CONVM     ! conversion factor for mass emissions [m3/mol]
         REAL  CONVN     ! conversion factor for number emissions [1e6*m3]
         REAL  CONVS     ! conversion factor for surface area emissions [m3/mol]

C     Domain decomposition info from emission and meteorology files
         INTEGER, SAVE :: STARTCOL, ENDCOL, STARTROW, ENDROW
         INTEGER, SAVE :: STRTCOL_O1, ENDCOL_O1, STRTROW_O1, ENDROW_O1
         INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3

C     Aerosol mass-emission rates [ ug/m3/s ]
         REAL EPOA          ! fine primary organic aerosol
         REAL EPEC          ! fine primary elemental carbon
         REAL EPNO3         ! fine primary nitrate
         REAL EPSO4         ! fine primary sulfate
         REAL EPMF          ! fine primary unspeciated pm
         REAL EPMCO         ! coarse anthropogenic aerosol
         REAL ESOILCO       ! coarse soil-derived aerosol
         REAL ESEASCO       ! coarse marine aerosol

C     Variables for handling vapor-phase sulfuric acid emissions
         REAL EMSULF                          ! emission rate [ ppmv/s ]
         REAL, PARAMETER :: MWH2SO4 = 98.0    ! molar mass [ g/mol ]
         INTEGER, SAVE :: VSULF               ! index to H2SO4 in VDEMIS array

C     Speciation factors for coarse mode emissions, from paragraph #15 of
C     Binkowski & Roselle (2003)
         REAL, PARAMETER :: FAC_DUST = 0.90   ! (fugitive dust)/PMC
         REAL, PARAMETER :: FAC_OTHER = 0.10  ! (non-fugitive dust)/PMC

C     Variables for handling sea-salt emissions
         REAL  OCEAN( NCOLS,NROWS )           ! fractional seawater cover
         REAL  SZONE( NCOLS,NROWS )           ! fractional surf-zone cover
         REAL  SSOUT( NSSDIAG )               ! all emission rates for 
                                              !  diagnostic output file
         REAL  SSOUTM( NSSSPC,NSSMOD )        ! mass emission rates [ug/m3/s]
         REAL  SSOUTN( NSSMOD )               ! number emission rates [1/m3/s]
         REAL  SSOUTS( NSSMOD - 1)            ! surface-area emission rates 
                                              !  [m2/m3/s] (omit coarse mode)

C     Grid-specific values for sea-salt calculations
         REAL  OFRAC                          ! fractional seawater cover
         REAL  SFRAC                          ! fractional surf-zone cover
         REAL  BLKPRS                         ! atmospheric pressure [Pa]
         REAL  BLKTA                          ! air temperature [K]
         REAL  BLKQV                          ! H2O mass mixing ratio [ kg/kg ]
         REAL  BLKDNS                         ! air density [ kg/m3 ]
         REAL  U10                            ! wind speed at 10m [m/s]
         REAL  RLAY1HT                        ! reciprocal of layer-1 hgt [1/m]
         REAL  AIRVOL                         ! grid-cell volume [m3]

C     Factors for splitting primary carbon emissions into Aitken and
C     accumulation modes, from paragraph #12 of Binkowski & Roselle (2003)
         REAL, PARAMETER :: FACEM25_ACC = 0.999  ! accumulation mode
         REAL, PARAMETER :: FACEM25_ATKN = 0.001 ! Aitken mode

C     Mode-specific mass-emission rates [ ug/m3/s ]
         REAL EPM25AT       ! Aitken mode unspeciated aerosol
         REAL EPM25AC       ! accumulation mode unspeciated aerosol
         REAL EPORGAT       ! Aitken mode primary organic aerosol
         REAL EPORGAC       ! accumulation mode primary organic aerosol
         REAL EPECAT        ! Aitken mode elemental carbon
         REAL EPECAC        ! accumulation mode elemental carbon
         REAL EPSO4AT       ! Aitken mode primary sulfate
         REAL EPSO4AC       ! accumulation mode primary sulfate
         REAL EPSO4CO       ! coarse mode primary sulfate
         REAL EPNO3AT       ! Aitken mode primary nitrate
         REAL EPNO3AC       ! accumulation mode primary nitrate
         REAL EPNAAT        ! Aitken mode sodium
         REAL EPNAAC        ! accumulation mode sodium
         REAL EPNACO        ! coarse mode sodium
         REAL EPCLAT        ! Aitken mode chloride
         REAL EPCLAC        ! accumulation mode chloride
         REAL EPCLCO        ! coarse mode chloride
         REAL EPH2OAT       ! Aitken mode primary water
         REAL EPH2OAC       ! accumulation mode primary water
         REAL EPH2OCO       ! coarse mode primary water

C     Factors for converting aerosol mass concentration [ug/m3] to 3rd
C     moment concentration [m3/m3]
         REAL, PARAMETER :: SO4FAC = F6DPIM9 / RHOSO4
         REAL, PARAMETER :: NO3FAC = F6DPIM9 / RHONO3
         REAL, PARAMETER :: ORGFAC = F6DPIM9 / RHOORG
         REAL, PARAMETER :: SOILFAC = F6DPIM9 / RHOSOIL
         REAL, PARAMETER :: SEASFAC = F6DPIM9 / RHOSEAS
         REAL, PARAMETER :: ANTHFAC = F6DPIM9 / RHOANTH

c     Third moment emissions rates [m3/m3/s]
         REAL EMISM3AT      ! Aitken mode
         REAL EMISM3AC      ! accumulation mode
         REAL EMISM3COR     ! coarse mode

C     Number emissions rates [1/m3/s]
         REAL EM_NUMATKN    ! Aitken mode
         REAL EM_NUMACC     ! accumulation mode
         REAL EM_NUMCOR     ! coarse mode

C     Surface area emission rates [m2/m3/s]
         REAL EM_SRFATKN    ! Aitken mode
         REAL EM_SRFACC     ! accumulation mode

C     Variables for writing out sea-salt emission rates
         INTEGER, SAVE :: WSTEP  = 0      ! local write counter
         INTEGER, EXTERNAL :: TIME2SEC    ! fxn not declared in IODECL3.EXT
         INTEGER, EXTERNAL :: SEC2TIME    ! fxn not declared in IODECL3.EXT
         INTEGER MDATE, MTIME             ! internal simulation date&time
         REAL, ALLOCATABLE, SAVE :: SSBF( :,:,: ) ! seasalt emission accumulator
         REAL  WRSS( NCOLS,NROWS )        ! seasalt emission write buffer
         LOGICAL, SAVE :: SSEMDIAG        ! flag for creating SSEMIS output file
         CHARACTER( 16 ), SAVE :: CTM_SSEMDIAG = 'CTM_SSEMDIAG'
                                          ! environment var for SSEMDIAG file
         LOGICAL, EXTERNAL :: ENVYN       ! get environment variable as boolean
         CHARACTER( 80 ) :: VARDESC       ! environment variable description
         INTEGER  STATUS                  ! ENV... status

C     Miscellaneous variables
         LOGICAL, SAVE :: FIRSTIME = .TRUE.
         INTEGER, SAVE :: LOGDEV
         INTEGER, SAVE :: INDX10        ! flag when PMC is calc'd from PM10
         INTEGER, EXTERNAL :: INDEX1, TRIMLEN, SETUP_LOGDEV
         INTEGER INDX
         INTEGER ALLOCSTAT
         CHARACTER( 96 ) :: XMSG = ' '
         CHARACTER( 16 ), SAVE :: PNAME = 'RDEMIS_AE'
         CHARACTER( 16 ) :: VNAME       ! temp var for species names
         INTEGER  GXOFF, GYOFF          ! origin offset
         INTEGER C,R,L,N,V              ! Loop indices

C ----------------------------------------------------------------------

         IF ( FIRSTIME ) THEN
            FIRSTIME = .FALSE.
!           LOGDEV = INIT3()
            LOGDEV = SETUP_LOGDEV()
            INDX10 = 0

            IF ( INDEX ( MECHNAME, 'AE3' ) .GT. 0 ) THEN
               AE_VRSN  = 'AE3'
            ELSE IF ( INDEX ( MECHNAME, 'AE4' ) .GT. 0 ) THEN
               AE_VRSN  = 'AE4'
            ELSE
               XMSG = 'This version of the emission processing code '
     &             // 'can only be used with the AE3 and AE4 aerosol '
     &             // 'mechanisms.'
                     CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF ! check on MECHNAME

C *** Set indices for the VDEMIS_AE array using the AE_EMIS table

            VNAME = 'ASO4J'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VSO4AJ = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ASO4I'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VSO4AI = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ANO3J'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VNO3AJ = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ANO3I'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VNO3AI = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'AORGPAJ'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VORGPAJ = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'AORGPAI'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VORGPAI = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'AECJ'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VECJ = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'AECI'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VECI = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'A25J'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VP25AJ = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'A25I'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VP25AI = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ACORS'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VANTHA = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            IF ( AE_VRSN .EQ. 'AE3' ) THEN
               VNAME = 'ASEAS'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VSEAS = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF
            END IF

            VNAME = 'ASOIL'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VSOILA = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'NUMATKN'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VAT0 = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'NUMACC'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VAC0 = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'NUMCOR'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VCOR0 = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'SRFATKN'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VSURFAT = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'SRFACC'
            N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
            IF ( N .NE. 0 ) THEN
               VSURFAC = N
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            IF ( AE_VRSN .EQ. 'AE4' ) THEN
               VNAME = 'AH2OJ'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VH2OAJ = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'AH2OI'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VH2OAI = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ANAJ'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VNAJ = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ANAI'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VNAI = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ACLJ'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VCLJ = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ACLI'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VCLI = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ANAK'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VNAK = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ACLK'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VCLK = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'ASO4K'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VSO4K = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF

               VNAME = 'AH2OK'
               N = INDEX1( VNAME, N_AE_EMIS, AE_EMIS )
               IF ( N .NE. 0 ) THEN
                  VH2OK = N
               ELSE
                  XMSG = 'Could not find ' // VNAME // 'in AE_EMIS table'
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
               END IF
            END IF


C *** Save array of MWs
            DO V = 1, N_AE_EMIS
               AE_EM_MW( V ) = AE_MOLWT( AE_EMIS_MAP(V) )
            END DO

C *** Calculate factors for converting 3rd moment emission rates into number
C     emission rates.  See Equation 7b of Binkowski & Roselle (2003)

            FACTNUMAT = EXP( 4.5 * LOG( SGEM_AT ) ** 2 ) / DGVEM_AT ** 3
            FACTNUMAC = EXP( 4.5 * LOG( SGEM_AC ) ** 2 ) / DGVEM_AC ** 3
            FACTNUMC  = EXP( 4.5 * LOG( SGEM_CO ) ** 2 ) / DGVEM_CO ** 3

C *** Calculate factors for converting 3rd moment emission rates into 2nd 
C     moment emission rates.  See Equation 7c of Binkowski & Roselle (2003)

            FACTM2AT  = EXP( 0.5 * LOG( SGEM_AT ) ** 2 ) / DGVEM_AT
            FACTM2AC  = EXP( 0.5 * LOG( SGEM_AC ) ** 2 ) / DGVEM_AC

C *** Open the gridded emissions file, which contains gas, aerosol, 
C     and non-reactive species

            IF ( .NOT. OPEN3( EMIS_1, FSREAD3, PNAME ) ) THEN
               XMSG = 'Could not open '// EMIS_1 // ' file'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

            IF ( .NOT. DESC3( EMIS_1 ) ) THEN
               XMSG = 'Could not get '// EMIS_1 // ' file description'
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
            END IF

C *** Search emission file for certain species names.  For each species found, 
C     1. Assign a value to the index variables in the PM_EM array 
C        (e.g., VPOA, VPSO4, etc.)
C     2. Populate the AEMIS array with the emitted species names
C        note: species names are hardcoded in the present version
C     3. Populate the UNITSAE array based on the units in which the 
C        emissions data are input (e.g., 'G/S', 'KG/H')
C
C     If a species is not found, print error message and halt.

            VNAME ='POA' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .NE. 0 ) THEN
               V = 1
               VPOA = V
               AEMIS( V ) = VNAME
               UNITSCK = UNITS3D( INDX )
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find '
     &              // VNAME( 1:TRIMLEN( VNAME ) )
     &              // ' in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME ='PSO4' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .NE. 0 ) THEN
               V = V + 1
               VPSO4 = V
               AEMIS( V ) = VNAME
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find '
     &              // VNAME( 1:TRIMLEN( VNAME ) )
     &              // ' in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'PNO3' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .NE. 0 ) THEN
               V = V + 1
               VPNO3 = V
               AEMIS( V ) = VNAME
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find '
     &              // VNAME( 1:TRIMLEN( VNAME ) )
     &              // ' in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'PEC' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .NE. 0 ) THEN
               V = V + 1
               VPEC = V
               AEMIS( V ) = VNAME
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find '
     &              // VNAME( 1:TRIMLEN( VNAME ) )
     &              // ' in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'PMFINE' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .NE. 0 ) THEN
               V = V + 1
               VPMF = V
               AEMIS( V ) = VNAME
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find '
     &              // VNAME( 1:TRIMLEN( VNAME ) )
     &              // ' in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF
 
C *** Compatibility with emission files that do not list 'PMC' explicitly:
C      1. If 'PMC' variable exists, use those data for coarse PM emissions.
C      2. Otherwise, look for the 'PM10' variable.  If found, assign INDX10
C         a non-zero value to flag the fact that PM10 was read instead of PMC.
C      3. If 'PM10' is not found either, print error message and halt.

            VNAME = 'PMC' 
            INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
            IF ( INDX .EQ. 0 ) THEN   ! try another
               XMSG = 'Could not find PMC in aerosol table.'
     &             // '  Using PM10 - sum(PM2.5) instead.'
               CALL M3WARN ( PNAME, JDATE, JTIME, XMSG )
               VNAME = 'PM10' 
               INDX = INDEX1( VNAME, NVARS3D, VNAME3D )
               INDX10 = INDX
            END IF
            
            IF ( INDX .NE. 0 ) THEN
               V = V + 1
               VPMC = V
               AEMIS( V ) = VNAME
               UNITSAE( V ) = UNITS3D( INDX )
            ELSE
               XMSG = 'Could not find PMC nor PM10 in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

C *** Save the number of aerosol species read from the emission file and
C     write their names to the log file

            NAESPCEMIS = V
            WRITE( LOGDEV, '( /5X, A )' ) 'PM species in emission file:'
            DO V = 1, NAESPCEMIS
               WRITE( LOGDEV, '( /5X, A )' ) AEMIS( V )
            END DO

C *** If AE4 mechanism is being used, set up for sea-salt emission processing

            IF ( AE_VRSN .EQ. 'AE4' ) THEN

c *** Open the ocean file, which contains the ocean and surf-zone fractions

               IF ( .NOT. OPEN3( OCEAN_1, FSREAD3, PNAME ) ) THEN
                  XMSG = 'Could not open '// OCEAN_1 // ' file'
                  CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
               END IF
               
               IF ( .NOT. DESC3( OCEAN_1 ) ) THEN
                  XMSG = 'Could not get '// OCEAN_1 // ' file description'
                  CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
               END IF

C *** Get sea-salt-emission diagnostic file flag.

               SSEMDIAG = .FALSE.         ! default
               VARDESC = 'Flag for writing the sea-salt-emission diagnostic file'
               SSEMDIAG = ENVYN( CTM_SSEMDIAG, VARDESC, SSEMDIAG, STATUS )
               IF ( STATUS .NE. 0 ) WRITE( LOGDEV, '(5X, A)' ) VARDESC
               IF ( STATUS .EQ. 1 ) THEN
                  XMSG = 'Environment variable improperly formatted'
                  CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
               ELSE IF ( STATUS .EQ. -1 ) THEN
                  XMSG =
     &                'Environment variable set, but empty ... Using default:'
                  WRITE( LOGDEV, '(5X, A, I9)' ) XMSG, JTIME
               ELSE IF ( STATUS .EQ. -2 ) THEN
                  XMSG = 'Environment variable not set ... Using default:'
                  WRITE( LOGDEV, '(5X, A, I9)' ) XMSG, JTIME
               END IF
               
            END IF  ! check on AE_VRSN

C *** Allocate memory for PM_EM, EMBUFF, GRDHGT, GRDVOL, CONVEM_AE, and SSBF

            ALLOCATE ( PM_EM( NAESPCEMIS ), STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** PM_EM memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            ALLOCATE ( EMBUFF( MY_NCOLS,MY_NROWS,EMISLYRS,NAESPCEMIS ),
     &                 STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** EMBUFF memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

            ALLOCATE ( CONVEM_AE( EMISLYRS ), STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** CONVEM_AE memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            ALLOCATE ( GRDHGT( EMISLYRS ), STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** GRDHGT memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            ALLOCATE ( GRDVOL( EMISLYRS ), STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** GRDVOL memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            ALLOCATE ( SSBF( NSSDIAG,MY_NCOLS,MY_NROWS ), STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = '*** SSBF memory allocation failed'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

C *** Calculate length and width of each grid cell
C     note: crude estimate is made for LAT/LONG coordinate systems

            IF ( GDTYP_GD .EQ. LATGRD3 ) THEN
               DX1 = DG2M * XCELL_GD ! in m
               DX2 = DG2M * YCELL_GD
     &             * COS( PI180*( YORIG_GD + YCELL_GD
     &             * FLOAT( GL_NROWS/2 ) ) ) ! in m
            ELSE
               DX1 = XCELL_GD        ! in m
               DX2 = YCELL_GD        ! in m
            END IF

C *** Calculate height of grid cell in each layer in sigma coordinates
C     Multiply by grid area [m2] to obtain grid volume

            GRDAREA = DX1 * DX2
            DO L = 1, EMISLYRS
               GRDHGT( L ) = X3FACE_GD( L ) - X3FACE_GD( L-1 )
               GRDVOL( L ) = GRDHGT( L ) * GRDAREA
            END DO

C *** Confirm that all aerosol species in the emission input file have 
C     the same units.  If not, print error message and halt.

            DO V = 1, NAESPCEMIS
               IF ( UNITSAE( V ) .NE. UNITSCK ) THEN
                     XMSG = 'PM Units not uniform on ' // EMIS_1
                     CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
               END IF
            END DO

C *** Calculate scaling factor for converting aerosol emissions from
C     their input units to [ug/s] and then to [ug/m2/s] using layer-
C     specific grid-cell volume

            IF ( UNITSCK .EQ. 'G/S' .OR.
     &           UNITSCK .EQ. 'g/s' ) THEN
               CONVEM_AE_MASS = MGPG                  ! (g/s) -> (ug/s)
            ELSE IF ( UNITSCK .EQ. 'KG/HR' .OR.
     &                UNITSCK .EQ. 'kg/hr' ) THEN
               CONVEM_AE_MASS = GPKG * MGPG / 3600.0  ! (kg/hr) -> (ug/s)
            ELSE
               XMSG = 'Units incorrect on ' // EMIS_1
               CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
            END IF

            DO L = 1, EMISLYRS
               CONVEM_AE( L ) = CONVEM_AE_MASS / GRDVOL( L )
            END DO

C *** Find location of sulfuric acid vapor in VDEMIS array

            VNAME = 'SULF'
            INDX = INDEX1 ( VNAME, N_GC_EMIS, GC_EMIS )
            IF ( INDX .NE. 0 ) THEN
               VSULF = INDX  ! index for vapor-phase H2SO4 emissions
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in gas table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

C *** Get domain decomposition info from input files

            CALL SUBHFILE ( EMIS_1, GXOFF, GYOFF,
     &                      STARTCOL, ENDCOL, STARTROW, ENDROW )

            IF ( AE_VRSN .EQ. 'AE4' ) THEN
               CALL SUBHFILE ( OCEAN_1, GXOFF, GYOFF,
     &                         STRTCOL_O1, ENDCOL_O1, STRTROW_O1, ENDROW_O1 )
            END IF  ! check on AE_VRSN

            CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                      STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

         END IF    ! FIRSTIME

C ----------------------------------------------------------------------

C *** Read aerosol emission rates from file and interpolate to the current
C     time.  Store result in EMBUFF array.

         DO N = 1, NAESPCEMIS
            IF ( .NOT. INTERPX( EMIS_1, AEMIS( N ), PNAME,
     &                          STARTCOL,ENDCOL, STARTROW,ENDROW, 1,EMISLYRS,
     &                          JDATE, JTIME, EMBUFF( 1,1,1,N ) ) ) THEN
               XMSG = 'Could not read '
     &              // AEMIS( N )( 1:TRIMLEN( AEMIS( N ) ) )
     &              // ' from ' // EMIS_1
               CALL M3WARN ( PNAME, JDATE, JTIME, XMSG  )
            END IF
         END DO

C *** Read air density [ kg/m3 ], atmospheric pressure [ Pa ], air temperature 
C     [ K ], specific humidity [ kg H2O / kg air ], and 10m wind speed [ m/s ] 
C     from meteorology file.  Interpolate to the current time.  Store results 
C     in DENS, PRES, TA, QV, and WSPD10 arrays.

         IF ( .NOT. INTERPX( MET_CRO_3D, 'DENS', PNAME,
     &                       STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                       1,NLAYS, JDATE, JTIME, DENS ) ) THEN
            XMSG = 'Could not interpolate DENS from ' // MET_CRO_3D
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

         IF ( AE_VRSN .EQ. 'AE4' ) THEN
            IF ( .NOT. INTERPX( MET_CRO_3D, 'PRES', PNAME,
     &                          STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                          1,1, JDATE, JTIME, PRES ) ) THEN
               XMSG = 'Could not interpolate PRES from ' // MET_CRO_3D
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            IF ( .NOT. INTERPX( MET_CRO_3D, 'TA', PNAME,
     &                          STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                          1,1, JDATE, JTIME, TA ) ) THEN
               XMSG = 'Could not interpolate TA from ' // MET_CRO_3D
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            IF ( .NOT. INTERPX( MET_CRO_3D, 'QV', PNAME,
     &                          STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                          1,1, JDATE, JTIME, QV ) ) THEN
               XMSG = 'Could not interpolate QV from ' // MET_CRO_3D
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

            IF ( .NOT. INTERPX( MET_CRO_2D, 'WSPD10', PNAME,
     &                          STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                          1, 1, JDATE, JTIME, WSPD10 ) ) THEN
               XMSG = 'Could not find WSPD10 in ' // MET_CRO_2D //
     &                ' search for WIND10.'
               CALL M3WARN ( PNAME, JDATE, JTIME, XMSG )
               IF ( .NOT. INTERPX( MET_CRO_2D, 'WIND10', PNAME,
     &                             STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
     &                             1, 1, JDATE, JTIME, WSPD10 ) ) THEN
                  XMSG = 'Could not find WIND10 or WSPD10 in ' // MET_CRO_2D
                  CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
               END IF
            END IF

C *** Read fractional seawater and surf-zone coverage from the OCEAN file.
C     Store results in the OCEAN and SZONE arrays.

            IF ( .NOT. INTERPX( OCEAN_1, 'OPEN', PNAME,
     &                          STRTCOL_O1,ENDCOL_O1, STRTROW_O1,ENDROW_O1,
     &                          1, 1, JDATE, JTIME, OCEAN ) ) THEN
               XMSG = 'Could not interpolate OPEN from ' // OCEAN_1
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF
            
            IF ( .NOT. INTERPX( OCEAN_1, 'SURF', PNAME,
     &                          STRTCOL_O1,ENDCOL_O1, STRTROW_O1,ENDROW_O1,
     &                          1, 1, JDATE, JTIME, SZONE ) ) THEN
               XMSG = 'Could not interpolate SURF from ' // OCEAN_1 //
     &                '.  Surf-zone emissions set to zero.'
               CALL M3WARN ( PNAME, JDATE, JTIME, XMSG )
            END IF
         END IF  ! check on AE_VRSN

C *** Initialize sea-salt output buffer

         IF ( WSTEP .EQ. 0 ) SSBF = 0.0

C *** LOOP OVER EACH GRID CELL

         DO L = 1, EMISLYRS
            DO R = 1, MY_NROWS
               DO C = 1, MY_NCOLS

C *** Store aerosol emission rates for this grid cell in a 1D array

                  DO N = 1, NAESPCEMIS
                     PM_EM( N ) = EMBUFF( C,R,L,N )
                  END DO

C *** Calculate scaling factor for converting mass emissions into [ ug/m3/s ]
C     note: RJACM converts grid heights from sigma coordinates to meters
C     Also calculate scaling factors for converting to molar-mixing-ratio units

                  GSFAC = CONVEM_AE( L ) * RJACM( C,R,L )
                  CONVM = MWAIR / GPKG / DENS( C,R,L )  !  [m3/mol]
                  CONVN = CONVM * RAVO * 1.0E+06        !  10^6 * [m3]
                  CONVS = CONVM                         !  [m3/mol]

C *** Calculate speciated mass emission rates for fine aerosol [ ug/m3/s ]

                  EPOA  = PM_EM( VPOA  ) * GSFAC
                  EPSO4 = PM_EM( VPSO4 ) * GSFAC
                  EPNO3 = PM_EM( VPNO3 ) * GSFAC
                  EPMF  = PM_EM( VPMF  ) * GSFAC
                  EPEC  = PM_EM( VPEC  ) * GSFAC

C *** If INDX10 is non-zero, the emission file did not contain PMC so 
C     PM_EM(VPMC) holds PM10 emissions.  Substract the PM2.5 species
C     from this so PM_EM(VPMC) holds only the coarse emission rate.

                  IF ( INDX10 .NE. 0 ) THEN
                     PM_EM( VPMC ) = MAX( 0.0, PM_EM( VPMC ) - 
     &                 ( PM_EM(VPOA) + PM_EM(VPEC) + PM_EM(VPSO4) +
     &                   PM_EM(VPNO3) + PM_EM(VPMF) ) )
                  END IF
                  
C *** Assign coarse PM emissions (excluding sea salt) to the coarse mode.
C     Split coarse material between SOIL and UNSPECIATED material, as
C     described in paragraph #15 of Binkowski & Roselle (2003).

                  ESOILCO = FAC_DUST  * PM_EM( VPMC ) * GSFAC
                  EPMCO   = FAC_OTHER * PM_EM( VPMC ) * GSFAC 
                  ESEASCO = 0.0

C *** Extract H2SO4 vapor emission rate from the VDEMIS array, add it to
C     the fine-PM sulfate emissions, and remove it from the gas emissions
                      
                  EMSULF = VDEMIS( VSULF,L,C,R )
                  EPSO4 = EPSO4 + EMSULF * MWH2SO4 / CONVM
                  VDEMIS( VSULF,L,C,R ) = 0.0

C *** Assign fine-particle emission rates to the fine modes.
C     Assume all non-seasalt-emissions of sulfate, nitrate, and unspeciated
C     fine PM are in the accumulation mode.  Split the carbon emissions 
C     between the Aitken and accumulation modes, as described in paragraph 
C     #12 of Binkowski & Roselle (2003).

                  EPM25AT = 0.0
                  EPM25AC = EPMF
                  EPSO4AT = 0.0
                  EPSO4AC = EPSO4  
                  EPNO3AT = 0.0
                  EPNO3AC = EPNO3
                  EPORGAT = FACEM25_ATKN * EPOA
                  EPORGAC = FACEM25_ACC  * EPOA
                  EPECAT  = FACEM25_ATKN * EPEC
                  EPECAC  = FACEM25_ACC  * EPEC

C *** Calculate emissions rate for third moments [m3/m3/s] of each mode 
C     (excluding sea salt), as in Equation 7a of Binkowski & Roselle (2003).

                  EMISM3AT =  ANTHFAC * ( EPM25AT + EPECAT )
     &                     +  ORGFAC  * EPORGAT
     &                     +  SO4FAC  * EPSO4AT
     &                     +  NO3FAC  * EPNO3AT
                  EMISM3AC =  ANTHFAC * ( EPM25AC + EPECAC )
     &                     +  ORGFAC  * EPORGAC
     &                     +  SO4FAC  * EPSO4AC
     &                     +  NO3FAC  * EPNO3AC
                  EMISM3COR = SOILFAC * ESOILCO
     &                      + SEASFAC * ESEASCO
     &                      + ANTHFAC * EPMCO

C *** Calculate the number emissions rate for each mode [1/m3/s], using 
C     Equation 7b of Binkowski & Roselle (2003).

                  EM_NUMATKN = FACTNUMAT * EMISM3AT
                  EM_NUMACC  = FACTNUMAC * EMISM3AC
                  EM_NUMCOR  = FACTNUMC  * EMISM3COR

C *** Calculate the surface area emissions rate for the fine modes [m2/m3/s],
C     using Equation 7c of Binkowski & Roselle (2003).  Multiplying by PI 
C     converts 2nd moment to surface area.

                  EM_SRFATKN = PI * FACTM2AT * EMISM3AT
                  EM_SRFACC  = PI * FACTM2AC * EMISM3AC


C *** Calculate sea-salt emission rates in the lowest layer.  The SSEMIS 
C     subroutine returns modal emission rates for sea-salt mass [g/m3/s], 
C     number [1/m3/s], and surface area [m2/m3/s].  The mass array is 
C     chemically speciated.

                 IF ( AE_VRSN .EQ. 'AE4' ) THEN

                  IF ( L .EQ. 1 .AND. OCEAN(C,R)+SZONE(C,R) .GT. 0.0 ) THEN
                     OFRAC   = OCEAN ( C,R )
                     SFRAC   = SZONE ( C,R )
                     BLKPRS  = PRES  ( C,R )
                     BLKTA   = TA    ( C,R )
                     BLKQV   = QV    ( C,R )
                     BLKDNS  = DENS  ( C,R,L )
                     U10     = WSPD10( C,R )
                     RLAY1HT = RJACM( C,R,L ) / GRDHGT( L )
                     CALL SSEMIS( OFRAC, SFRAC, BLKPRS, BLKTA, BLKQV, U10, 
     &                            RLAY1HT, SSOUTM, SSOUTN, SSOUTS )
                  ELSE
                     DO V = 1, NSSMOD
                        DO N = 1, NSSSPC
                           SSOUTM(N,V) = 0.0
                        END DO
                        SSOUTN(V) = 0.0
                     END DO
                     DO V = 1, NSSMOD - 1
                        SSOUTS(V) = 0.0
                     END DO
                  END IF

C *** Convert units of SSOUTM from [g/m3/s] to [ug/m3/s].  Transfer result
C     to mode- and species-specific variables.  Sea-salt sulfate in the fine 
C     modes must be added to the anthropogenic sulfate emissions.  Remaining
C     sea-salt species are not in the standard inventory.

                  EPNAAT  = SSOUTM(KNA,1)  * MGPG
                  EPNAAC  = SSOUTM(KNA,2)  * MGPG
                  EPNACO  = SSOUTM(KNA,3)  * MGPG
                  EPCLAT  = SSOUTM(KCL,1)  * MGPG
                  EPCLAC  = SSOUTM(KCL,2)  * MGPG
                  EPCLCO  = SSOUTM(KCL,3)  * MGPG
                  EPSO4AT = SSOUTM(KSO4,1) * MGPG + EPSO4AT
                  EPSO4AC = SSOUTM(KSO4,2) * MGPG + EPSO4AC
                  EPSO4CO = SSOUTM(KSO4,3) * MGPG
                  EPH2OAT = SSOUTM(KH2O,1) * MGPG
                  EPH2OAC = SSOUTM(KH2O,2) * MGPG
                  EPH2OCO = SSOUTM(KH2O,3) * MGPG

C *** Add sea salt to the total emissions of particle number and surface area

                  EM_NUMATKN = EM_NUMATKN + SSOUTN(1)
                  EM_NUMACC  = EM_NUMACC  + SSOUTN(2)
                  EM_NUMCOR  = EM_NUMCOR  + SSOUTN(3)
                  EM_SRFATKN = EM_SRFATKN + SSOUTS(1)
                  EM_SRFACC  = EM_SRFACC  + SSOUTS(2)
                  
                 END IF  ! check on AE_VRSN

C *** Convert emission rates into molar-mixing-ratio units, as required by
C     the vertical diffusion routines.  Mass and number emissions are 
C     converted to [ppmv/s].  Surface area emissions are converted to 
C     [m2/mol/s].  Save results in the VDEMIS_AE array.

                  VDEMIS_AE( VSO4AI, L,C,R ) = EPSO4AT * CONVM
     &                                       / AE_EM_MW( VSO4AI )
                  VDEMIS_AE( VSO4AJ, L,C,R ) = EPSO4AC * CONVM
     &                                       / AE_EM_MW( VSO4AJ )
                  VDEMIS_AE( VNO3AI, L,C,R ) = EPNO3AT * CONVM
     &                                       / AE_EM_MW( VNO3AI )
                  VDEMIS_AE( VNO3AJ, L,C,R ) = EPNO3AC * CONVM
     &                                       / AE_EM_MW( VNO3AJ )
                  VDEMIS_AE( VORGPAI,L,C,R ) = EPORGAT * CONVM
     &                                       / AE_EM_MW( VORGPAI )
                  VDEMIS_AE( VORGPAJ,L,C,R ) = EPORGAC * CONVM
     &                                       / AE_EM_MW( VORGPAJ )
                  VDEMIS_AE( VECI,   L,C,R ) = EPECAT * CONVM
     &                                       / AE_EM_MW( VECI )
                  VDEMIS_AE( VECJ,   L,C,R ) = EPECAC * CONVM
     &                                       / AE_EM_MW( VECJ )
                  VDEMIS_AE( VP25AI, L,C,R ) = EPM25AT * CONVM    
     &                                       / AE_EM_MW( VP25AI )
                  VDEMIS_AE( VP25AJ, L,C,R ) = EPM25AC * CONVM
     &                                       / AE_EM_MW( VP25AJ )
                  VDEMIS_AE( VANTHA, L,C,R ) = EPMCO * CONVM
     &                                       / AE_EM_MW( VANTHA )
                  VDEMIS_AE( VSOILA, L,C,R ) = ESOILCO * CONVM
     &                                       / AE_EM_MW( VSOILA )
                  VDEMIS_AE( VAT0,   L,C,R ) = EM_NUMATKN * CONVN
                  VDEMIS_AE( VAC0,   L,C,R ) = EM_NUMACC  * CONVN
                  VDEMIS_AE( VCOR0,  L,C,R ) = EM_NUMCOR  * CONVN
                  VDEMIS_AE( VSURFAT,L,C,R ) = EM_SRFATKN * CONVS
                  VDEMIS_AE( VSURFAC,L,C,R ) = EM_SRFACC  * CONVS

                  IF ( AE_VRSN .EQ. 'AE3' ) THEN
                     VDEMIS_AE( VSEAS,  L,C,R ) = ESEASCO * CONVM
     &                                          / AE_EM_MW( VSEAS )
                  ELSE IF ( AE_VRSN .EQ. 'AE4' ) THEN
                     VDEMIS_AE( VH2OAI, L,C,R ) = EPH2OAT * CONVM
     &                                          / AE_EM_MW( VH2OAI )
                     VDEMIS_AE( VH2OAJ, L,C,R ) = EPH2OAC * CONVM 
     &                                          / AE_EM_MW( VH2OAJ )
                     VDEMIS_AE( VNAI,   L,C,R ) = EPNAAT  * CONVM 
     &                                          / AE_EM_MW( VNAI )
                     VDEMIS_AE( VNAJ,   L,C,R ) = EPNAAC  * CONVM 
     &                                          / AE_EM_MW( VNAJ )
                     VDEMIS_AE( VCLI,   L,C,R ) = EPCLAT  * CONVM 
     &                                          / AE_EM_MW( VCLI )
                     VDEMIS_AE( VCLJ,   L,C,R ) = EPCLAC  * CONVM 
     &                                          / AE_EM_MW( VCLJ )
                     VDEMIS_AE( VNAK,   L,C,R ) = EPNACO  * CONVM 
     &                                          / AE_EM_MW( VNAK )
                     VDEMIS_AE( VCLK,   L,C,R ) = EPCLCO  * CONVM 
     &                                          / AE_EM_MW( VCLK )
                     VDEMIS_AE( VSO4K,  L,C,R ) = EPSO4CO * CONVM 
     &                                          / AE_EM_MW( VSO4K )
                     VDEMIS_AE( VH2OK,  L,C,R ) = EPH2OCO * CONVM 
     &                                          / AE_EM_MW( VH2OK )
                  END IF  ! check on AE_VRSN

C *** Update the SSBF array, for writing the diagnostic sea-salt-emission file.

                  IF ( AE_VRSN .EQ. 'AE4' ) THEN
                     IF ( L .EQ. 1 ) THEN
                        AIRVOL    = GRDVOL(L) / RJACM( C,R,L )
                        SSOUT(1)  = SSOUTM(KNA, 2)
                        SSOUT(2)  = SSOUTM(KCL, 2)
                        SSOUT(3)  = SSOUTM(KSO4,2)
                        SSOUT(4)  = SSOUTM(KH2O,2)
                        SSOUT(5)  = SSOUTM(KNA, 3)
                        SSOUT(6)  = SSOUTM(KCL, 3)
                        SSOUT(7)  = SSOUTM(KSO4,3)
                        SSOUT(8)  = SSOUTM(KH2O,3)
                        SSOUT(9)  = SSOUTN(2)
                        SSOUT(10) = SSOUTN(3)
                        SSOUT(11) = SSOUTS(2)
                        DO V = 1, NSSDIAG
                           SSBF( V,C,R ) = SSBF( V,C,R ) + SSOUT( V ) * AIRVOL
     &                                   * FLOAT( TIME2SEC ( TSTEP( 2 ) ) )
                        END DO
                     END IF
                  END IF  ! check on AE_VRSN
                  
               END DO   ! loop on MY_NCOLS
            END DO   ! loop on MY_NROWS
         END DO   ! loop on EMISLYRS

C *** If last call this hour, write out the total sea-salt emissions [g/s].
C     Then reset the sea-salt emissions array and local write counter.

         IF ( AE_VRSN .EQ. 'AE4' ) THEN
            WSTEP = WSTEP + TIME2SEC( TSTEP( 2 ) )
            IF ( SSEMDIAG ) THEN
            
               IF ( WSTEP .GE. TIME2SEC( TSTEP( 1 ) ) ) THEN
!                 MDATE = JDATE
!                 MTIME = JTIME
!                 CALL NEXTIME( MDATE, MTIME, 
!    &                          SEC2TIME( TIME2SEC( TSTEP( 2 ) + 1 ) / 2 ) )

!                 DO V = 1, NSSDIAG
!                    DO R = 1, MY_NROWS
!                       DO C = 1, MY_NCOLS
!                          WRSS( C,R ) = SSBF( V,C,R ) / FLOAT( WSTEP )
!                       END DO
!                    END DO
               
!                    IF ( .NOT. WRITE3( CTM_SSEMIS_1, WRSS_SPC( V ),
!    &                          MDATE, MTIME, WRSS ) ) THEN
!                       XMSG = 'Could not write ' // CTM_SSEMIS_1 // ' file'
!                       CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
!                    END IF
               
!                 END DO
               
!                 WRITE( LOGDEV, '( /5X, 3( A, :, 1X ), I8, ":", I6.6 )' )
!    &                  'Timestep written to', CTM_SSEMIS_1,
!    &                  'for date and time', MDATE, MTIME
               
                  WSTEP = 0
                  SSBF = 0.0
               
               END IF
            
            END IF         
         END IF  ! check on AE_VRSN

         RETURN
         
         END SUBROUTINE RDEMIS_AE

      END MODULE AERO_EMIS
      
