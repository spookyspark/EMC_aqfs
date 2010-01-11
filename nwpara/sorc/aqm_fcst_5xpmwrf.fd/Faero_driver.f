
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

C RCS file, release, date & time of last delta, author, state, [locker]
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/aero/aero3/aero_driver.F,v 1.1.1.1 2005/09/09 18:56:04 sjr Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C @(#)aero_driver.F     1.5 /project/mod3/CMAQ/src/aero/aero/SCCS/s.aero_driver.F 25 Jul 1997 08:50:55

C >>> 08/04/2000 Changes necessary to be able to read and process
C two different types of emissions files.
C the first type is the existing opperational PM2.5 & PM10 unspeciated
C file. The new file format has speciated emissions. 
C >>> This version uses the FORTRAN 90 feature for runtime memory
C allocation.

C 1/12/99 David Wong at LM: 
C   -- introduce new variable MY_NUMBLKS (eliminate NUMBLKS)
C   -- re-calculate NOXYZ accordingly
C FSB Updated for inclusion of surface area / second moment
C 25 Sep 00 (yoj) various bug fixes, cleanup to coding standards
C   Jeff - Dec 00 - move CGRID_MAP into f90 module
C FSB/Jeff - May 01 - optional emissions processing
C   Jerry Gipson - Jun 01 - added SOA linkages for saprc99
C   Bill Hutzell - Jun 01 - simplified CBLK mapping
C   Jerry Gipson - Jun 03 - modified for new soa treatment
C   Jerry Gipson - Aug 03 - removed SOA prod form alkenes & added 
C       emission adjustment factors for ALK & TOL ( RADM2 & SAPRC99 only)
C   Shawn Roselle - Jan 04
C   - removed SOA from transported aerosol surface area
C   - fixed bug in calculation of wet parameters.  Previously, DRY aerosol
C      parameters were being written to the AER_DIAG files and mislabeled
C      as WET.
C   Prakash Bhave - May 04
C   - changed AERODIAG species (added RH; removed M0 & M2dry)
C   J.Young 31 Jan 05: dyn alloc - establish both horizontal & vertical
C                      domain specifications in one module
C   Prakash Bhave - Jul 05 - added PM25 mass-fraction calculations
C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE AERO ( JDATE, JTIME, TSTEP )

      USE CGRID_DEFN          ! inherits GRID_CONF and CGRID_SPCS
      USE VIS_DEFN
      USE AERO_INFO_AE3       ! replaces aero include files

      IMPLICIT NONE
 
C *** includes:
 
!     INCLUDE SUBST_HGRD_ID   ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID   ! vertical dimensioning parameters
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_SPC.EXT"    ! gas chemistry species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_EMIS.EXT"   ! gas chem emis surrogate names and map
                              ! table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"    ! aerosol species table
!     INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_EMIS.EXT"   ! aerosol emis surrogate names and map
                              ! table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_SPC.EXT"    ! non-reactive species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_G2AE.EXT"   ! gas chem aerosol species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_N2AE.EXT"   ! non-react aerosol species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/RXCM.EXT"    ! to get mech name
!     INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"     ! constants
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"   ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/FDESC3.EXT"   ! file header data structure

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

      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/FILES_CTM.EXT"  ! file name parameters
!     INCLUDE SUBST_BLKPRM    ! sets BLKSIZE AND MXBLKS
!     INCLUDE SUBST_COORD_ID  ! coord. and domain definitions 
                              ! (req IOPARMS)
!     INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/PA_CTL.EXT"  ! process analysis

C *** arguments:

      INTEGER      JDATE        ! Current model date , coded YYYYDDD
      INTEGER      JTIME        ! Current model time , coded HHMMSS
      INTEGER      TSTEP( 2 )   ! time step vector (HHMMSS)
                                ! TSTEP(1) = local output step
                                ! TSTEP(2) = sciproc sync. step (chem)

      REAL, PARAMETER :: CONMIN = 1.0E-30 ! concentration lower limit

      INTEGER, SAVE :: LOGDEV             ! unit number for the log file

C *** local variables:

      CHARACTER( 16 ), SAVE :: PNAME = 'AERO_DRIVER'
      CHARACTER( 16 ) :: VNAME            ! variable name
      CHARACTER( 96 ) :: XMSG = ' '

      INTEGER   MDATE, MTIME, MSTEP  ! julian date, time and 
                                     ! timestep in sec
      INTEGER   C, R, L, V, N        ! loop counters
      INTEGER   SPC                  ! species loop counter
      INTEGER   STRT, FINI           ! loop induction variables
      INTEGER   ALLOCSTAT            ! memory allocation status
      INTEGER   LAYER                ! model layer

      LOGICAL   LERROR               ! Error flag

C *** External Functions not previously declared in IODECL3.EXT:

      INTEGER, EXTERNAL :: SECSDIFF, SEC2TIME, TIME2SEC, INDEX1
      LOGICAL, EXTERNAL :: ENVYN     ! get environment variable as boolean
      INTEGER, EXTERNAL :: SETUP_LOGDEV

C *** Grid description

      REAL DX1                      ! Cell x-dimension
      REAL DX2                      ! Cell y-dimension

C *** Variable to set time step for writing visibility file

      INTEGER, SAVE :: WSTEP  = 0   ! local write counter
      LOGICAL, SAVE :: WRITETIME = .FALSE. ! local write flag

C *** meteorological variables

C *** Reciprocal (air density X Jacobian, where Jacobian = sq. root of the
C     determinant of the metric tensor) at midlayer -inverted after read
      REAL PRES   ( NCOLS,NROWS,NLAYS )  ! Atmospheric pressure [ Pa ]
      REAL TA     ( NCOLS,NROWS,NLAYS )  ! Air temperature [ K ] 
      REAL DENS   ( NCOLS,NROWS,NLAYS )  ! Air density [ kg/m**-3 ]
      REAL QV     ( NCOLS,NROWS,NLAYS )  ! Water vapor mixing ratio [ kg/kg ]

C *** variables computed and output but not carried in CGRID

C *** visibility variables

!     INTEGER, PARAMETER :: N_AE_VIS_SPC = 4

C     visual range in deciview (Mie)
!     INTEGER, PARAMETER :: IDCVW1 = 1

C     extinction [ 1/km ] (Mie)
!     INTEGER, PARAMETER :: IBEXT1 = 2
      INTEGER, PARAMETER :: IBEXT1 = 1

C     visual range in deciview (Reconstructed)
!     INTEGER, PARAMETER :: IDCVW2 = 3

C     extinction [ 1/km ] (Reconstructed)
!     INTEGER, PARAMETER :: IBEXT2 = 4
      INTEGER, PARAMETER :: IBEXT2 = 2

!     REAL VIS_SPC( NCOLS,NROWS,N_AE_VIS_SPC ) ! Visual range information

C *** aerosol distribution variables

!     REAL DIAM_SPC( NCOLS,NROWS,NLAYS,18 ) 
                                ! aerosol size distribution variables

C *** grid variables

C *** information about blocks

C *** pointers to gas (vapor) phase species and production rates in CGRID

      INTEGER, SAVE :: LSULF, LSULFP, LHNO3, LNH3,LN2O5
      INTEGER, SAVE :: LTOLAER, LXYLAER, LCSLAER
      INTEGER, SAVE :: LALKAER
      INTEGER, SAVE :: LOLIAER, LTERPAER, LTERP 

C *** meteorological information:

      REAL BLKPRS           ! Air pressure in [ Pa ]
      REAL BLKTA            ! Air temperature [ K ]
      REAL BLKDENS          ! Air density  [ kg m^-3 ]
      REAL BLKDENS1         ! Reciprocal of air density      
      REAL BLKQA            ! Water vapor mixing ratio
      REAL BLKESAT          ! Saturation water vapor pressure [Pa]
      REAL BLKEVAP          ! Ambient water vapor pressure [Pa]
      REAL BLKRH            ! Fractional relative humidity

C *** chemical production rates: [ ug / m**3 s ]

      REAL SO4RATE      ! sulfate gas-phase production rate 

C *** new information f or secondary organic aerosols
      
      INTEGER               VV ! loop index for vapors
      INTEGER               VVLOC !	 generic index
      INTEGER, PARAMETER :: NPSPCS = 6
      INTEGER, PARAMETER :: NCVAP = 10
      CHARACTER( 16 ), SAVE :: VAPNAMES ( NCVAP )  
      REAL VAPORS( NCVAP )  ! condensible secondary organic vapors 
      INTEGER, SAVE :: LOCVAP( NCVAP )
      REAL ORGPROD( NPSPCS )

c..The following paramters derived form annual emission inv estimates
c..They represent the fraction of lumped compunds that are SOA precursors
      REAL, PARAMETER :: SPALK = 0.57  ! Frac of SAPRC99 ALK5 producing SOA
      REAL, PARAMETER :: SPTOL = 0.93  ! Frac of SAPRC99 ARO1 producing SOA
      REAL, PARAMETER :: RDALK = 0.56  ! Frac of RADM2 HC8 producing SOA
      REAL, PARAMETER :: RDTOL = 0.94  ! Frac of RADM2 TOL producing SOA


C *** Current implementation

!     ORGPROD(1) -> "long" alkanes ( alk5 in saprc99)
!     ORGPROD(2) -> internal alkenes ( cyclohexene. ole2 in saprc99 )
!     ORGPROD(3) -> aromatics like xylene  (aro2 in saprc99)
!     ORGPROD(4) -> aromatics like cresol (cres in saprc99)
!     ORGPROD(5) -> aromatics like toluene (aro1 in saprc99)
!     ORGPROD(6) -> monoterpenes (trp1 in saprc99)
 
C *** atmospheric properties

      REAL XLM             ! atmospheric mean free path [ m ]
      REAL AMU             ! atmospheric dynamic viscosity [ kg/m s ]

C *** modal diameters [ m ]

      REAL DGATK           ! Aitken mode geometric mean diameter  [ m ]
      REAL DGACC           ! accumulation geometric mean diameter [ m ]
      REAL DGCOR           ! coarse mode geometric mean diameter  [ m ] 

C *** log of modal geometric standard deviation

      REAL XXLSGAT         ! Aitken mode
      REAL XXLSGAC         ! accumulation mode
      
C *** aerosol properties: 

C *** modal mass concentrations [ ug m**3 ]

      REAL PMASSAT         ! mass concentration in Aitken mode 
      REAL PMASSAC         ! mass concentration in accumulation mode
      REAL PMASSCO         ! mass concentration in coarse mode 

C *** average modal particle densities  [ kg/m**3 ]

      REAL PDENSAT         ! average particle density in Aitken mode 
      REAL PDENSAC         ! average particle density in 
                           ! accumulation mode 
      REAL PDENSCO         ! average particle density in coarse mode  

C *** mass fraction of each mode less than 2.5um aerodynamic diameter

      REAL PM25AT          ! fine fraction of Aitken mode
      REAL PM25AC          ! fine fraction of accumulation mode
      REAL PM25CO          ! fine fraction of coarse mode

C *** visual range information

      REAL BLKDCV1         ! block deciview (Mie)
      REAL BLKEXT1         ! block extinction [ km**-1 ] (Mie)

      REAL BLKDCV2         ! block deciview (Reconstructed)
      REAL BLKEXT2         ! block extinction [ km**-1 ] (Reconstructed)

C *** molecular weights

      REAL, SAVE :: MWSO4, MWNO3, MWNH4         ! Aerosol species
      REAL, SAVE :: MWH2SO4, MWHNO3, MWNH3      ! Gas (vapor) species
      REAL, SAVE :: MWTOL, MWXYL, MWCSL, MWTERP ! organic aerosol precursors
      REAL, SAVE :: MWN2O5                      ! N2O5

C *** conversion factors for unit conversions betwen ppm and ugm**-3

      REAL, SAVE :: TOLCONV, XYLCONV, CSLCONV, TERPCONV ! ppm -> ug m**-3  
      REAL, SAVE :: H2SO4CONV, HNO3CONV, NH3CONV        ! ppm -> ug m**-3
      REAL, SAVE :: N2O5CONV
      REAL, SAVE :: H2SO4CONV1, HNO3CONV1, NH3CONV1     ! ug m**-3 -> ppm
      REAL, SAVE :: N2O5CONV1
      
C FSB PM emissions now done in vertical diffusion

      INTEGER      GXOFF, GYOFF              ! global origin offset from file
C for INTERPX
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3

C *** other internal aerosol variables

      INTEGER IND                         ! index to be used with INDEX1

C *** synchronization time step [ s ]

      REAL DT

C *** variables to set up for "dry transport "

      REAL M3_WET, M3_DRY   ! third moment with and without water
      REAL M2_WET, M2_DRY   ! second moment with and without water
C flag to include water in the 3rd moment calculation
      LOGICAL, PARAMETER :: M3_WET_FLAG = .FALSE.
                            
C FSB the following variables are defined and set in AERO_INFO_AE3
C      11/09/2001

!     REAL, PARAMETER :: TWO3 = 2.0 / 3.0          ! 2/3
!     REAL, PARAMETER :: F6DPI = 6.0 / PI          ! 6/PI
!     REAL, PARAMETER :: F6DPIM9 = 1.0E-9 * F6DPI  ! 1.0e-9 * 6/PI
!     REAL, PARAMETER :: RHOH2O = 1.0E+3     !  bulk density of aerosol water 
!     REAL, PARAMETER :: H2OFAC = F6DPIM9 / RHOH2O

C *** variables aerosol diagnostic file flag

      INTEGER      STATUS            ! ENV... status
      CHARACTER( 80 ) :: VARDESC     ! environment variable description

C *** environment variable for AER_DIAG file

!     CHARACTER( 16 ), SAVE :: CTM_AER_DIAG = 'CTM_AER_DIAG'

C *** flag for AER_DIAG file [F], default

!     LOGICAL, SAVE :: AER_DIAG

C *** number of species (gas + aerosol) includes 2nd,3rd Moments & 4 gases

      INTEGER, PARAMETER :: NSPCSDA = N_AE_SPC + 13 ! N2O5 added - FSB

C *** main array of variables by species

      REAL CBLK( NSPCSDA )

C *** map of aerosol species

      INTEGER, SAVE :: N_AE_MAP
      INTEGER, SAVE :: CBLK_MAP( N_AE_SPCD ) = 0
 
      LOGICAL, SAVE :: FIRSTIME = .TRUE.

C *** ratio of molecular weights of water vapor to dry air = 0.622015

      REAL, PARAMETER :: EPSWATER = MWWAT / MWAIR

C *** mechanism name

      CHARACTER( 16 ), SAVE :: MECH

C *** Statement Function **************

      REAL ESATL ! arithmetic statement function for vapor pressure [Pa]
      REAL TT
C *** Coefficients for the equation, ESATL defining saturation vapor pressure
      REAL, PARAMETER :: AL = 610.94
      REAL, PARAMETER :: BL = 17.625
      REAL, PARAMETER :: CL = 243.04

C *** values of AL, BL, and CL are from:
C     Alduchov and Eskridge, "Improved Magnus Form Approximations of
C                            Saturation Vapor Pressure,"
C                            Jour. of Applied Meteorology, vol. 35,
C                            pp 601-609, April, 1996.         

      ESATL( TT ) = AL * EXP( BL * ( TT - 273.15 ) / ( TT - 273.15 + CL ) )

C *** End Statement Function  ********

C ------------------ begin body of AERO_DRIVER -------------------------

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
!        LOGDEV = INIT3()
         LOGDEV = SETUP_LOGDEV()

c..removed by jg to allow ae3 mechanism check below
!        IF ( N_AE_SPC .LE. 0 ) THEN
!           CALL M3MESG ( 'WARNING: Model not compiled for aerosols!' )
!           RETURN
!        END IF

C*** Make sure an ae3 version of the mechanism is being used
          IF ( INDEX ( MECHNAME, 'AE3' ) .LE. 0 ) THEN
             XMSG = 'AERO3 requires an AE3 version of chemical mechanism'
             CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
          END IF

C *** Set nucleation flag:
 
!         INUCL = 1  ! Flag for choice of nucleation Mechanism
!                    ! INUCL = 0, Kumala et al. Mechanism
!                    ! INUCL = 1, Youngblood and Kreidenweis mechanism

C *** Get aerosol diagnostic file flag.

!        AER_DIAG = .FALSE.         ! default
!        VARDESC = 'Flag for writing the aerosol diagnostic file'
!        AER_DIAG = ENVYN( CTM_AER_DIAG, VARDESC, AER_DIAG, STATUS )
!        IF ( STATUS .NE. 0 ) WRITE( LOGDEV, '(5X, A)' ) VARDESC
!        IF ( STATUS .EQ. 1 ) THEN
!           XMSG = 'Environment variable improperly formatted'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
!        ELSE IF ( STATUS .EQ. -1 ) THEN
!           XMSG = 
!    &          'Environment variable set, but empty ... Using default:'
!           WRITE( LOGDEV, '(5X, A, I9)' ) XMSG, JTIME
!        ELSE IF ( STATUS .EQ. -2 ) THEN
!           XMSG = 'Environment variable not set ... Using default:'
!           WRITE( LOGDEV, '(5X, A, I9)' ) XMSG, JTIME
!        END IF

C *** Set up names and indices.

C *** Initialize species indices for CBLK.

C *** Get CGRID offsets.

         CALL CGRID_MAP ( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )

C *** Determine CGRID species map from AE_SPC.EXT.

         V = 0
         VNAME = 'ASO4J'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSO4AJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ASO4I'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSO4AI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANH4J'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VNH4AJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANH4I'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VNH4AI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANO3J'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VNO3AJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ANO3I'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VNO3AI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGAJ'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGAJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGAI'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGAI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGPAJ'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGPAJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGPAI'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGPAI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF            

         VNAME = 'AORGBJ'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGBAJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AORGBI'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VORGBAI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AECJ'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VECJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AECI'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VECI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'A25J'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VP25AJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'A25I'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VP25AI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ACORS'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VANTHA = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ASEAS'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSEAS = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'ASOIL'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSOILA = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMATKN'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VAT0 = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMACC'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VAC0 = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NUMCOR'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VCOR0 = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF
               
         VNAME = 'SRFATKN'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSURFAT = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'SRFACC'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VSURFAC = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF                       

         VNAME = 'AH2OJ'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VH2OAJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'AH2OI'
         N = INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VH2OAI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
         ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

C define additional AE species for Concentration of HPLUS in Aitken and
C Accumulation modes

         VNAME = 'HPLUSJ'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VHPLUSJ = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            VHPLUSJ = 0
            END IF

         VNAME = 'HPLUSI'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            VHPLUSI = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            VHPLUSI = 0
            END IF

         N_AE_MAP = V

C additional AE species for mean geometric diameters in Aitken and
C accumulation modes

         VNAME = 'DGATKN_DRY'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            DGATKN_DRY = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            DGATKN_DRY = 0
            END IF

         VNAME = 'DGACC_DRY'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            DGACC_DRY = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            DGACC_DRY = 0
            END IF

         VNAME = 'DGATKN_WET'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            DGATKN_WET = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            DGATKN_WET = 0
            END IF

         VNAME = 'DGACC_WET'
         N =  INDEX1( VNAME, N_AE_SPC, AE_SPC )
         IF ( N .NE. 0 ) THEN
            V = V + 1
            DGACC_WET = V
            CBLK_MAP( V ) = AE_STRT - 1 + N
            ELSE
            XMSG = 'Could not find ' // VNAME // 'in aerosol table'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            CALL M3MESG ( XMSG )
            DGACC_DRY = 0
            END IF

C *** Set additional species contained only in CBLK not needed in CBLK_MAP.

         V = N_AE_SPC + 1
         VSGAT = V

         V = V + 1
         VSGAC = V

         V = V + 1
         VDGAT = V

         V = V + 1
         VDGAC = V

         V = V + 1
         VAT2 = V

         V = V + 1
         VAC2 = V

         V = V + 1
         VAT3 = V

         V = V + 1
         VAC3 = V
            
         V = V + 1
         VCOR3 = V
            
         V = V + 1
         VSULF = V
          
         V = V + 1
         VHNO3 = V

         V = V + 1
         VNH3 = V
         
         V = V + 1
         VN2O5 = V
         
C *** Get generic mechanism name

         IF ( INDEX ( MECHNAME, 'CB4' ) .GT. 0 ) THEN
             MECH = 'CB4'
         ELSE IF ( INDEX ( MECHNAME, 'RADM2' )  .GT. 0 ) THEN
             MECH = 'RADM2'
         ELSE IF ( INDEX ( MECHNAME, 'SAPRC99' ) .GT. 0 ) THEN
             MECH = 'SAPRC99'
         ELSE
            XMSG = 'Base chemical mechanism must CB4, RADM2, or SAPRC99'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

C *** Set pointers for gas (vapor) phase species and production rates in CGRID.

         VNAME = 'SULF'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LSULF     = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWH2SO4   = GC_MOLWT( GC_G2AE_MAP( N ) )
         ELSE
            XMSG = 
     &        'Could not find ' // VNAME // 'in gas chem aerosol table'
        
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF
               
         VNAME = 'HNO3'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LHNO3  = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWHNO3 = GC_MOLWT( GC_G2AE_MAP( N ) )           
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'N2O5'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LN2O5  = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWN2O5 = GC_MOLWT( GC_G2AE_MAP( N ) )           
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF


         IF ( MECH .EQ. 'RADM2' .OR. MECH .EQ. 'CB4' ) THEN
            VNAME = 'TERPSP'
            N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
            IF ( N .NE. 0 ) THEN
               LTERP = GC_STRT - 1 + GC_G2AE_MAP( N )
            ELSE
               LTERP = 0
               XMSG =
     &            'Could not find ' // VNAME // 'in gas chem aerosol table'
               CALL M3MESG ( XMSG )
               CALL M3MESG ( 'Terpene species not modeled' )
            END IF
         END IF

         VNAME = 'ALKRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LALKAER = GC_STRT - 1 + GC_G2AE_MAP( N )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG 
     &             ( 'No production of organic aerosols from alkanes' )
            LALKAER = 0
         END IF

         VNAME = 'OLIRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LOLIAER = GC_STRT - 1 + GC_G2AE_MAP( N )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas Chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG 
     &            ( 'No production of organic aerosols from olefins' )
            LOLIAER = 0
         END IF

         VNAME = 'TOLRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LTOLAER = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWTOL   = GC_MOLWT( GC_G2AE_MAP( N ) )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG 
     &            ( 'No production of organic aerosols from toluene' )
            LTOLAER = 0
         END IF

         VNAME = 'XYLRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LXYLAER = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWXYL   = GC_MOLWT( GC_G2AE_MAP( N ) )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG 
     &           ( 'No production of organic aerosols from xylene' )
            LXYLAER = 0
         END IF
               
         VNAME = 'CSLRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LCSLAER = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWCSL   = GC_MOLWT( GC_G2AE_MAP( N ) )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG 
     &         ( 'No production of organic aerosols from cresol' )
            LCSLAER = 0
         END IF
               
         VNAME = 'TERPRXN'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LTERPAER = GC_STRT - 1 + GC_G2AE_MAP( N )
            MWTERP   = GC_MOLWT( GC_G2AE_MAP( N ) )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3MESG ( XMSG )
            CALL M3MESG
     &           ( 'No production of organic aerosols from terpenes' )
            LTERPAER = 0
         END IF
               
         VNAME = 'SULPRD'
         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
         IF ( N .NE. 0 ) THEN
            LSULFP = GC_STRT - 1 + GC_G2AE_MAP( N )
         ELSE
            XMSG = 
     &         'Could not find ' // VNAME // 'in gas chem aerosol table'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
         END IF

         VNAME = 'NH3'

C *** Look in gas-phase species first.

         N = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )

         IF ( N .NE. 0 ) THEN
            LNH3  = GC_STRT - 1 + GC_G2AE_MAP( N ) 
            MWNH3 = GC_MOLWT( GC_G2AE_MAP( N ) )                        

         ELSE

