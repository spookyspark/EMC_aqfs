
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/hadv/yamo/rdbcon.F,v 1.1.1.1 2005/09/09 18:56:06 sjr Exp $
 
C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%
 
C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE RDBCON ( JDATE, JTIME, TSTEP, LVL, BCON )

C-----------------------------------------------------------------------
C Function:
C   Read boundary concentrations data for advection and couple with
C   SqRDMT, Where SqRDMT = Sq. Root [det ( metric tensor )]
C                        = Vertical Jacobian / (map scale factor)**2
C   Load Air Density X SqRDMT = RHOJ into last BCON slot for advection

C Preconditions:

C Subroutines and Functions Called:
C   INTERPX, PINTERPB, M3EXIT, TRIMLEN, ADVBC_MAP, TIME2SEC, SEC2TIME, NEXTIME

C Revision History:
C   Jeff - Aug 1997 Based on beta version, keep in ppmV units (not aerosols)
C   Jeff - Dec 97 - add CMIN
C   Jeff - Apr 98 - fix conversion/coupling for aerosol number species
C   Jeff - Apr 01 - dyn alloc - Use PINTERB for boundary data - assume the met
C                   data could come from a larger file, but not the conc cata
C   23 Jun 03 J.Young: for layer dependent advection tstep
C   31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                      domain specifications in one module
C-----------------------------------------------------------------------

      USE GRID_CONF            ! horizontal & vertical domain specifications

      IMPLICIT NONE
 
C Includes:
 
!     INCLUDE SUBST_HGRD_ID    ! horizontal dimensioning parameters
!     INCLUDE SUBST_VGRD_ID    ! vertical dimensioning parameters
 
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_SPC.EXT"     ! gas chemistry species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"     ! aerosol species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_SPC.EXT"     ! non-reactive species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/TR_SPC.EXT"     ! tracer species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_ADV.EXT"     ! gas chem advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_ADV.EXT"     ! aerosol advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_ADV.EXT"     ! non-react advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/TR_ADV.EXT"     ! tracer advection species and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/GC_ICBC.EXT"    ! gas chem ic/bc surrogate names and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_ICBC.EXT"    ! aerosol ic/bc surrogate names and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/NR_ICBC.EXT"    ! non-react ic/bc surrogate names and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/TR_ICBC.EXT"    ! tracer ic/bc surrogate names and map table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"      ! constants
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/PARMS3.EXT"    ! I/O parameters definitions
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/FDESC3.EXT"    ! file header data structure
      INCLUDE "/meso/save/wx20dw/tools/ioapi_3/ioapi/fixed_src/IODECL3.EXT"     ! I/O definitions and declarations
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/FILES_CTM.EXT"   ! file name parameters

C Arguments:
 
      INTEGER      JDATE       ! current model date, coded YYYYDDD
      INTEGER      JTIME       ! current model time, coded HHMMSS
      INTEGER      TSTEP       ! timestep
      INTEGER      LVL         ! layer
!     REAL         BCON( NBNDY,NLAYS,* )  ! boundary concentrations
      REAL      :: BCON( :,: ) ! boundary concentrations

C Parameters:
 
!     REAL, PARAMETER ( MAOAVO = MWAIR / AVO * 1.0E-03 ) ! Ma/avo X Kg/g
      REAL, PARAMETER :: KGPMG = 1.0E-09  ! Kg / micro-gram
 
      INTEGER, PARAMETER :: N_SPC_ADV = N_GC_ADV
     &                                + N_AE_ADV
     &                                + N_NR_ADV
     &                                + N_TR_ADV
     &                                + 1

      REAL, PARAMETER :: CMIN = 1.0E-30

      CHARACTER( 16 ) :: CONCMIN

C File variables:

      REAL        SQRDMT_BND( NBNDY,NLAYS )        ! boundary Jacobian
      REAL        RHOJ_BND  ( NBNDY,NLAYS )        ! mid-layer boundary RhoJ
!     REAL, ALLOCATABLE, SAVE :: SQRDMT_BND( : )   ! boundary Jacobian
!     REAL, ALLOCATABLE, SAVE :: RHOJ_BND  ( : )   ! mid-layer boundary RhoJ

      REAL, ALLOCATABLE, SAVE :: SQRDMT_BUF( :,: ) ! grid Jacobian
      REAL, ALLOCATABLE, SAVE :: RHOJ_BUF  ( :,: ) ! mid-layer grid RhoJ

      REAL, ALLOCATABLE, SAVE :: BBUF    ( :,:,: ) ! bcon file buffer

