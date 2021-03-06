
        SUBROUTINE PRE_TEMPORAL(premaq_jdate, premaq_jtime)

C***********************************************************************
C  program body starts at line 214
C
C  DESCRIPTION:
C    This program computes the hourly emissions data from inventory emissions 
C    and/or activity and emission factor data. It can read average-inventory,
C    day-specific and hour-specific emissions and activity data.
C
C  PRECONDITIONS REQUIRED:  
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C    copied by: M. Houyoux 01/99
C    origin: tmppoint.F 4.3
C    extracted from temporal for Air Quality Forecasting 1/21/05 GAP
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id: temporal.f,v 1.24 2004/06/27 02:09:21 cseppan Exp $
C
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C
C Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/temporal/temporal.f,v $
C Last updated: $Date: 2004/06/27 02:09:21 $ 
C
C*************************************************************************

C.........  MODULES for public variables
C.........  This module contains the inventory arrays
        USE MODSOURC, ONLY: TZONES, TPFLAG, FLTRDAYL

C.........  This module contains the temporal cross-reference tables
        USE MODXREF, ONLY: MDEX, WDEX, DDEX

C.........  This module contains the temporal profile tables
        USE MODTMPRL, ONLY: NMON, NWEK, NHRL

C.........  This module contains emission factor tables and related
        USE MODEMFAC, ONLY: NEFS, INPUTHC, OUTPUTHC, EMTNAM,
     &                      EMTPOL, NEPOL, NETYPE

C.........  This module contains data for day- and hour-specific data
        USE MODDAYHR, ONLY: DYPNAM, DYPDSC, NDYPOA, NDYSRC, 
     &                      HRPNAM, HRPDSC, NHRPOA, NHRSRC,
     &                      LDSPOA, LHSPOA, LHPROF,
     &                      INDXD, EMACD, INDXH, EMACH

C.........  This module contains the lists of unique source characteristics
        USE MODLISTS, ONLY: NINVIFIP, INVIFIP, MXIDAT, INVDNAM, INVDVTS

C.........  This module contains the information about the source category
        USE MODINFO, ONLY: CATEGORY, BYEAR, NIPPA, EANAM, NSRC, 
     &                     NIACT, INVPIDX, NIPOL, EAREAD, EINAM, ACTVTY

C.........  This module is used for MOBILE6 setup information 
        USE MODMBSET, ONLY: DAILY, WEEKLY, MONTHLY, EPISLEN

        USE MOD_TEMPORAL
        USE MOD_LAYPOINT, ONLY:  ENAME, ANAME, SDEV
        USE MODMERGE, ONLY: CDEV

C.........  INCLUDES:

        IMPLICIT NONE

        INCLUDE 'SETDECL.EXT'   !  FileSetAPI variables and functions
	
	integer premaq_jdate, premaq_jtime


C..........  EXTERNAL FUNCTIONS and their descriptions:

        LOGICAL         CHKINT
        CHARACTER(2)    CRLF
        INTEGER         ENVINT
        LOGICAL         ENVYN
        INTEGER         FINDC
        INTEGER         GETDATE
        INTEGER         GETFLINE
        INTEGER         GETNUM
        INTEGER         INDEX1
        LOGICAL         ISDSTIME
        CHARACTER(14)   MMDDYY
        INTEGER         PROMPTFFILE
        INTEGER         RDTPROF
        INTEGER         SECSDIFF
        INTEGER         STR2INT
        LOGICAL         SETENVVAR

        EXTERNAL    CHKINT, CRLF, ENVINT, ENVYN, FINDC, 
     &              GETDATE, GETFLINE, GETNUM, INDEX1, ISDSTIME, MMDDYY,
     &              PROMPTFFILE, RDTPROF, SECSDIFF, STR2INT, SETENVVAR
                        

        INTEGER   I


        CHARACTER(16) :: PROGNAME = 'PRE_TEMPORAL' ! program name

C***********************************************************************
C   begin body of program PRE_TEMPORAL

!need to initalize constants in pre_temporal module
        GNAME = ' '
        DNAME = 'NONE'
	FNAME = ' '
	HNAME = 'NONE'
	TNAME = ' '
	PYEAR = 0
	EDEV = 0
	HDEV = 0
	MDEV = 0
        TMPNAME = ' '
	DAYLIT = .FALSE.
	EFLAG = .FALSE.
	EFLAG2 = .FALSE.
	FNDOUTPUT = .FALSE.
	USETIME( 4) = .FALSE.
	
        LDEV = INIT3()

C.........  Write out copywrite, version, web address, header info, and prompt
C           to continue running the program.
!AQF        CALL INITEM( LDEV, CVSW, PROGNAME )

C.........  Obtain settings from the environment...

C.........  Get the time zone for output of the emissions
        TZONE = ENVINT( 'OUTZONE', 'Output time zone', 0, IOS )