C *** Then try non-reactives.

            N = INDEX1( VNAME, N_NR_N2AE, NR_N2AE )
            IF ( N .NE. 0 ) THEN
               LNH3  = NR_STRT - 1 + NR_N2AE_MAP( N )  
               MWNH3 = NR_MOLWT( NR_N2AE_MAP( N ) )

C *** If NH3 not present, quit with error message.

            ELSE
               XMSG = 'Could not find ' // VNAME // 
     &                'in gas chem aerosol or non-reactives table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 ) 
            END IF

         END IF

C *** Set VAPNAMES values

         VAPNAMES(  1 ) = 'SGTOT_ALK'         
         VAPNAMES(  2 ) = 'SGTOT_OLI_1'       
         VAPNAMES(  3 ) = 'SGTOT_OLI_2'       
         VAPNAMES(  4 ) = 'SGTOT_XYL_1'       
         VAPNAMES(  5 ) = 'SGTOT_XYL_2'       
         VAPNAMES(  6 ) = 'SGTOT_CSL'         
         VAPNAMES(  7 ) = 'SGTOT_TOL_1'       
         VAPNAMES(  8 ) = 'SGTOT_TOL_2'       
         VAPNAMES(  9 ) = 'SGTOT_TRP_1'       
         VAPNAMES( 10 ) = 'SGTOT_TRP_2'       