C External Functions not declared in IODECL3.EXT:
 
      INTEGER, EXTERNAL :: TRIMLEN, SEC2TIME, TIME2SEC
      LOGICAL, EXTERNAL :: PINTERPB

C Local variables:

      CHARACTER( 16 ) :: PNAME = 'RDBCON'
      CHARACTER( 16 ) :: VNAME

      LOGICAL, SAVE :: FIRSTIME = .TRUE.

      CHARACTER( 16 ) :: BLNK = '    '
      CHARACTER( 16 ), SAVE :: BCNAME( N_SPC_ADV )  ! BC name for adv species
      REAL, SAVE :: BCFAC( N_SPC_ADV )              ! Scale factor for BCs

      CHARACTER( 96 ) :: XMSG = ' '

      INTEGER   MDATE             ! mid-advection date
      INTEGER   MTIME             ! mid-advection time
      INTEGER   STEP              ! advection time step in seconds

      INTEGER   BND, VAR, SPC     ! loop counters
      INTEGER   COL, ROW          ! loop counters
      INTEGER   STRT, FINI
      INTEGER   ALLOCSTAT

      INTEGER   COUNT             ! Counter for constructing boundary arrays

      INTEGER   GXOFF, GYOFF      ! global origin offset from file
      LOGICAL, SAVE :: WINDOW = .FALSE. ! posit same file and global
                                        ! processing domain
C for INTERPX
      INTEGER, SAVE :: STRTCOL,   ENDCOL,   STRTROW,   ENDROW
      INTEGER       :: STRTCOLMC, ENDCOLMC, STRTROWMC, ENDROWMC

C-----------------------------------------------------------------------
 
      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.

         WRITE( CONCMIN,'(1PE8.2)' ) CMIN

C create advected species map to bc's
 
         CALL ADVBC_MAP ( CONCMIN, BCNAME, BCFAC )

         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC, ENDCOLMC, STRTROWMC, ENDROWMC )

