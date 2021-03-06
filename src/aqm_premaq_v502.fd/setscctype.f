
        LOGICAL FUNCTION SETSCCTYPE( TSCC )

C***********************************************************************
C  function body starts at line 68
C
C  DESCRIPTION:
C       Checks SCC code and resets parameters based on type
C
C  PRECONDITIONS REQUIRED:
C       CATEGORY type must be set in MODINFO
C       SCC must be 10-digits long and right-justified
C       8-digit SCCs must start with '00'
C
C  SUBROUTINES AND FUNCTIONS CALLED: none
C
C  REVISION  HISTORY:
C     7/03: Created by C. Seppanen
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id: setscctype.f,v 1.4 2004/06/21 17:28:26 cseppan Exp $
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
C Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/lib/setscctype.f,v $
C Last updated: $Date: 2004/06/21 17:28:26 $ 
C
C***********************************************************************

C.........  MODULES for public variables
C.........  This module contains the information about the source category
        USE MODINFO, ONLY: LSCCEND, RSCCBEG, SCCLEV1, SCCLEV2,
     &                     SCCLEV3, CATEGORY
            
        IMPLICIT NONE
       
C........  Function arguments
        CHARACTER(*), INTENT (IN) :: TSCC   ! SCC code

C........  Local variables and their descriptions:
        
        CHARACTER(16) :: PROGNAME = 'SETSCCTYPE' ! program name
        
C***********************************************************************
C   begin body of function SETSCCTYPE

        SETSCCTYPE = .FALSE.

C.........  Don't change any parameters if category is mobile
        IF( CATEGORY == 'MOBILE' ) RETURN

C.........  Check if first two digits of SCC are zero
        IF( TSCC( 1:2 ) == '00' ) THEN

C.............  Only set new values if needed and set flag
            IF( LSCCEND /= 5 ) THEN
                SETSCCTYPE = .TRUE.  ! flag indicates that values have been changed
                LSCCEND = 5
                RSCCBEG = 6
                SCCLEV1 = 3
                SCCLEV2 = 5
                SCCLEV3 = 8
            END IF
        ELSE
            IF( LSCCEND /= 7 ) THEN
                SETSCCTYPE = .TRUE.
                LSCCEND = 7
                RSCCBEG = 8
                SCCLEV1 = 2
                SCCLEV2 = 4
                SCCLEV3 = 7
            END IF
        END IF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )  
      
C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )
       
        END FUNCTION SETSCCTYPE
