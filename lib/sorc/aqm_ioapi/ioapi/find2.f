
C.........................................................................
C Version "@(#)$Header: /env/proj/archive/cvs/ioapi/./ioapi/src/find2.f,v 1.2 2000/11/28 21:22:41 smith_w Exp $"
C EDSS/Models-3 I/O API.  Copyright (C) 1992-1999 MCNC
C Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
C See file "LGPL.txt" for conditions of use.
C.........................................................................

        INTEGER FUNCTION FIND2( K1, K2, N, LIST1, LIST2 )

C***********************************************************************
C  function body starts at line  53
C
C  RETURNS:
C       subscript at which the targeted key-pair appears, or 
C       -1 in case of failure.
C       EXAMPLE:  search for <ID7,ID3> ASC-pair in table of ASC values
C       (where ID7 is leading-7 digits and ID3 is trailing 3 digits
C       in a 10-digit Area Source Code).
C
C  PRECONDITIONS REQUIRED:
C       Sorted table <N,LIST1,LIST2> for searching
C
C  SUBROUTINES AND FUNCTIONS CALLED:  none
C
C  REVISION  HISTORY:
C       prototype 2/28/95 by CJC
C
C***********************************************************************

      IMPLICIT NONE


C...........   ARGUMENTS and their descriptions:
        
        INTEGER  K1             !  first  key
        INTEGER  K2             !  second key
        INTEGER  N              !  table size
        INTEGER  LIST1( N )     !  table to search for K1
        INTEGER  LIST2( N )     !  table to search for K2


C...........   SCRATCH LOCAL VARIABLES and their descriptions:
        
        INTEGER  LO
        INTEGER  HI
        INTEGER  M


C***********************************************************************
C   begin body of function  FIND2

        LO = 1
        HI = N
        
11      CONTINUE
            
            IF ( LO .GT. HI ) THEN
            
                FIND2 = -1
                RETURN
                
            END IF
           
            M = ( LO + HI ) / 2
            IF ( K1 .GT. LIST1( M ) ) THEN
                LO = M + 1
                GO TO  11
            ELSE IF ( K1 .LT. LIST1( M ) ) THEN
                HI = M - 1
                GO TO  11
            ELSE IF ( K2 .GT. LIST2( M ) ) THEN
                LO = M + 1
                GO TO  11
            ELSE IF ( K2 .LT. LIST2( M ) ) THEN
                HI = M - 1
                GO TO  11
            END IF          !  end of bin search loop for this <K1,K2>
        
        
        FIND2 = M
        RETURN
        END