C currently not implemented: case where only one origin component matches file's
         IF ( GXOFF .NE. 0 .AND. GYOFF .NE. 0 ) THEN
            WINDOW = .TRUE.       ! windowing from file
            STRTCOL = STRTCOLMC - 1
            ENDCOL  = ENDCOLMC  + 1
            STRTROW = STRTROWMC - 1
            ENDROW  = ENDROWMC  + 1
            ELSE
            STRTCOL = STRTCOLMC
            ENDCOL  = ENDCOLMC
            STRTROW = STRTROWMC
            ENDROW  = ENDROWMC
            END IF

         ALLOCATE ( BBUF( NBNDY,NLAYS,SIZE( BCON,2 ) ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            XMSG = 'Failure allocating BBUF'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

!        ALLOCATE ( SQRDMT_BND( NBNDY ), STAT = ALLOCSTAT )
!        IF ( ALLOCSTAT .NE. 0 ) THEN
!           XMSG = 'Failure allocating SQRDMT_BND'
!           CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!           END IF

!        ALLOCATE ( RHOJ_BND( NBNDY ), STAT = ALLOCSTAT )
!        IF ( ALLOCSTAT .NE. 0 ) THEN
!           XMSG = 'Failure allocating RHOJ_BND'
!           CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!           END IF

         IF ( WINDOW ) THEN

            ALLOCATE ( SQRDMT_BUF( 0:MY_NCOLS+1,0:MY_NROWS+1 ),
     &                 STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = 'Failure allocating SQRDMT_BUF'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
               END IF

            ALLOCATE ( RHOJ_BUF( 0:MY_NCOLS+1,0:MY_NROWS+1 ),
     &                 STAT = ALLOCSTAT )
            IF ( ALLOCSTAT .NE. 0 ) THEN
               XMSG = 'Failure allocating RHOJ_BUF'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
               END IF

            END IF

         END IF                    ! if FIRSTIME

      MDATE  = JDATE
      MTIME  = JTIME
      STEP   = TIME2SEC( TSTEP )
      CALL NEXTIME( MDATE, MTIME, SEC2TIME( STEP / 2 ) )

C Read & interpolate boundary SqrDMT, and RhoJ

      IF ( WINDOW ) THEN

         VNAME = 'DENSA_J'
         IF ( .NOT. INTERPX ( MET_CRO_3D, VNAME, PNAME,
     &                        STRTCOL,ENDCOL, STRTROW,ENDROW, LVL,LVL,
     &                        MDATE, MTIME, RHOJ_BUF ) ) THEN
            XMSG = 'Could not read ' // VNAME // ' from ' // MET_CRO_3D
            CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF

         VNAME = 'JACOBM'
         IF ( .NOT. INTERPX ( MET_CRO_3D, VNAME, PNAME,
     &                        STRTCOL,ENDCOL, STRTROW,ENDROW, LVL,LVL,
     &                        MDATE, MTIME, SQRDMT_BUF ) ) THEN
            XMSG = 'Could not read ' // VNAME // ' from ' // MET_CRO_3D
            CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF

C Fill in DENSJ array for boundaries

         COUNT = 0
         DO ROW = 0, 0                                ! South
            DO COL = 1, MY_NCOLS+1
               COUNT = COUNT + 1
               SQRDMT_BND( COUNT,LVL ) = SQRDMT_BUF( COL,ROW )
               RHOJ_BND  ( COUNT,LVL ) = RHOJ_BUF  ( COL,ROW )
               END DO
            END DO
         DO ROW = 1, MY_NROWS+1                       ! East
            DO COL = MY_NCOLS+1, MY_NCOLS+1
               COUNT = COUNT + 1
               SQRDMT_BND( COUNT,LVL ) = SQRDMT_BUF( COL,ROW )
               RHOJ_BND  ( COUNT,LVL ) = RHOJ_BUF  ( COL,ROW )
               END DO
            END DO
         DO ROW = MY_NROWS+1, MY_NROWS+1              ! North
            DO COL = 0, MY_NCOLS
               COUNT = COUNT + 1
               SQRDMT_BND( COUNT,LVL ) = SQRDMT_BUF( COL,ROW )
               RHOJ_BND  ( COUNT,LVL ) = RHOJ_BUF  ( COL,ROW )
               END DO
            END DO
         DO ROW = 0, MY_NROWS                         ! West
            DO COL = 0, 0
               COUNT = COUNT + 1
               SQRDMT_BND( COUNT,LVL ) = SQRDMT_BUF( COL,ROW )
               RHOJ_BND  ( COUNT,LVL ) = RHOJ_BUF  ( COL,ROW )
               END DO
            END DO

         ELSE

         VNAME = 'JACOBM'
         IF ( .NOT. PINTERPB ( MET_BDY_3D, VNAME, PNAME,
     &                        MDATE, MTIME, NBNDY*NLAYS,
     &                        SQRDMT_BND ) ) THEN
            XMSG = 'Could not read' // VNAME // ' from ' // MET_BDY_3D
            CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF

         VNAME = 'DENSA_J'
         IF ( .NOT. PINTERPB ( MET_BDY_3D, VNAME, PNAME,
     &                        MDATE, MTIME, NBNDY*NLAYS,
     &                        RHOJ_BND ) ) THEN
            XMSG = 'Could not read ' // VNAME // ' from ' // MET_BDY_3D
            CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )
            END IF

         END IF   ! WINDOW

      BCON = 0.0

C Read & interpolate boundary concentrations

      SPC = 0
      STRT = 1
      FINI = N_GC_ADV
      DO 141 VAR = STRT, FINI
         SPC = SPC + 1 
         IF ( BCNAME ( VAR ) .NE. BLNK ) THEN

            IF ( .NOT. PINTERPB( BNDY_GASC_1, BCNAME( VAR ) , PNAME,
     &                          MDATE, MTIME, NBNDY*NLAYS,
     &                          BBUF( 1,1,VAR ) ) ) THEN
               XMSG = 'Could not read ' //
     &                 BCNAME( VAR )(1:TRIMLEN( BCNAME ( VAR ) ) )  //
     &                ' from ' // BNDY_GASC_1
               CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )

               ELSE   ! found bc's (PPM) on file; convert

               DO BND = 1, NBNDY
                  BCON( BND,VAR ) = BCFAC( VAR )
     &                            * BBUF( BND,LVL,VAR )
     &                            * RHOJ_BND( BND,LVL )
                  END DO
               END IF
            ELSE
            DO BND = 1, NBNDY
               BCON( BND,VAR ) = CMIN
               END DO
            END IF
141      CONTINUE

      SPC = 0
      STRT = N_GC_ADV + 1
      FINI = N_GC_ADV + N_AE_ADV
      DO 151 VAR = STRT, FINI
         SPC = SPC + 1
         IF ( BCNAME ( VAR ) .NE. BLNK ) THEN
            IF ( .NOT. PINTERPB ( BNDY_AERO_1, BCNAME( VAR ), PNAME,
     &                           MDATE, MTIME, NBNDY*NLAYS,
     &                           BBUF( 1,1,VAR ) ) ) THEN
               XMSG = 'Could not read ' //
     &                 BCNAME( VAR )(1:TRIMLEN( BCNAME ( VAR ) ) )  //
     &                ' from ' // BNDY_AERO_1
               CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )

               ELSE   ! found bc's (microgram/m**3, m**2/m**3, or number/m**3)

                      ! on file; convert
               IF ( AE_ADV( SPC )( 1:3 ) .EQ. 'NUM' ) THEN
                  DO BND = 1, NBNDY
                     BCON( BND,VAR ) = BCFAC( VAR )