C *** Fetch the indices for organic vapors from the non-reactive table
            
         DO VV = 1, NCVAP
            VNAME = VAPNAMES( VV )
            N = INDEX1( VNAME, N_NR_N2AE, NR_N2AE )
            IF ( N .NE. 0 ) THEN
               LOCVAP( VV )  = NR_STRT - 1 + NR_N2AE_MAP( N )  
            ELSE
               XMSG = 'Could not find ' // VNAME // 
     &                'in non-reactives table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 ) 
            END IF
         END DO 

C *** Fetch molecular weights.

         MWSO4 = AE_MOLWT( VSO4AJ )
         MWNO3 = AE_MOLWT( VNO3AJ )
         MWNH4 = AE_MOLWT( VNH4AJ )

C *** In the following conversion factors, the 1.0e3 factor
C     is to convert density from kg m**-3 to g m**-3.
        
C *** factors for converting from ppm to ug m-**3
         
         H2SO4CONV = 1.0E3 * MWH2SO4 / MWAIR
         HNO3CONV  = 1.0E3 * MWHNO3  / MWAIR
         NH3CONV   = 1.0E3 * MWNH3   / MWAIR
         N2O5CONV  = 1.0E3 * MWN2O5  / MWAIR

C..no longer used
!         TOLCONV   = 1.0E3 * MWTOL  / MWAIR
!         XYLCONV   = 1.0E3 * MWXYL  / MWAIR
!         CSLCONV   = 1.0E3 * MWCSL  / MWAIR
!         TERPCONV  = 1.0E3 * MWTERP / MWAIR
    
