
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
C $Header: /project/work/rep/CCTM/src/util/util/cksummer.F,v 1.18 2003/09/12 15:17:55 yoj Exp $ 

C what(1) key, module and SID; SCCS file; date and time of last delta:
C @(#)cksummer.F        1.1 /project/mod3/CMAQ/src/util/util/SCCS/s.cksummer.F 03 Jun 1997 12:08:53

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE CKSUMMER ( SCIPROC, JDATE, JTIME )

C Function:
C     Sum concentrations over entire grid.

C Revision History:
C    Original version ???
C    2 October, 1998 by Al Bourgeois at LM: 1 implementation
C          and fix bug by SAVEing DEVNAME.

C    1/22/99 David Wong at LM: compute global sum for variables: GC_CKSUM,
C                              AE_CKSUM, NR_CKSUM, and TR_CKSUM

C    1/28/99 David Wong at LM: compute global sum for GCELLS

C    15 Dec 00 J.Young: move CGRID_MAP into f90 module
C                       GLOBAL_RSUM -> Dave Wong's f90 stenex GLOBAL_SUM
C    Jeff - Feb 01 - assumed shape arrays
C    23 Mar 01 J.Young: Use HGRD_DEFN
C    31 May 02 J.Young: REAL*8 reduction accumulator (avoid 32 bit roundoff)
C    31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                       domain specifications in one module
C-----------------------------------------------------------------------

      USE CGRID_DEFN            ! inherits GRID_CONF and CGRID_SPCS
      USE WVEL_DEFN             ! derived vertical velocity component
!     USE SE_MODULES              ! stenex
!     USE SUBST_GLOBAL_SUM_MODULE    ! stenex

      IMPLICIT NONE

!     INCLUDE SUBST_HGRD_ID     ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID     ! vertical dimensioning parameters
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_SPC.EXT"      ! gas chemistry species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"      ! aerosol species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_SPC.EXT"      ! non-reactive species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/TR_SPC.EXT"      ! tracer species table
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"     ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"      ! I/O definitions and declarations

      CHARACTER( * ) SCIPROC    ! science process name
      INTEGER      JDATE        ! current model date, coded YYYYDDD
      INTEGER      JTIME        ! current model time, coded HHMMSS

C Parameters:

      REAL, PARAMETER :: CZIP = 0.0

C Local variables:
 
      LOGICAL, SAVE :: FIRSTIME = .TRUE.
      INTEGER, SAVE :: LOGDEV         ! FORTRAN unit number for log file

      CHARACTER( 16 ), SAVE :: PNAME = 'CKSUMMER'
      CHARACTER( 96 ) :: XMSG = ' '
!     CHARACTER( 16 ), SAVE :: OUTNAME = 'FLOOR_FILE'
      CHARACTER( 16 ) :: APPL = 'CTM_APPL'
      CHARACTER( 48 ) :: EQNAME
      CHARACTER(  6 ) :: PRESTR = 'FLOOR_'
      CHARACTER(  3 ) :: CMYPE
      CHARACTER( 96 ), SAVE :: DEVNAME ! Name of output file.

      INTEGER, SAVE :: OUTDEV    ! FORTRAN unit number for neg conc ascii file

      INTEGER, EXTERNAL :: GETEFILE, TRIMLEN, SETUP_LOGDEV
 
      LOGICAL ::  RDONLY = .FALSE.
      LOGICAL ::  FMTTED = .TRUE.
      INTEGER     STATUS       !  ENVSTR status

      INTEGER     S, V, L, C, R
      REAL( 8 ) :: DBL_CKSUM
      REAL         GC_CKSUM, AE_CKSUM, NR_CKSUM, TR_CKSUM
!     REAL, SAVE :: GCELLS
      REAL, SAVE :: LCELLS

      LOGICAL, SAVE :: OPFLG = .TRUE.               ! open file flag
      LOGICAL     EXFLG                             ! write header flag

C-----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
!        LOGDEV = INIT3()
         LOGDEV = SETUP_LOGDEV()

         OUTDEV = LOGDEV

C Get CGRID offsets
         CALL CGRID_MAP( NSPCSD, GC_STRT, AE_STRT, NR_STRT, TR_STRT )
!        GCELLS = SE_GLOBAL_SUM ( FLOAT( MY_NCOLS * MY_NROWS * NLAYS ) )
         LCELLS = FLOAT( MY_NCOLS * MY_NROWS * NLAYS )

!        CALL ENVSTR( OUTNAME, 'Floor file', PNAME, DEVNAME, STATUS )
!        IF ( STATUS .NE. 0 ) WRITE( LOGDEV,'(5X, A)' ) 'Floor file'
!        IF ( STATUS .EQ. 1 ) THEN
!           XMSG = 'Environment variable improperly formatted'
!           CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
!           ELSE IF ( STATUS .EQ. -1 ) THEN
!           XMSG = 'Environment variable set, but empty ... Using default:'
!           WRITE( LOGDEV,'(5X, A, I9)' ) XMSG, JTIME
!           ELSE IF ( STATUS .EQ. -2 ) THEN
!           XMSG = 'Environment variable not set ... Using default:'
!           WRITE( LOGDEV,'(5X, A, I9)' ) XMSG, JTIME
!           END IF
         CALL NAMEVAL ( APPL, EQNAME )
         WRITE( CMYPE,'(I3.3)' ) MYPE
         DEVNAME = PRESTR // CMYPE // '.' // EQNAME( 1:TRIMLEN( EQNAME ) )

         END IF

      EXFLG = .TRUE.

      DBL_CKSUM = 0.0
      IF ( N_GC_SPC .GT. 0 ) THEN

         V = 0
         DO S = GC_STRT, GC_STRT - 1 + N_GC_SPC
            V = V + 1
            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     DBL_CKSUM = DBL_CKSUM + CGRID( C,R,L,S )
                     IF ( CGRID( C,R,L,S ) .LT. CZIP ) THEN
                        IF ( EXFLG ) THEN
                           EXFLG = .FALSE.
!                          IF ( OPFLG ) THEN   ! open output ASCII file
!                             OPFLG = .FALSE.
!                             OUTDEV = GETEFILE ( DEVNAME, RDONLY, FMTTED, PNAME )
!                             END IF
                           WRITE( OUTDEV,1001 ) CZIP, SCIPROC
                           END IF
                        WRITE( OUTDEV,1003 ) JDATE, JTIME, C, R, L, S,
     &                                       GC_SPC( V ), CGRID( C,R,L,S )
                        CGRID( C,R,L,S ) = CZIP
                        END IF
                     END DO
                  END DO
               END DO
            END DO

         GC_CKSUM = DBL_CKSUM
 
!        WRITE( LOGDEV,1005 ) 'Gas chemistry', SCIPROC, CKSUM

         ELSE

         GC_CKSUM = 0.0
 
         END IF
     
      DBL_CKSUM = 0.0
      IF ( N_AE_SPC .GT. 0 ) THEN

         V = 0
         DO S = AE_STRT, AE_STRT - 1 + N_AE_SPC
            V = V + 1
            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     DBL_CKSUM = DBL_CKSUM + CGRID( C,R,L,S )
                     IF ( CGRID( C,R,L,S ) .LT. CZIP ) THEN
                        IF ( EXFLG ) THEN
                           EXFLG = .FALSE.
!                          IF ( OPFLG ) THEN   ! open output ASCII file
!                             OPFLG = .FALSE.
!                             OUTDEV = GETEFILE ( DEVNAME, RDONLY, FMTTED, PNAME )
!                             END IF
                           WRITE( OUTDEV,1001 ) CZIP, SCIPROC
                           END IF
                        WRITE( OUTDEV,1003 ) JDATE, JTIME, C, R, L, S,
     &                                       AE_SPC( V ), CGRID( C,R,L,S )
                        CGRID( C,R,L,S ) = CZIP
                        END IF
                     END DO
                  END DO
               END DO
            END DO

         AE_CKSUM = DBL_CKSUM
  
!        WRITE( LOGDEV,1005 ) '      Aerosol', SCIPROC, CKSUM

         ELSE

         AE_CKSUM = 0.0
 
         END IF
     
      DBL_CKSUM = 0.0
      IF ( N_NR_SPC .GT. 0 ) THEN
 
         V = 0
         DO S = NR_STRT, NR_STRT - 1 + N_NR_SPC
            V = V + 1
            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     DBL_CKSUM = DBL_CKSUM + CGRID( C,R,L,S )
                     IF ( CGRID( C,R,L,S ) .LT. CZIP ) THEN
                        IF ( EXFLG ) THEN
                           EXFLG = .FALSE.
!                          IF ( OPFLG ) THEN   ! open output ASCII file
!                             OPFLG = .FALSE.
!                             OUTDEV = GETEFILE ( DEVNAME, RDONLY, FMTTED, PNAME )
!                             END IF
                           WRITE( OUTDEV,1001 ) CZIP, SCIPROC
                           END IF
                        WRITE( OUTDEV,1003 ) JDATE, JTIME, C, R, L, S,
     &                                       NR_SPC( V ), CGRID( C,R,L,S )
                        CGRID( C,R,L,S ) = CZIP
                        END IF
                     END DO
                  END DO
               END DO
            END DO

         NR_CKSUM = DBL_CKSUM
  
!        WRITE( LOGDEV,1005 ) ' Non-reactive', SCIPROC, CKSUM

         ELSE

         NR_CKSUM = 0.0
 
         END IF
     
      DBL_CKSUM = 0.0

      IF ( W_VEL ) THEN
         IF ( SCIPROC .EQ. 'ZADV' ) THEN
            S = NSPCSD + 1
            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
!                    DBL_CKSUM = DBL_CKSUM + CGRID_X( C,R,L,S )
                     DBL_CKSUM = DBL_CKSUM + WVEL( C,R,L )
                     END DO
                  END DO
               END DO
            ELSE
            DBL_CKSUM = 0.0
            END IF
 
         ELSE

         V = 0
!        DO S = TR_STRT, TR_STRT - 1 + N_TR_SPC
         DO S = GC_STRT - 1 + N_GC_SPCD, N_GC_SPCD
            V = V + 1
            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     DBL_CKSUM = DBL_CKSUM + CGRID( C,R,L,S )
                     IF ( CGRID( C,R,L,S ) .LT. CZIP ) THEN
                        IF ( EXFLG ) THEN
                           EXFLG = .FALSE.
!                          IF ( OPFLG ) THEN   ! open output ASCII file
!                             OPFLG = .FALSE.
!                             OUTDEV = GETEFILE ( DEVNAME, RDONLY, FMTTED, PNAME )
!                             END IF
                           WRITE( OUTDEV,1001 ) CZIP, SCIPROC
                           END IF
                        WRITE( OUTDEV,1003 ) JDATE, JTIME, C, R, L, S,
!    &                                       TR_SPC( V ), CGRID( C,R,L,S )
     &                                       'RHO_J',     CGRID( C,R,L,S )
                        CGRID( C,R,L,S ) = CZIP
                        END IF
                     END DO
                  END DO
               END DO
            END DO

         END IF   ! W_VEL

         TR_CKSUM = DBL_CKSUM
  
!        WRITE( LOGDEV,1005 ) '       Tracer', SCIPROC, CKSUM
 
!        ELSE

!        TR_CKSUM = 0.0
 
!        END IF
     
!     IF ( N_TR_SPC .EQ. 0 ) THEN
!        WRITE( LOGDEV,1005 ) SCIPROC,
!    &                        SE_GLOBAL_SUM( GC_CKSUM ) / GCELLS,
!    &                        SE_GLOBAL_SUM( AE_CKSUM ) / GCELLS,
!    &                        SE_GLOBAL_SUM( NR_CKSUM ) / GCELLS
!        ELSE
         WRITE( LOGDEV,1007 ) SCIPROC,
!    &                        SE_GLOBAL_SUM( GC_CKSUM ) / GCELLS,
!    &                        SE_GLOBAL_SUM( AE_CKSUM ) / GCELLS,
!    &                        SE_GLOBAL_SUM( NR_CKSUM ) / GCELLS,
!    &                        SE_GLOBAL_SUM( TR_CKSUM ) / GCELLS
     &                        GC_CKSUM / LCELLS,
     &                        AE_CKSUM / LCELLS,
     &                        NR_CKSUM / LCELLS,
     &                        TR_CKSUM / LCELLS
!        END IF

      RETURN

1001  FORMAT(  5X, 'Concentrations less than, but reset to', 1PE11.3,
     &         1X, 'in', A16
     &       / 9X, 'Date:Time',
     &         5X, 'Col', 2X, 'Row', 1X, 'Layer', 1X, 'Species',
     &         13X, 'Value before reset' )

c003  FORMAT( 1X, 4I7, 9X, 1PE11.3)
1003  FORMAT( 5X, I8, ':', I6.6, 4I5, 1X, '(', A16, ')', 1PE12.3)

c005  FORMAT( 3X, A13, 1X, 'Conc field cksum after science process:',
1005  FORMAT( 1X, 'after',
     &        1X, A09, 1X, 'G ', 1PE13.7,
     &                 1X, 'A ', 1PE13.7,
     &                 1X, 'N ', 1PE13.7 )

1007  FORMAT( 1X, 'after',
     &        1X, A09, 1X, 'G ', 1PE13.7,
     &                 1X, 'A ', 1PE13.7,
     &                 1X, 'N ', 1PE13.7,
     &                 1X, 'T ', 1PE13.6 ) ! to allow negatives

      END