!    &                               * BBUF( BND,LVL,VAR ) * MAOAVO
     &                               * BBUF( BND,LVL,VAR )
     &                               * SQRDMT_BND( BND,LVL )
                     END DO
                  ELSE IF ( AE_ADV( SPC )( 1:3 ) .EQ. 'SRF' ) THEN
                  DO BND = 1, NBNDY
                     BCON( BND,VAR ) = BCFAC( VAR )
     &                               * BBUF( BND,LVL,VAR )
     &                               * SQRDMT_BND( BND,LVL )
                     END DO
                  ELSE
                  DO BND = 1, NBNDY
                     BCON( BND,VAR ) = BCFAC( VAR )
     &                               * BBUF( BND,LVL,VAR ) * KGPMG
     &                               * SQRDMT_BND( BND,LVL )
                     END DO
                  END IF
               END IF
            ELSE

            DO BND = 1, NBNDY
               BCON( BND,VAR ) = CMIN
               END DO
            END IF
151      CONTINUE

      SPC = 0
      STRT = N_GC_ADV + N_AE_ADV + 1
      FINI = N_GC_ADV + N_AE_ADV + N_NR_ADV
      DO 161 VAR = STRT, FINI
         SPC = SPC + 1 
         IF ( BCNAME ( VAR ) .NE. BLNK ) THEN

            IF ( .NOT. PINTERPB ( BNDY_NONR_1, BCNAME ( VAR ), PNAME,
     &                           MDATE, MTIME, NBNDY*NLAYS,
     &                           BBUF( 1,1,VAR ) ) ) THEN
               XMSG = 'Could not read ' //
     &                 BCNAME( VAR )(1:TRIMLEN( BCNAME ( VAR ) ) )  //
     &                ' from ' // BNDY_NONR_1
               CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )

               ELSE   ! found bc's (PPM) on file; convert

               DO BND = 1, NBNDY
                  BCON( BND,VAR ) = BCFAC( VAR )
     &                            * BBUF( BND,LVL,VAR )
     &                            * RHOJ_BND( BND,LVL )
                  END DO
               END IF
            ELSE
            DO BND = 1, NBNDY
               BCON( BND,VAR ) = CMIN
               END DO
            END IF
161      CONTINUE

      SPC = 0
      STRT = N_GC_ADV + N_AE_ADV + N_NR_ADV + 1
      FINI = N_GC_ADV + N_AE_ADV + N_NR_ADV + N_TR_ADV
      DO 171 VAR = STRT, FINI
         SPC = SPC + 1 
         IF ( BCNAME ( VAR ) .NE. BLNK ) THEN

            IF ( .NOT. PINTERPB ( BNDY_TRAC_1, BCNAME ( VAR ), PNAME,
     &                           MDATE, MTIME, NBNDY*NLAYS,
     &                           BBUF( 1,1,VAR ) ) ) THEN
               XMSG = 'Could not read ' //
     &                 BCNAME( VAR )(1:TRIMLEN( BCNAME ( VAR ) ) )  //
     &                ' from ' // BNDY_TRAC_1
               CALL M3EXIT( PNAME, MDATE, MTIME, XMSG, XSTAT1 )

               ELSE   ! found bc's (PPM) on file; convert

               DO BND = 1, NBNDY
                  BCON( BND,VAR ) = BCFAC( VAR )
     &                            * BBUF( BND,LVL,VAR )
     &                            * RHOJ_BND( BND,LVL )
                  END DO
               END IF
            ELSE
            DO BND = 1, NBNDY
               BCON( BND,VAR ) = CMIN
               END DO
            END IF
171      CONTINUE

C for advecting Air Density X Jacobian

      DO BND = 1, NBNDY
         BCON ( BND,N_SPC_ADV ) = RHOJ_BND( BND,LVL )
         END DO

      RETURN
      END