C *** reciprocals for converting from ug m**-3 to ppm
         
         H2SO4CONV1 = 1.0 / H2SO4CONV
         HNO3CONV1  = 1.0 / HNO3CONV
         NH3CONV1   = 1.0 / NH3CONV
         N2O5CONV1  = 1.0 / N2O5CONV

C *** Open the met files.

         IF ( .NOT. OPEN3( MET_CRO_3D, FSREAD3, PNAME ) ) THEN
            XMSG = 'Could not open  MET_CRO_3D  file '
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

         IF ( .NOT. OPEN3( MET_CRO_2D, FSREAD3, PNAME ) ) THEN
            XMSG = 'Could not open  MET_CRO_2D file '
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

C *** Set up file structure for visibility file. It has two variables,
C     visual range in deciview units (dimensionless) and extinction in
C     units of (1/km) and is for layer 1 only.

!        IF ( MYPE .EQ. 0 ) CALL OPVIS ( JDATE, JTIME, TSTEP( 1 ) )

C *** Open the aerosol parameters file (diameters and standard deviations).

!        IF ( AER_DIAG .AND.
!    &        MYPE .EQ. 0 ) CALL OPDIAM ( JDATE, JTIME, TSTEP( 1 ) )

C Get domain decomp info from the MET_CRO_3D file

         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

      END IF    ! FIRSTIME

