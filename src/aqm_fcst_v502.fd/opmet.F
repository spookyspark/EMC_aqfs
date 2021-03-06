
!------------------------------------------------------------------------!
!  The Community Multiscale Air Quality (CMAQ) system software is in     !
!  continuous development by various groups and is based on information  !
!  from these groups: Federal Government employees, contractors working  !
!  within a United States Government contract, and non-Federal sources   !
!  including research institutions.  These groups give the Government    !
!  permission to use, prepare derivative works of, and distribute copies !
!  of their work in the CMAQ system to the public and to permit others   !
!  to do so.  The United States Environmental Protection Agency          !
!  therefore grants similar permission to use the CMAQ system software,  !
!  but users are requested to provide copies of derivative works or      !
!  products designed to operate in the CMAQ system to the United States  !
!  Government without restrictions as to use by others.  Software        !
!  that is used with the CMAQ system but distributed under the GNU       !
!  General Public License or the GNU Lesser General Public License is    !
!  subject to their copyright restrictions.                              !
!------------------------------------------------------------------------!


C RCS file, release, date & time of last delta, author, state, [and locker]
C $Header: /project/yoj/arc/CCTM/src/vdiff/acm2/opmet.F,v 1.4 2011/10/21 16:11:46 yoj Exp $
 
C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%
 
C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE OPMET ( JDATE, JTIME, CONVPA )

      USE UTILIO_DEFN

      IMPLICIT NONE

      INCLUDE SUBST_FILES_ID  ! file name parameters

      INTEGER      JDATE      ! current model date, coded YYYYDDD
      INTEGER      JTIME      ! current model time, coded HHMMSS
      REAL         CONVPA     ! conversion factor to pressure in Pascals

C External Functions: None

C Local variables:

      CHARACTER( 16 ) :: PNAME = 'OPMET'
      CHARACTER( 96 ) :: XMSG = ' '
      CHARACTER( 16 ) :: UNITSCK

      INTEGER      V

C-----------------------------------------------------------------------

C Open the met files
 
      IF ( .NOT. OPEN3( MET_CRO_3D, FSREAD3, PNAME ) ) THEN
         XMSG = 'Could not open '// MET_CRO_3D // ' file'
         CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

      IF ( .NOT. OPEN3( MET_CRO_2D, FSREAD3, PNAME ) ) THEN
         XMSG = 'Could not open '// MET_CRO_2D // ' file'
         CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

      IF ( .NOT. DESC3( MET_CRO_2D ) ) THEN
         XMSG = 'Could not get ' // MET_CRO_2D // ' file description'
         CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
         END IF         !  error abort if if desc3() failed

      V = INDEX1( 'PRSFC', NVARS3D, VNAME3D )
      IF ( V .NE. 0 ) THEN
         UNITSCK = UNITS3D( V ) 
         ELSE
         XMSG = 'Could not get variable PRSFC from ' // MET_CRO_2D
     &        // ' Try for variable PSTAR'
         CALL M3MESG( XMSG )
         V = INDEX1( 'PSTAR', NVARS3D, VNAME3D )
         IF ( V .NE. 0 ) THEN
            UNITSCK = UNITS3D( V ) 
            ELSE
            V = INDEX1( 'PSTAR', NVARS3D, VNAME3D )
            XMSG = 'Could not get variable PSTAR from ' // MET_CRO_2D
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
            END IF
         END IF

      IF (UNITSCK .EQ. 'PASCAL' .OR. UNITSCK .EQ. 'pascal' .OR.
     &    UNITSCK .EQ. 'Pascal' .OR. UNITSCK .EQ. 'PA'     .OR.
     &    UNITSCK .EQ. 'pa'     .OR. UNITSCK .EQ. 'Pa') THEN
         CONVPA = 1.0
         ELSE IF (UNITSCK .EQ. 'MILLIBAR' .OR. UNITSCK .EQ. 'millibar' .OR.
     &            UNITSCK .EQ. 'Millibar' .OR. UNITSCK .EQ. 'MB'       .OR.
     &            UNITSCK .EQ. 'mb'       .OR. UNITSCK .EQ. 'Mb') THEN
         CONVPA = 1.0E-02
         ELSE IF (UNITSCK .EQ. 'CENTIBAR' .OR. UNITSCK .EQ. 'centibar' .OR.
     &            UNITSCK .EQ. 'Centibar' .OR. UNITSCK .EQ. 'CB'       .OR.
     &            UNITSCK .EQ. 'cb'       .OR. UNITSCK .EQ. 'Cb') THEN
         CONVPA = 1.0E-03
         ELSE
         XMSG = 'Units incorrect on ' // MET_CRO_2D
         CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
         END IF
                       
      RETURN
      END