C.........  Get environment variable that overrides temporal profiles and 
C               uses only uniform profiles.
        NFLAG = ENVYN( 'UNIFORM_TPROF_YN', MESG, .FALSE., IOS )

C.........  Set source category based on environment variable setting
        CALL GETCTGRY

C.........  Get the name of the emission factor model to use for one run
        IF ( CATEGORY .EQ. 'MOBILE' ) THEN
            MESG = 'Emission factor model'
            CALL ENVSTR( 'SMK_EF_MODEL', MESG, 'MOBILE6', MODELNAM, IOS)
        ELSE
            MODELNAM = ' '
        END IF

C.........  Get inventory file names given source category
        CALL GETINAME( CATEGORY, ENAME, ANAME )
 

C.........  Prompt for and open input files
C.........  Also, store source-category specific information in the MODINFO 
C           module.
        CALL OPENTMPIN( MODELNAM, NFLAG, ENAME, ANAME, DNAME, HNAME, 
     &                  GNAME, SDEV, XDEV, RDEV, CDEV, HDEV, TDEV, 
     &                  MDEV, EDEV, PYEAR )

C.........  Determine status of some files for program control purposes
        DFLAG = ( DNAME .NE. 'NONE' )  ! Day-specific emissions
        HFLAG = ( HNAME .NE. 'NONE' )  ! Hour-specific emissions
        MFLAG = ( MDEV .NE. 0 )        ! Use mobile codes file
!
!!!!! added by GAP for debugging
!
        DFLAG = .FALSE.
	HFLAG = .FALSE.
	MFLAG = .FALSE.

C.........  Get length of inventory file name
        ENLEN = LEN_TRIM( ENAME )

C.........  Get episode settings from the Models-3 environment variables
        SDATE  = 0
        STIME  = 0
        NSTEPS = 1

	
!        CALL GETM3EPI( TZONE, SDATE, STIME, TSTEP, NSTEPS )

	
        NSTEPS = 1
	TZONE = 0
	SDATE = premaq_jdate
	STIME = premaq_jtime
	
        TSTEP  = 10000  ! Only 1-hour time steps supported

C.........  Compare base year with episode and warn if not consistent
        IF( SDATE / 1000 .NE. BYEAR ) THEN

            WRITE( MESG,94010 ) 'WARNING: Inventory base year ', BYEAR, 
     &             'is inconsistent with year ' // CRLF() // BLANK10 //
     &             'of episode start date', SDATE/1000
            CALL M3MSG2( MESG )

        ENDIF

C.........  Give a note if running for a projected year
        IF( PYEAR .GT. 0 ) THEN

            WRITE( MESG,94010 ) 'NOTE: Emissions based on projected '//
     &             'year', PYEAR
            CALL M3MSG2( MESG )

        END IF

C.........  Calculate the ending date and time
        EDATE = SDATE
        ETIME = STIME
        CALL NEXTIME( EDATE, ETIME, NSTEPS * 10000 )

C.........  Check requested episode against available emission factors

C.........  For day-specific data input...
        IF( DFLAG ) THEN