C ------------ Begin Interpolation of Meteorological Variables ---------

      MDATE  = JDATE
      MTIME  = JTIME
      MSTEP = TIME2SEC( TSTEP( 2 ) )
      CALL NEXTIME ( MDATE, MTIME, SEC2TIME( MSTEP / 2 ) )

      WSTEP = WSTEP + TIME2SEC( TSTEP( 2 ) )
      IF ( WSTEP .GE. TIME2SEC( TSTEP( 1 ) ) ) WRITETIME = .TRUE.

C *** Set floating point synchronization time step:

      DT = FLOAT( MSTEP ) ! set time step in seconds

C *** layered variables PRES, TA, QV, DENS:

C *** air density X square root of the determinant of the metric tensor
C     at midlayer 

C *** pressure (Pa)

      VNAME = 'PRES'

!     IF ( .NOT. INTERP3( MET_CRO_3D, VNAME, PNAME,
!    &                    MDATE, MTIME, NCOLS*NROWS*NLAYS,
!    &                    PRES ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, PRES ) ) THEN
        XMSG = 'Could not interpolate PRES from ' // MET_CRO_3D
        CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

C *** temperature (K)

      VNAME = 'TA'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VNAME, PNAME,
!    &                    MDATE, MTIME, NCOLS* NROWS*NLAYS,
!    &                    TA ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, TA ) ) THEN
        XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_3D '
        CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

