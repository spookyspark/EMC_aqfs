
        SUBROUTINE WMRGEMIS( VNAME, V, JDATE, JTIME )

C***********************************************************************
C  subroutine WMRGEMIS body starts at line
C
C  DESCRIPTION:
C      The purpose of this subroutine is to write out all NetCDF files
C      coming from the merge program.  It is expected that this routine
C      will be called for each time step.
C
C  PRECONDITIONS REQUIRED:  
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C       Created 3/99 by M. Houyoux
C       01/05 David Wong
C         -- Introduced a new variable KP in argument list since
C            variable PEMGRD has been changed from 2D to 3D
C         -- Called SAFE_WRITE3 with respect to a particular species
C            for variable PEMGRD
C         -- Omitted writing PEMGRD to a file
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id: wmrgemis.f,v 1.10 2004/07/26 14:08:39 cseppan Exp $
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
C Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/smkmerge/wmrgemis.f,v $
C Last updated: $Date: 2004/07/26 14:08:39 $ 
C
C****************************************************************************

C.........  MODULES for public variables
C.........  This module contains the major data structure and control flags
        USE MODMERGE, ONLY: AFLAG, BFLAG, MFLAG, PFLAG, XFLAG, SFLAG,
     &                      ANMSPC, BNMSPC, MNMSPC, PNMSPC,
     &                      AEMNAM, BEMNAM, MEMNAM, PEMNAM,  
     &                      ANIPOL,         MNIPPA, PNIPOL, 
     &                      AEINAM,         MEANAM, PEINAM,
     &                      AONAME, BONAME, MONAME, PONAME, TONAME, 
     &                      AEMGRD, BEMGRD, MEMGRD, PEMGRD, TEMGRD,
     &                      LGRDOUT, PINGFLAG, PINGNAME

C.........  This module contains arrays for plume-in-grid and major sources
        USE MODELEV, ONLY: PGRPEMIS

        IMPLICIT NONE

C.........  INCLUDES:
        
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file desc. data structures
        INCLUDE 'SETDECL.EXT'   !  FileSetAPI variables and functions

C.........  EXTERNAL FUNCTIONS and their descriptions:
        
        CHARACTER(2)    CRLF
        INTEGER         INDEX1

        EXTERNAL        CRLF , INDEX1

C.........  SUBROUTINE ARGUMENTS
        CHARACTER(*), INTENT (IN) :: VNAME   ! variable name to output
        INTEGER     , INTENT (IN) :: V       ! variable index
        INTEGER     , INTENT (IN) :: JDATE   ! Julian date to output (YYYYDDD)
        INTEGER     , INTENT (IN) :: JTIME   ! time to output (HHMMSS)

C.........  Other local variables
        INTEGER         J

        LOGICAL      :: AOUTFLAG = .FALSE.  ! true: output area sources
        LOGICAL      :: BOUTFLAG = .FALSE.  ! true: output biogenic sources
        LOGICAL      :: MOUTFLAG = .FALSE.  ! true: output mobile sources
        LOGICAL      :: POUTFLAG = .FALSE.  ! true: output point sources

        CHARACTER(IOVLEN3) FILNAM       ! tmp logical file name
        CHARACTER(300)     MESG         ! message buffer

        CHARACTER(16) :: PROGNAME = 'WMRGEMIS' ! program name

C***********************************************************************
C   begin body of subroutine WMRGEMIS

C.........  Initialize output flags
        AOUTFLAG = .FALSE.
        BOUTFLAG = .FALSE.
        MOUTFLAG = .FALSE.
        POUTFLAG = .FALSE.

C.........  Determine the source categories that are valid for output
C.........  If the subroutine call is for speciated output, use different
C           indicator arrays for determining output or not.
        IF( SFLAG ) THEN

            IF( LGRDOUT .AND. AFLAG ) THEN
                J = INDEX1( VNAME, ANMSPC, AEMNAM )
                AOUTFLAG = ( J .GT. 0 )
            END IF

            IF( LGRDOUT .AND. BFLAG ) THEN
                J = INDEX1( VNAME, BNMSPC, BEMNAM )
                BOUTFLAG = ( J .GT. 0 )
            END IF

            IF( LGRDOUT .AND. MFLAG ) THEN
                J = INDEX1( VNAME, MNMSPC, MEMNAM )
                MOUTFLAG = ( J .GT. 0 )
            END IF

            IF( ( LGRDOUT .OR. PINGFLAG ) .AND. PFLAG ) THEN
                J = INDEX1( VNAME, PNMSPC, PEMNAM )
                POUTFLAG = ( J .GT. 0 )
            END IF

C.........  Non-speciated (it's not possible to have biogenics w/o speciation)
        ELSE  

            IF( LGRDOUT .AND. AFLAG ) THEN
                J = INDEX1( VNAME, ANIPOL, AEINAM )
                AOUTFLAG = ( J .GT. 0 )
            END IF

            IF( LGRDOUT .AND. MFLAG ) THEN
                J = INDEX1( VNAME, MNIPPA, MEANAM )
                MOUTFLAG = ( J .GT. 0 )
            END IF

            IF( ( LGRDOUT .OR. PINGFLAG ) .AND. PFLAG ) THEN
                J = INDEX1( VNAME, PNIPOL, PEINAM )
                POUTFLAG = ( J .GT. 0 )
            END IF            

        END IF

C.........  For area sources, output file...
        IF( AOUTFLAG ) CALL SAFE_WRITE3( AONAME, AEMGRD )

C.........  For biogenic, output file...
        IF( BOUTFLAG ) 
     &      CALL SAFE_WRITE3( BONAME, BEMGRD )

C.........  For mobile sources, output file...
        IF( MOUTFLAG ) CALL SAFE_WRITE3( MONAME, MEMGRD )

C.........  For point sources, output file...
c       IF( POUTFLAG ) CALL SAFE_WRITE3( PONAME, PEMGRD (1,1,v) )

C.........  For plume-in-grid, output file...
        IF( POUTFLAG .AND. PINGFLAG ) 
     &      CALL SAFE_WRITE3( PINGNAME, PGRPEMIS )

C.........  For multiple source categories, output totals file...
        IF( LGRDOUT .AND. XFLAG ) CALL SAFE_WRITE3( TONAME, TEMGRD )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats.............94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

C*****************  INTERNAL SUBPROGRAMS  ******************************

        CONTAINS

C.............  This internal subprogram uses WRITE3 and exits gracefully
C               if a write error occurred
            SUBROUTINE SAFE_WRITE3( FILNAM, EMDATA )

            INCLUDE 'SETDECL.EXT'   !  FileSetAPI variables and functions

            CHARACTER(*), INTENT (IN) :: FILNAM
            REAL        , INTENT (IN) :: EMDATA( * )

C.......................................................................

            IF( .NOT. WRITESET( FILNAM, VNAME, ALLFILES,
     &                          JDATE, JTIME, EMDATA ) ) THEN

                MESG = 'Could not write "' // VNAME //
     &                 '" to file "'// FILNAM // '"'
                CALL M3EXIT( PROGNAME, JDATE, JTIME, MESG, 2 )

            END IF

            RETURN

            END SUBROUTINE SAFE_WRITE3

        END SUBROUTINE WMRGEMIS