C.............  Get header description of day-specific input file
            IF( .NOT. DESC3( DNAME ) ) THEN
                CALL M3EXIT( PROGNAME, 0, 0, 
     &                       'Could not get description of file "' 
     &                       // DNAME( 1:LEN_TRIM( DNAME ) ) // '"', 2 )
            END IF

C.............  Allocate memory for pollutant pointer
            ALLOCATE( DYPNAM( NVARS3D ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DYPNAM', PROGNAME )
            ALLOCATE( DYPDSC( NVARS3D ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DYPDSC', PROGNAME )
            DYPNAM = ' '  ! array
            DYPDSC = ' '  ! array

C.............  Set day-specific file dates, check dates, and report problems
            CALL PDSETUP( DNAME, SDATE, STIME, EDATE, ETIME, TZONE,  
     &                    NIPPA, EANAM, NDYPOA, NDYSRC, EFLAG, DYPNAM,
     &                    DYPDSC )

        ENDIF

C.........  Allocate memory for reading day-specific emissions data
C.........  NDYSRC is initialized to zero in case DFLAG is false
        ALLOCATE( INDXD( NDYSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INDXD', PROGNAME )
        ALLOCATE( EMACD( NDYSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EMACD', PROGNAME )

C.........  For hour-specific data input...
        IF( HFLAG ) THEN

C............. Get header description of hour-specific input file
            IF( .NOT. DESC3( HNAME ) ) THEN
                CALL M3EXIT( PROGNAME, 0, 0, 
     &                       'Could not get description of file "' 
     &                       // HNAME( 1:LEN_TRIM( HNAME ) ) // '"', 2 )
            ENDIF

C.............  Allocate memory for pollutant pointer
            ALLOCATE( HRPNAM( NVARS3D ), STAT=IOS )
            CALL CHECKMEM( IOS, 'HRPNAM', PROGNAME )
            ALLOCATE( HRPDSC( NVARS3D ), STAT=IOS )
            CALL CHECKMEM( IOS, 'HRPDSC', PROGNAME )
            HRPNAM = ' '  ! array
            HRPDSC = ' '  ! array

C.............  Set day-specific file dates, check dates, and report problems
            CALL PDSETUP( HNAME, SDATE, STIME, EDATE, ETIME, TZONE,  
     &                    NIPPA, EANAM, NHRPOA, NHRSRC, EFLAG2, HRPNAM,
     &                    HRPDSC )

        ENDIF

C.........  Allocate memory for reading hour-specific emissions data
C.........  NHRSRC is initialized to 0 in case HFLAG is false
        ALLOCATE( INDXH( NHRSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INDXH', PROGNAME )
        ALLOCATE( EMACH( NHRSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EMACH', PROGNAME )

        IF( EFLAG .OR. EFLAG2 ) THEN
            MESG = 'Problem with day- or hour-specific inputs'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ENDIF

C.........  Set inventory variables to read for all source categories
        IVARNAMS( 1 ) = 'IFIP'
        IVARNAMS( 2 ) = 'TZONES'
        IVARNAMS( 3 ) = 'TPFLAG'
        IVARNAMS( 4 ) = 'CSCC'
        IVARNAMS( 5 ) = 'CSOURC'

C.........  Set inventory variables to read for specific source categories
        IF( CATEGORY .EQ. 'AREA' ) THEN
            NINVARR = 5

        ELSE IF( CATEGORY .EQ. 'MOBILE' ) THEN
            NINVARR = 9
            IVARNAMS( 6 ) = 'IRCLAS'
            IVARNAMS( 7 ) = 'IVTYPE'
            IVARNAMS( 8 ) = 'CLINK'
            IVARNAMS( 9 ) = 'CVTYPE'

        ELSE IF( CATEGORY .EQ. 'POINT' ) THEN
            NINVARR = 5

        END IF


	
C.........  Allocate memory for and read in required inventory characteristics
        CALL RDINVCHR( CATEGORY, ENAME, SDEV, NSRC, NINVARR, IVARNAMS )


C.........  Reset TPFLAG if average day emissions are being used since
C           we don't want to apply the monthly adjustment factors in this case.
        IF ( INVPIDX .EQ. 1 ) THEN
            DO S = 1, NSRC
                IF ( MOD( TPFLAG( S ), MTPRFAC ) .EQ. 0 ) THEN
                    TPFLAG( S ) = TPFLAG( S ) / MTPRFAC
                END IF
            END DO
        END IF

C.........  Build unique lists of SCCs per SIC from the inventory arrays
        CALL GENUSLST

C.........  Define the minimum and maximum time zones in the inventory
        TZMIN = MINVAL( TZONES )
        TZMAX = MAXVAL( TZONES )

C.........  Adjust TZMIN for possibility of daylight savings
        TZMIN = MAX( TZMIN - 1, 0 )

C.........  Read special files...

C.........  Read region codes file
        CALL RDSTCY( CDEV, NINVIFIP, INVIFIP )
!AQF
        DEALLOCATE (INVIFIP)
        REWIND(CDEV)

!AQF
C.........  Populate filter for sources that use daylight time
        CALL SETDAYLT

C.........  Read holidays file
        CALL RDHDAYS( HDEV, SDATE, EDATE )

C.........  When mobile codes file is being used read mobile codes file
        IF( MFLAG ) CALL RDMVINFO( MDEV )

C.........  Perform steps needed for using activities and emission factors

        IF( NIACT .GT. 0 ) THEN   ! DONT NEED FOR PT SOURCES

C.............  Allocate memory for emission factor arrays
            ALLOCATE( TEMPEF( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'TEMPEF', PROGNAME )
            ALLOCATE( EFTYPE( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EFFILE', PROGNAME )
            ALLOCATE( EFIDX( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EFIDX', PROGNAME )

            TEMPEF = 0.
            EFTYPE = ' '
            EFIDX  = 0

C.............  Determine number of days in episode

C.............  Earliest day is start time in maximum time zone
            EARLYDATE = SDATE
            EARLYTIME = STIME
            CALL NEXTIME( EARLYDATE, EARLYTIME, 
     &                   -( TZMAX - TZONE )*10000 )
            
C.............  If time is before 6 am, need previous day also
            IF( EARLYTIME < 60000 ) THEN
                EARLYDATE = EARLYDATE - 1
            END IF
            
C.............  Latest day is end time in minimum time zone
            LATEDATE = EDATE
            LATETIME = ETIME
            CALL NEXTIME( LATEDATE, LATETIME, 
     &                   -( TZMIN - TZONE )*10000 )

C.............  If time is before 6 am, don't need last day
            IF( LATETIME < 60000 ) THEN
                LATEDATE = LATEDATE - 1
            END IF

            NDAYS = SECSDIFF( EARLYDATE, 0, LATEDATE, 0 ) / ( 24*3600 )
            NDAYS = NDAYS + 1
            ALLOCATE( EFDAYS( NDAYS,4 ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EFDAYS', PROGNAME )
            EFDAYS = 0

C.............  Read header of ungridding matrix
            IF( .NOT. DESC3( GNAME ) ) THEN
                MESG = 'Could not get description for file ' // GNAME
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Store number of ungridding factors
            NMATX = NCOLS3D

C.............  Allocate memory for ungridding matrix
            ALLOCATE( UMAT( NSRC + 2*NMATX ), STAT=IOS )
            CALL CHECKMEM( IOS, 'UMAT', PROGNAME )

C.............  Read ungridding matrix
            CALL RDUMAT( GNAME, NSRC, NMATX, NMATX, UMAT( 1 ),
     &                   UMAT( NSRC+1 ), UMAT( NSRC+NMATX+1 )  )

C.............  Store sources that are outside the grid
            DO S = 1, NSRC
                IF( UMAT( S ) == 0 ) THEN
                    EFIDX( S ) = -9
                END IF
            END DO

C.............  Read emission processes file.  Populate array in MODEMFAC.
            CALL RDEPROC( TDEV )

C.............  Loop through activities and...
C.............  NOTE - this is not fully implemented for multiple activities. 
C               To do this, the data structures and RDEFACS will need to be 
C               updated. Also, the variable names in the emission factor file
C               are not truly supporting 16-character pollutant and 
C               emission process names, because it is only set up for MOBILE5
            DO I = 1, NIACT

C.................  Skip activities that do not have emissions types
                IF( NETYPE( I ) .LE. 0 ) CYCLE            

C.................  Set up emission process variable names
                CALL EFSETUP( 'NONE', MODELNAM, NEFS, VOLNAM )

            END DO

C.............  Read inventory table
            VDEV = PROMPTFFILE( 
     &           'Enter logical name for INVENTORY DATA TABLE file',
     &           .TRUE., .TRUE., 'INVTABLE', PROGNAME )
            CALL RDCODNAM( VDEV )

C.............  Check if processing NONHAP values

C.............  Set input and output hydrocarbon names
            INPUTHC = TRIM( VOLNAM )
            OUTPUTHC = 'NONHAP' // TRIM( INPUTHC )

            FNDOUTPUT = .FALSE.
            K = 0

C.............  Loop through all pollutants        
            DO I = 1, MXIDAT
            
                IF( INVDNAM( I ) == OUTPUTHC ) THEN
                    FNDOUTPUT = .TRUE.
                    CYCLE
                END IF

C.................  If requested hydrocarbon is not TOG or VOC, skip rest of loop
                IF( INPUTHC /= 'TOG' .AND. INPUTHC /= 'VOC' ) EXIT
         
                IF( INVDVTS( I ) /= 'N' ) THEN
            
C.....................  Check that pollutant is generated by MOBILE6   
                    DO J = 1, NEPOL
                        IF( INVDNAM( I ) == EMTPOL( J ) ) THEN
                            IF( INVDVTS( I ) == 'V' ) THEN
                                K = K + 1
                            ELSE IF( INPUTHC == 'TOG' ) THEN
                                K = K + 1
                            END IF
                            EXIT
                        END IF
                    END DO
                END IF
            END DO

C.............  If output was not found, set name to blank        
            IF( .NOT. FNDOUTPUT .OR. K == 0 ) THEN
                OUTPUTHC = ' '             
            END IF

C.............  Rename emission factors if necessary
            IF( OUTPUTHC /= ' ' ) THEN
                DO I = 1, SIZE( EMTNAM,1 )
                    L = INDEX( EMTNAM( I,1 ), ETJOIN )
                    L2 = LEN_TRIM( ETJOIN )
                    
                    IF( EMTNAM( I,1 )( L+L2:IOVLEN3 ) == INPUTHC ) THEN
                        EMTNAM( I,1 )( L+L2:IOVLEN3 ) = OUTPUTHC
                        CYCLE
                    END IF
                END DO
            END IF

C.............  Read list of emission factor files
            NLINES = GETFLINE( EDEV, 'Emission factor file list' )

            ALLOCATE( EFLIST( NLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EFLIST', PROGNAME )
            ALLOCATE( EFLOGS( NLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EFLOGS', PROGNAME )
        
            EFLIST = ' '
            EFLOGS = ' '
            CALL RDLINES( EDEV, 'Emission factor file list', NLINES, 
     &                    EFLIST )

C.............  Loop through EF files
            MESG = 'Checking emission factor files...'
            CALL M3MSG2( MESG )

            DO N = 1, NLINES

                CURFNM = EFLIST( N )
                
C.................  Skip any blank lines
                IF( CURFNM == ' ' ) CYCLE

C.................  Determine file type
                IF( INDEX( CURFNM, 'daily' ) > 0 ) THEN
                    AVERTYPE = DAILY
                ELSE IF( INDEX( CURFNM, 'weekly' ) > 0 ) THEN
                    AVERTYPE = WEEKLY
                ELSE IF( INDEX( CURFNM, 'monthly' ) > 0 ) THEN
                    AVERTYPE = MONTHLY
                ELSE IF( INDEX( CURFNM, 'episode' ) > 0 ) THEN
                    AVERTYPE = EPISLEN
                ELSE
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not determine time period ' //
     &                     'of file ' // TRIM( CURFNM )
                    CALL M3MESG( MESG )
                    CYCLE
                END IF
                
C.................  Assign and store logical file name
                WRITE( INTBUF,94030 ) N
                CURLNM = 'EMISFAC_' // ADJUSTL( INTBUF )
                EFLOGS( N ) = CURLNM

C.................  Set logical file name
                IF( .NOT. SETENVVAR( CURLNM, CURFNM ) ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not set logical file name ' //
     &                     'for file ' // CRLF() // BLANK10 // '"' //
     &                     TRIM( CURFNM ) // '".'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

                USETIME( AVERTYPE ) = .TRUE.


C.................  Try to open file   
                IF( .NOT. OPENSET( CURLNM, FSREAD3, PROGNAME ) ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not open emission factors ' //
     &                     'file ' // CRLF() // BLANK10 // '"' //
     &                     TRIM( CURFNM ) // '".'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C.................  Read file description
                IF( .NOT. DESCSET( CURLNM, ALLFILES ) ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not get description for ' // 
     &                     'file ' // CRLF() // BLANK10 // '"' //
     &                     TRIM( CURFNM ) // '".'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF
                
                EFSDATE = SDATE3D

C.................  Find end date in file description
                SEARCHSTR = '/END DATE/ '
                L = LEN_TRIM( SEARCHSTR ) + 1
                ENDFLAG = .FALSE.
                
                DO I = 1, MXDESC3
                   IF( INDEX( FDESC3D( I ), 
     &                        SEARCHSTR( 1:L ) ) > 0 ) THEN
                       TEMPLINE = FDESC3D( I )
                       IF( CHKINT( TEMPLINE( L+1:L+8 ) ) ) THEN
                           EFEDATE = STR2INT( TEMPLINE( L+1:L+8 ) )
                           EXIT
                       ELSE
                           ENDFLAG = .TRUE.
                           EXIT
                       END IF
                   END IF
                   
                   IF( I == MXDESC3 ) THEN
                       ENDFLAG = .TRUE.
                   END IF
                END DO

                IF( ENDFLAG ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not get ending date of ' //
     &                     'file ' // CRLF() // BLANK10 // '"' //
     &                     TRIM( CURFNM ) // '".'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C.................  Determine starting and ending positions in array
                STPOS  = SECSDIFF( EARLYDATE, 0, EFSDATE, 0 )/(24*3600)
                STPOS  = STPOS + 1
                ENDPOS = SECSDIFF( EARLYDATE, 0, EFEDATE, 0 )/(24*3600)
                ENDPOS = ENDPOS + 1

C.................  Make sure starting and ending positions are valid
                IF( STPOS < 1 ) THEN
                    IF( ENDPOS > 0 ) THEN
                        STPOS = 1
                    ELSE
                        CYCLE
                    END IF
                END IF 
                
                IF( ENDPOS > NDAYS ) THEN
                    IF( STPOS <= NDAYS ) THEN
                        ENDPOS = NDAYS
                    ELSE
                        CYCLE
                    END IF
                END IF

C.................  Store day info
                DO I = STPOS, ENDPOS
                    EFDAYS( I, AVERTYPE ) = N
                END DO

C.................  Allocate memory for temporary source info
                IF( ALLOCATED( SRCS ) ) DEALLOCATE( SRCS )
                ALLOCATE( SRCS( NROWS3D ), STAT=IOS )
                CALL CHECKMEM( IOS, 'SRCS', PROGNAME )
            
                SRCS = 0
            
C.................  Read source information
                IF( .NOT. READSET( CURLNM, 'SOURCES', ALLAYS3, 
     &                             ALLFILES, SDATE3D, STIME3D, 
     &                             SRCS ) ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not read SOURCES ' // 
     &                     'from file ' // CRLF() // BLANK10 // '"' //
     &                     TRIM( CURFNM ) // '".'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C.................  Store source information
                DO S = 1, NROWS3D
                                    
                    IF( SRCS( S ) /= 0 ) THEN

C.........................  Make sure source number is valid
                        IF( SRCS( S ) < 1 .OR. SRCS( S ) > NSRC ) CYCLE
                        
C.........................  Skip sources that are outside the grid
                        IF( EFIDX( SRCS( S ) ) == -9 ) CYCLE
                    
                        EFIDX( SRCS( S ) ) = S
                        WRITE( EFTYPE( SRCS( S ) ),'(I1)' ) AVERTYPE
                    END IF
                END DO
                
C.................  Close current file
                IF( .NOT. CLOSESET( CURLNM ) ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Could not close file ' // 
     &                     TRIM( CURFNM )
                    CALL M3MESG( MESG )
                    CYCLE
                END IF
                
            END DO
 
C.............  Exit if there was a problem with the emission factor files
            IF( EFLAG ) THEN
                MESG = 'Problem checking emission factor files'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Make sure all days are covered
            DO I = DAILY, EPISLEN
                IF( USETIME( I ) .EQV. .TRUE. ) THEN 
                    IF( MINVAL( EFDAYS( 1:NDAYS,I ) ) == 0 ) THEN
                        MESG = 'ERROR: Emission factor files do not ' //
     &                         'cover requested time period.'
                        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                    END IF
                END IF
            END DO

C............  Print warning for sources that don't have emission factors
           DO I = 1, NSRC
               IF( EFIDX( I ) == 0 ) THEN
!                   WRITE( MESG,94070 ) 'WARNING: No VMT or emission ' //
!     &                    'factors available for' // CRLF() // 
!     &                    BLANK10 // 'Region: ', IFIP( I ),
!     &                    ' SCC: ' // CSCC( I )
!                   CALL M3MESG( MESG )
                   EFIDX( I ) = -1
               END IF
           END DO

        END IF   ! END IF foR ACTIVITY CHECK

C.........  Determine all of the variables to be output based on the 
C           activities and input pollutants.  
C.........  NOTE - Uses NETYPE, EMTACTV, and EMTNAM, and sets units, and units
C           conversion factors for all pollutants and activities
        CALL TMNAMUNT
        
C.........  Reset the number of all output variables as the number of pollutants
C           and emission types, instead of the number of pollutants and 
C           activities
        NIPPA = NIPOL
        DO I = 1, NIACT
            NIPPA = NIPPA + NETYPE( I )
        END DO

C.........  Allocate memory for I/O pol names, activities, & emission types
C.........  Will be resetting EANAM to include the emission types instead
C           of the activities
        DEALLOCATE( EANAM )
        ALLOCATE( EANAM( NIPPA ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EANAM', PROGNAME )
        ALLOCATE( ALLIN( NIPPA ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ALLIN', PROGNAME )

C.........  Create 1-d arrays of I/O pol names
C.........  If pollutant is created by one or more activities, then give a
C           warning.
        N = 0
        DO I = 1, NIPOL

C.............  Look for pollutant in list of pollutants created by activities
C               First, make sure that EMTPOL has been allocated; it won't be
C               when not using emission factors
            IF( ALLOCATED( EMTPOL ) ) THEN
                J = INDEX1( EINAM( I ), NEPOL, EMTPOL )
            ELSE
                J = 0
            END IF

C.............  If pollutant created by activity, skip from this list, unless
C               pollutant is also part of the inventory pollutants
            IF( J .GT. 0 ) THEN
                L1 = LEN_TRIM( EINAM ( I ) )
                L2 = LEN_TRIM( EAREAD( I ) )
                MESG = 'WARNING: Pollutant "' // EINAM(I)( 1:L1 ) //
     &                 '" is explicitly in the inventory and' //
     &                 CRLF() // BLANK10 // 'it is also generated by '
     &                 // 'activity data.'
                CALL M3MSG2( MESG )
            END IF

            N = N + 1
            ALLIN( N ) = EAREAD( I )
            EANAM( N ) = EINAM ( I )

        END DO

C.........  Add activities, & emission types to read and output lists
        J = NIPOL
        DO I = 1, NIACT

            K = NETYPE( I )  ! Number of emission types

C.............  If any emissions types associated with this activity, store them
            IF ( K .GT. 0 ) THEN
                ALLIN( J+1:J+K ) = ACTVTY( I )
                EANAM( N+1:N+K ) = EMTNAM( 1:K, I )
                N = N + K
            END IF
            J = J + K

        END DO

C.........  Reset number of pollutants and emission types based on those used
        NIPPA = N

C.........  Set up and open I/O API output file(s) ...
        CALL OPENTMP( ENAME, SDATE, STIME, TSTEP, NSTEPS, TZONE, NPELV,
     &                TNAME, PDEV )


	
        TNLEN = LEN_TRIM( TNAME )

C.........  Read temporal-profile cross-reference file and put into tables
C.........  Only read entries for pollutants that are in the inventory.
C.........  Only read if not using uniform temporal profiles
        IF( .NOT. NFLAG ) CALL RDTREF( XDEV, TREFFMT )

C.........  Read temporal-profiles file:  4 parts (monthly, weekly, 
C           weekday diurnal, and weekend diurnal)
        CALL M3MSG2( 'Reading temporal profiles file...' )

        NMON = RDTPROF( RDEV, 'MONTHLY', NFLAG )
        NWEK = RDTPROF( RDEV, 'WEEKLY' , NFLAG )
        NHRL = RDTPROF( RDEV, 'DIURNAL', NFLAG )

C.........  Adjust temporal profiles for use in generating temporal emissions
C.........  NOTE - All variables are passed by modules.
        CALL NORMTPRO

C.........  It is important that all major arrays must be allocated by this 
C           point because the next memory allocation step is going to pick a
C           data structure that will fit within the limits of the host.

C.........  Allocate memory, but allow flexibility in memory allocation
C           for second dimension.
C.........  The second dimension (the number of pollutants and emission types)
C            can be different depending on the memory available.
C.........  To determine the approproate size, first attempt to allocate memory
C           for all pollutants & emission types to start, and if this fails,
C           divide pollutants into even groups and try again.

        NGSZ = NIPPA            ! No. of pollutant & emis types in each group
        NGRP = 1               ! Number of groups

C.........  Make sure total array size is not larger than maximum
        DO
            IF( NSRC*NGSZ*24 >= 1024*1024*1024 ) THEN
                NGRP = NGRP + 1
                NGSZ = ( NIPPA + NGRP - 1 ) / NGRP
            ELSE
                EXIT
            END IF
        END DO

        IF (NGRP .NE. 1) THEN
            MESG = 'Insufficient memory for Temporal processing'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )	
	ENDIF


        DO

            ALLOCATE( TMAT ( NSRC, NGSZ, 24 ), STAT=IOS1 )
            ALLOCATE( MDEX ( NSRC, NGSZ )    , STAT=IOS2 )
            ALLOCATE( WDEX ( NSRC, NGSZ )    , STAT=IOS3 )
            ALLOCATE( DDEX ( NSRC, NGSZ )    , STAT=IOS4 )
            ALLOCATE( EMAC ( NSRC, NGSZ )    , STAT=IOS6 )
            ALLOCATE( EMACV( NSRC, NGSZ )    , STAT=IOS7 )
            ALLOCATE( EMIST( NSRC, NGSZ )    , STAT=IOS8 )
            ALLOCATE( EMFAC( NSRC, NGSZ )    , STAT=IOS9 )
            
            IF( IOS1 .GT. 0 .OR. IOS2 .GT. 0 .OR. IOS3 .GT. 0 .OR.
     &          IOS4 .GT. 0 .OR. IOS6 .GT. 0 .OR.
     &          IOS7 .GT. 0 .OR. IOS8 .GT. 0 .OR. IOS9 .GT. 0 ) THEN

                CALL M3MSG2('SPECIAL MEMORY ALLOCATION SECTION')

                IF( NGSZ .EQ. 1 ) THEN
                    J = 8 * NSRC * 31    ! Assume 8-byte reals
                    WRITE( MESG,94010 ) 
     &                'Insufficient memory to run program.' //
     &                CRLF() // BLANK5 // 'Could not allocate ' // 
     &                'pollutant-dependent block of', J, 'bytes.'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                NGRP = NGRP + 1
                NGSZ = ( NIPPA + NGRP - 1 ) / NGRP

                IF( ALLOCATED( TMAT  ) ) DEALLOCATE( TMAT )
                IF( ALLOCATED( MDEX  ) ) DEALLOCATE( MDEX )
                IF( ALLOCATED( WDEX  ) ) DEALLOCATE( WDEX )
                IF( ALLOCATED( DDEX  ) ) DEALLOCATE( DDEX )
                IF( ALLOCATED( EMAC  ) ) DEALLOCATE( EMAC )
                IF( ALLOCATED( EMACV ) ) DEALLOCATE( EMACV )
                IF( ALLOCATED( EMIST ) ) DEALLOCATE( EMIST )
                IF( ALLOCATED( EMFAC ) ) DEALLOCATE( EMFAC )

            ELSE
                EXIT

            END IF

        END DO
        
C.........  Allocate a few small arrays based on the size of the groups
C.........  NOTE that this has a small potential for a problem if these little
C           arrays exceed the total memory limit.
        ALLOCATE( ALLIN2D( NGSZ, NGRP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ALLIN2D', PROGNAME )
        ALLOCATE( EANAM2D( NGSZ, NGRP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EANAM2D', PROGNAME )
        ALLOCATE( LDSPOA( NGSZ ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LDSPOA', PROGNAME )
        ALLOCATE( LHSPOA( NGSZ ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LHSPOA', PROGNAME )
        ALLOCATE( LHPROF( NGSZ ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LHPROF', PROGNAME )

C.........  Create 2-d arrays of I/O pol names, activities, & emission types 
        ALLIN2D = ' '
        EANAM2D = ' '
        I = 0
        DO N = 1, NGRP 
            DO J = 1, NGSZ
                I = I + 1
                IF ( I .LE. NIPPA ) THEN
                    EANAM2D( J,N ) = EANAM( I )
                    ALLIN2D( J,N ) = ALLIN( I )
                END IF
            END DO
        END DO



        DO N = 1, NGRP

C.............  If this is the last group, NGSZ may be larger than actual
C               number of variables, so reset based on total number
            IF( N == NGRP ) THEN
                NGSZ = NIPPA - ( NGRP - 1 )*NGSZ
            END IF
            
C.............  Skip group if the first pollutant in group is blank (this
C               shouldn't happen, but it is happening, and it's easier to
C               make this fix).
            IF ( EANAM2D( 1,N ) .EQ. ' ' ) CYCLE

C.............  Write message stating the pols/emission-types being processed
            CALL POLMESG( NGSZ, EANAM2D( 1,N ) )

C.............  Set up logical arrays that indicate which pollutants/activities
C               are day-specific and which are hour-specific.
C.............  Also set flag for which hour-specific pollutants/activities
C               are actually diurnal profiles instead of emissions
            LDSPOA = .FALSE.   ! array
            DO I = 1, NDYPOA
                J = INDEX1( DYPNAM( I ), NGSZ,  EANAM2D( 1,N ) )
                LDSPOA( J ) = .TRUE.
            END DO

            LHSPOA = .FALSE.   ! array
            LHPROF = .FALSE.   ! array
            DO I = 1, NHRPOA
                J = INDEX1( HRPNAM( I ), NGSZ,  EANAM2D( 1,N ) )
                LHSPOA( J ) = .TRUE.

                CALL UPCASE( HRPDSC( I ) )
                K = INDEX( HRPDSC( I ), 'PROFILE' )
                IF( K .GT. 0 ) LHPROF( J ) = .TRUE.
            END DO

C.............  Initialize emissions, activities, and other arrays for this
C               pollutant/emission-type group
            TMAT  = 0.
            MDEX  = IMISS3
            WDEX  = IMISS3
            DDEX  = IMISS3
            EMAC  = 0.
            EMACV = 0.
            EMIST = 0.
            IF( NIACT .GT. 0 ) EMFAC = IMISS3

C.............  Assign temporal profiles by source and pollutant
            CALL M3MSG2( 'Assigning temporal profiles to sources...' )

C.............  If using uniform profiles, set all temporal profile number
C               to 1; otherwise, assign profiles with cross-reference info
            IF( NFLAG ) THEN
                MDEX = 1
                WDEX = 1
                DDEX = 1

            ELSE
                CALL ASGNTPRO( NGSZ, EANAM2D( 1,N ), TREFFMT )

            END IF
C.............  Read in pollutant emissions or activities from inventory for 
C               current group
            DO I = 1, NGSZ

                EBUF = EANAM2D( I,N )
                CBUF = ALLIN2D( I,N )
                L1   = LEN_TRIM( CBUF )

C.................  Skip blanks that can occur when NGRP > 1
                IF ( CBUF .EQ. ' ' ) CYCLE

C.................  Read the emissions data in either map format
C                   or the old format.
                CALL RDMAPPOL( NSRC, 1, 1, CBUF, EMAC( 1,I ) )

C...............  If there are any missing values in the data, give an
C                 error to avoid problems in genhemis routine
                RTMP = MINVAL( EMAC( 1:NSRC,I ) )
                IF( RTMP .LT. 0 ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Missing or negative emission '//
     &                     'value(s) in inventory for "' // 
     &                     CBUF( 1:L1 ) // '".'
                    CALL M3MSG2( MESG )
                END IF

C.................  If pollutant name is average day-based, remove the
C                   prefix from the input pollutant name
                K = INDEX1( CBUF, NIPPA, EAREAD )
                J = INDEX( CBUF, AVEDAYRT )
                IF( J .GT. 0 ) THEN
                    CBUF = CBUF( CPRTLEN3+1:L1 )
                    ALLIN2D( I,N ) = CBUF
                    EAREAD ( K )   = CBUF
                END IF

            END DO

C.............  Abort if error found
            IF( EFLAG ) THEN
                MESG = 'Problem with input data.'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  For each time step and pollutant or emission type in current 
C               group, generate hourly emissions, and write layer-1 emissions
C               file (or all data).
            JDATE = SDATE
            JTIME = STIME

C.............  Write supplemental temporal profiles file
            CALL WRTSUP( PDEV, NSRC, NGSZ, EANAM2D( 1,N ) )
        END DO          ! End loop on pollutant groups N


C.........  Exit program with normal completion
        CALL M3MSG2( 'NORMAL COMPLETION OF '// PROGNAME)

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats.............94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94030   FORMAT( I3 )

94050   FORMAT( A, 1X, I2.2, A, 1X, A, 1X, I6.6, 1X,
     &          A, 1X, I3.3, 1X, A, 1X, I3.3, 1X, A   )
     
94070   FORMAT( A, I5, A )

        END SUBROUTINE PRE_TEMPORAL