C *** specific humidity (g H2O / g air)

      VNAME = 'QV'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VNAME, PNAME,
!    &                    MDATE, MTIME, NCOLS*NROWS*NLAYS,
!    &                    QV ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, QV ) ) THEN
        XMSG = 'Could not interpolate specific humidity from MET_CRO_3D'
        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF 

C *** air density (kg/m3)

      VNAME = 'DENS'
!     IF ( .NOT. INTERP3( MET_CRO_3D, VNAME, PNAME,
!    &                    MDATE, MTIME, NCOLS*NROWS*NLAYS,
!    &                    DENS ) ) THEN
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, DENS ) ) THEN
        XMSG = 'Could not interpolate '// VNAME // ' from MET_CRO_3D '
        CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
      END IF

C *** end interpolation of meteorological variables 


C --------------------- Begin loops over grid cells --------------------------

C *** initialize CBLK

      CBLK = 0.0

      DO L = 1, NLAYS
         DO R = 1, MY_NROWS
            DO C = 1, MY_NCOLS

C *** Fetch the grid cell meteorological data.

               LAYER = L

               BLKTA    = TA   ( C,R,L )
               BLKPRS   = PRES ( C,R,L )   ! Note pascals
               BLKQA    = QV   ( C,R,L )
               BLKDENS  = DENS ( C,R,L )
               BLKDENS1 = 1.0 / BLKDENS 
               BLKESAT  = ESATL( BLKTA ) 
               BLKEVAP  = BLKPRS * BLKQA / ( EPSWATER  + BLKQA )
!              BLKRH    = MIN( 0.99, BLKEVAP / BLKESAT )
               BLKRH    = MAX( 0.005, MIN( 0.99, BLKEVAP / BLKESAT ) )

C *** Transfer CGRID values to CBLK (limit to mapped species)

               DO SPC = 1, N_AE_MAP
                  V = CBLK_MAP( SPC )
                  CBLK( SPC ) = MAX ( CGRID( C,R,L,V ), CONMIN )
               END DO

C *** Add gas and vapor phase species to CBLK

               CBLK( VSULF ) = MAX( CONMIN, 
     &             H2SO4CONV * BLKDENS * CGRID( C,R,L,LSULF ) )

               CBLK( VHNO3 ) = MAX( CONMIN,
     &             HNO3CONV  * BLKDENS * CGRID( C,R,L,LHNO3 ) )

               CBLK( VNH3 )  = MAX( CONMIN,
     &             NH3CONV   * BLKDENS * CGRID( C,R,L,LNH3 ) )

               CBLK( VN2O5 ) = MAX( CONMIN,
     &             N2O5CONV  * BLKDENS * CGRID( C,R,L,LN2O5 ) )

C *** Fetch gas-phase production rates.

C *** sulfate 
               SO4RATE = H2SO4CONV * BLKDENS
     &                 * CGRID( C,R,L,LSULFP ) / DT

C *** secondary organics

               DO SPC = 1, NPSPCS
                  ORGPROD( SPC ) = 0.0
               END DO

               IF ( LALKAER .GT. 0 )
     &            ORGPROD( 1 ) = CGRID( C,R,L,LALKAER ) 

C..SOA production forom alkenes eliminated 
!              IF ( MECH .EQ. 'RADM2' ) THEN
!                 IF ( LOLIAER .GT. 0 .AND. LTERPAER .GT. 0 )
!     &              ORGPROD( 2 ) = MAX( 0.0, ( CGRID( C,R,L,LOLIAER )
!     &                            - CGRID( C,R,L,LTERPAER ) ) )
!              ELSE IF (  MECH .EQ. 'SAPRC99' ) THEN
!                 IF ( LOLIAER .GT. 0 )
!     &              ORGPROD( 2 ) = CGRID( C,R,L,LOLIAER ) 
!              END IF

               IF ( LXYLAER .GT. 0 ) 
     &            ORGPROD( 3 ) = CGRID( C,R,L,LXYLAER ) 

               IF ( LCSLAER .GT. 0 )
     &            ORGPROD( 4 ) = CGRID( C,R,L,LCSLAER ) 

               IF ( LTOLAER .GT. 0 )
     &            ORGPROD( 5 ) = CGRID( C,R,L,LTOLAER ) 

               IF ( LTERPAER .GT. 0 )
     &            ORGPROD(6) = CGRID( C,R,L,LTERPAER ) 

c..Adjust TOL & ALK orgprods for fraction of precursor that produces SOA
               IF( MECH .EQ. 'SAPRC99' ) THEN
                  ORGPROD( 1 ) = SPALK * ORGPROD( 1 )
                  ORGPROD( 5 ) = SPTOL * ORGPROD( 5 )
               ELSEIF( MECH .EQ. 'RADM2' ) THEN
                  ORGPROD( 1 ) = RDALK * ORGPROD( 1 )
                  ORGPROD( 5 ) = RDTOL * ORGPROD( 5 )
               ENDIF

c *** Transfer SVOC concentrations from CGRID to VAPORS

               DO VV = 1, NCVAP
                  VAPORS( VV ) = 0.0
                  VVLOC = LOCVAP( VV )
                  IF ( VVLOC .GT. 0 ) VAPORS( VV ) = CGRID( C,R,L,VVLOC )
               END DO

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c     call aerosol process routines

               CALL AEROPROC( NSPCSDA,
     &                        CBLK, DT, LAYER,
     &                        BLKTA, BLKPRS, BLKDENS, BLKRH,
     &                        SO4RATE, 
     &                        ORGPROD, NPSPCS, VAPORS, NCVAP,
     &                        XLM, AMU,
     &                        DGATK, DGACC, DGCOR,
     &                        XXLSGAT, XXLSGAC,
     &                        PMASSAT, PMASSAC, PMASSCO,
     &                        PDENSAT, PDENSAC, PDENSCO,
     &                        LOGDEV )
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

C *** Transfer new aerosol information from CBLK to CGRID 
c      (limit to mapped species)

               DO SPC = 1, N_AE_MAP
                  V = CBLK_MAP( SPC )
                  CGRID( C,R,L,V ) = MAX( CONMIN, CBLK( SPC ) )
               END DO

C *** Transfer new gas/vapor concentrations from CBLK to CGRID

               CGRID( C,R,L,LSULF ) = MAX( CONMIN,
     &                      H2SO4CONV1 * BLKDENS1 * CBLK( VSULF ) )

               CGRID( C,R,L,LHNO3 ) = MAX( CONMIN,
     &                      HNO3CONV1  * BLKDENS1 * CBLK( VHNO3 ) )

               CGRID( C,R,L,LNH3 )  = MAX( CONMIN,
     &                      NH3CONV1   * BLKDENS1 * CBLK( VNH3 ) )
               
               CGRID( C,R,L,LN2O5 )  = MAX( CONMIN,
     &                      N2O5CONV1   * BLKDENS1 * CBLK( VN2O5 ) )

C *** Zero out species representing the contributions to production 
C      of aerosols.

               CGRID( C,R,L,LSULFP )  = 0.0

               IF ( LALKAER  .GT. 0 ) CGRID( C,R,L,LALKAER  ) = 0.0
               IF ( LOLIAER  .GT. 0 ) CGRID( C,R,L,LOLIAER  ) = 0.0
               IF ( LXYLAER  .GT. 0 ) CGRID( C,R,L,LXYLAER  ) = 0.0
               IF ( LCSLAER  .GT. 0 ) CGRID( C,R,L,LCSLAER  ) = 0.0
               IF ( LTOLAER  .GT. 0 ) CGRID( C,R,L,LTOLAER  ) = 0.0
               IF ( LTERPAER .GT. 0 ) CGRID( C,R,L,LTERPAER ) = 0.0

C *** Transfer new SVOC concentrations from VAPORS to CGRID

               DO VV = 1, NCVAP
                  VVLOC = LOCVAP( VV )
                  IF ( VVLOC .GT. 0 ) 
     &                CGRID( C,R,L,VVLOC ) = MAX ( CONMIN, VAPORS( VV ) )  
               END DO  

C *** Calculate volume fraction of each mode < 2.5um aerodynamic diameter

               XXLSGCO = LOG( SGINICO )
               CALL INLET25 ( DGATK, XXLSGAT, PDENSAT, PM25AT )
               CALL INLET25 ( DGACC, XXLSGAC, PDENSAT, PM25AC )
               CALL INLET25 ( DGCOR, XXLSGCO, PDENSCO, PM25CO )

C *** Write aerosol extinction coefficients and deciviews to visibility
C      diagnostic array (lowest vertical layer only)

!              IF ( WRITETIME .AND. L .EQ. 1 ) THEN
               IF ( WRITETIME ) THEN

                  CALL GETVISBY ( NSPCSDA,
     &                            CBLK, BLKRH,
     &                            BLKDCV1, BLKEXT1, BLKDCV2, BLKEXT2,
     &                            DGATK, DGACC, DGCOR,
     &                            XXLSGAT, XXLSGAC,
     &                            PMASSAT, PMASSAC, PMASSCO )

!                 VIS_SPC( C,R,L,IDCVW1 ) = BLKDCV1 ! visual range [ deciview ]
                                                    ! (Mie)
                  VIS_SPC( C,R,L,IBEXT1 ) = BLKEXT1 ! aerosol extinction [ 1/km ]
                                                    ! (Mie)
!                 VIS_SPC( C,R,L,IDCVW2 ) = BLKDCV2 ! visual range [ deciview ]
                                                    ! (Reconstructed)
                  VIS_SPC( C,R,L,IBEXT2 ) = BLKEXT2 ! aerosol extinction [ 1/km ]
                                                    ! (Reconstructed)

               END IF

C *** Write wet diameters, 2nd, and 3rd moments to aerosol diagnostic array
C     This assumes that GETPAR was last called with M3_WET_FLAG = .TRUE.

               IF ( WRITETIME .AND. AER_DIAG ) THEN

                  DIAM_SPC( C,R,L, 5 ) = DGATK         ! wet i-mode diameter
                  DIAM_SPC( C,R,L, 6 ) = DGACC         ! wet j-mode diameter
                  DIAM_SPC( C,R,L, 8 ) = CBLK( VAT2 )  ! wet i-mode 2nd moment
                  DIAM_SPC( C,R,L, 9 ) = CBLK( VAC2 )  ! wet j-mode 2nd moment
                  DIAM_SPC( C,R,L,12 ) = CBLK( VAT3 )  ! wet i-mode 3rd moment
                  DIAM_SPC( C,R,L,13 ) = CBLK( VAC3 )  ! wet j-mode 3rd moment
                  DIAM_SPC( C,R,L,16 ) = PM25AT        ! i-mode fine fraction
                  DIAM_SPC( C,R,L,17 ) = PM25AC        ! j-mode fine fraction
                  DIAM_SPC( C,R,L,18 ) = PM25CO        ! coarse-mode fine fraction

               END IF   ! WRITETIME .AND. AER_DIAG

C *** Add wet mean diameters to CGRID

               CGRID( C,R,L,CBLK_MAP( DGATKN_WET ) ) = DGATK
               CGRID( C,R,L,CBLK_MAP( DGACC_WET ) ) = DGACC

C *** Calculate 2nd and 3rd moments of the "dry" aerosol distribution
C     NOTE! "dry" aerosol excludes both H2O and SOA  (January 2004 --SJR)

C     Aitken mode.
               M3_WET = CBLK( VAT3 )
               M3_DRY = M3_WET
     &                - H2OFAC * CBLK( VH2OAI )
     &                - ORGFAC * CBLK( VORGAI )
     &                - ORGFAC * CBLK( VORGBAI )
               M2_WET = CBLK( VAT2 )
               M2_DRY = M2_WET * ( M3_DRY / M3_WET ) ** TWO3

               CBLK( VAT3 ) = M3_DRY
               CBLK( VAT2 ) = M2_DRY

C     accumulation mode.
               M3_WET = CBLK( VAC3 )
               M3_DRY = M3_WET
     &                - H2OFAC * CBLK( VH2OAJ )
     &                - ORGFAC * CBLK( VORGAJ )
     &                - ORGFAC * CBLK( VORGBAJ )
               M2_WET = CBLK( VAC2 )
               M2_DRY = M2_WET * ( M3_DRY / M3_WET ) ** TWO3

               CBLK( VAC3 ) = M3_DRY
               CBLK( VAC2 ) = M2_DRY

C *** Calculate geometric mean diameters and standard deviations of the
C      "dry" size distribution

               CALL GETPAR( NSPCSDA,
     &                      CBLK,
     &                      PMASSAT, PMASSAC, PMASSCO,
     &                      PDENSAT, PDENSAC, PDENSCO,
     &                      DGATK, DGACC, DGCOR,
     &                      XXLSGAT, XXLSGAC,
     &                      M3_WET_FLAG )

C *** Write dry aerosol distribution parameters to aerosol diagnostic array

               IF ( WRITETIME .AND. AER_DIAG ) THEN

                  DIAM_SPC( C,R,L, 1 ) = EXP( XXLSGAT )
                  DIAM_SPC( C,R,L, 2 ) = EXP( XXLSGAC )
                  DIAM_SPC( C,R,L, 3 ) = DGATK         ! dry i-mode diameter
                  DIAM_SPC( C,R,L, 4 ) = DGACC         ! dry j-mode diameter
                  DIAM_SPC( C,R,L, 7 ) = DGCOR         ! dry coarse-mode diam.

                  DIAM_SPC( C,R,L,10 ) = CBLK( VAT3 )  ! dry i-mode 3rd moment
                  DIAM_SPC( C,R,L,11 ) = CBLK( VAC3 )  ! dry j-mode 3rd moment
                  DIAM_SPC( C,R,L,14 ) = CBLK( VCOR3 ) ! dry coarse-mode 3rd
                                                       ! moment
                  DIAM_SPC( C,R,L,15 ) = BLKRH         ! relative humidity

               END IF   ! WRITETIME .AND. AER_DIAG

C *** Calculate aerosol surface area from the dry 2nd moment.  Dry value is
C      used in transport routines.

               CGRID( C,R,L,CBLK_MAP( VSURFAT ) ) = PI * CBLK( VAT2 )
               CGRID( C,R,L,CBLK_MAP( VSURFAC ) ) = PI * CBLK( VAC2 )

C *** Add dry mean diameters to CGRID

               CGRID( C,R,L,CBLK_MAP( DGATKN_DRY ) ) = DGATK
               CGRID( C,R,L,CBLK_MAP( DGACC_DRY ) ) = DGACC

            END DO ! loop on MY_COLS
         END DO ! loop on MY_ROWS
      END DO ! loop on NLAYS

C *** end of loops over grid cells

C ------------ Write diagnostic information to output files --------------

C *** If last call this hour, write visibility information.

      IF ( WRITETIME ) THEN
         MDATE = JDATE
         MTIME = JTIME
         CALL NEXTIME ( MDATE, MTIME, TSTEP( 2 ) )
         WSTEP = 0
         WRITETIME = .FALSE.

!        IF ( .NOT. WRITE3( CTM_VIS_1, ALLVAR3,
!    &                      MDATE, MTIME, VIS_SPC ) ) THEN
!           XMSG = 'Could not write ' // CTM_VIS_1 // ' file'
!           CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
!        END IF

!        WRITE( LOGDEV, '( /5X, 3( A, :, 1X ), I8, ":", I6.6 )' )
!    &                  'Timestep written to', CTM_VIS_1,
!    &                  'for date and time', MDATE, MTIME

C *** Write data to the aerosol parameters file.

!        IF ( AER_DIAG ) THEN

!           IF ( .NOT. WRITE3( CTM_DIAM_1, ALLVAR3,
!    &                         MDATE, MTIME, DIAM_SPC ) ) THEN
!              XMSG = 'Could not write ' // CTM_DIAM_1 // ' file'
!              CALL M3EXIT ( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
!           END IF

!           WRITE( LOGDEV, '( /5X, 3( A, :, 1X ), I8, ":", I6.6 )' )
!    &                     'Timestep written to', CTM_DIAM_1,
!    &                     'for date and time', MDATE, MTIME

!        END IF

      END IF

      RETURN
      END