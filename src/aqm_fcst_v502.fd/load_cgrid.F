
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
C $Header: /project/yoj/arc/CCTM/src/init/yamo/load_cgrid.F,v 1.9 2012/01/19 14:47:23 yoj Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SUBROUTINE LOAD_CGRID ( FNAME, JDATE, JTIME, SPC_CAT, CMIN, CGRID )

C-----------------------------------------------------------------------
C Function:
C   Initialize the model CGRID array from file data

C Revision history:
C   Jeff - Dec 00 - split out from initscen.F
C                 - move CGRID_MAP into f90 module
C   Jeff - Feb 01 - module LOCALFILE to set CCTM IOAPI file defn's
C                 - add BUFSIZE for dfio option
C                 - assumed shape arrays
C   30 Mar 01 J.Young: dyn alloc - Use HGRD_DEFN; replace INTERP3 with INTERPX;
C   30 Oct 01 J.Young: fix ICBC_FAC
C    4 Sep 03 J.Young: fix SPC/NDX bug if ASO4J IC's are unavailable
C   20 Nov 03 J.Young: enable loading RHOJ
C   31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                      domain specifications in one module
C   21 Jun 10 J.Young: convert for Namelist redesign
C   16 Feb 11 S.Roselle: replaced I/O API include files with UTILIO_DEFN;
C                      removed deprecated TRIMLEN
C    2 Sep 11 J.Young: change ICBC_FAC policy to always assigning factor,
C                      if specified, not just if a surrogate is also specified 
C-----------------------------------------------------------------------

      USE GRID_CONF             ! horizontal & vertical domain specifications
      USE CGRID_SPCS            ! CGRID mechanism species
      USE UTILIO_DEFN

      IMPLICIT NONE

      INCLUDE SUBST_CONST       ! constants
      INCLUDE SUBST_FILES_ID    ! file name parameters

C Arguments:

      CHARACTER( 16 ) :: FNAME
      INTEGER      JDATE
      INTEGER      JTIME
      CHARACTER( 2 ) :: SPC_CAT
      REAL         CMIN
!     REAL      :: CGRID( :,:,:,: )  ! for initial CONC
      REAL, POINTER :: CGRID( :,:,:,: )  ! for initial CONC

C Parameters:

C minimum aerosol sulfate concentration [ ug/m**3 ]
      REAL, PARAMETER :: AEROCONCMIN = 0.001

C The following two factors assume that sulfate density is 1.8e3 [ kg/m**3 ]
C and that the geometric mean diameter and geometric standard deviations
C for the Aitken mode are 0.01e-6 [ m ] and 1.7 respectively
C and are 0.07e-6 and 2.0 respectively for the accumulation mode.

C factor to calculate aerosol number concentration from aerosol sulfate mass
C concentration in the Aitken mode [ ug ].
      REAL, PARAMETER :: NUMFACT_I = 2.988524 E11

C factor to calculate aerosol number concentration from aerosol sulfate mass
C concentration in the Accumulation mode [ ug ].
      REAL, PARAMETER :: NUMFACT_J = 3.560191 E08

C fraction of sulfuric acid vapor taken as aerosol for first time step
      REAL, PARAMETER :: SO4VAPTOAER = 0.999
C initial fraction of total aerosol sulfate in the Aitken mode
      REAL, PARAMETER :: IFRACATKN = 0.04

      INTEGER, SAVE :: MXSPC
      INTEGER ASTAT

C File variables:

      REAL      :: DENS( NCOLS,NROWS,NLAYS )       ! air density (kg/m^3)
      REAL      :: RHOJ( NCOLS,NROWS,NLAYS ) ! air density X Jacobian (kg/m^2)

C External Functions:

      INTEGER, EXTERNAL :: FINDEX       !  looks up number in table.

C Local Variables

      REAL         MWH2SO4                           ! H2SO4 molec. wt.
      REAL         H2SO4CONV                         ! ppm -> ug/m**3
      INTEGER      LSULF                             ! Gas chem CGRID index
      INTEGER      ISO4AJ, ISO4AI, INUMATKN, INUMACC ! CGRID aerosol indices

      INTEGER      GXOFF, GYOFF               ! global origin offset from file

C for XTRACT3
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3
      INTEGER       :: STRTCOLINI, ENDCOLINI, STRTROWINI, ENDROWINI
      REAL      :: DBUFF( NCOLS,NROWS,NLAYS )

      INTEGER      SPC_STRT
      INTEGER      N_SPCS                     ! no. of species for this call
      INTEGER      NDX                        ! loop copy of INDX
      INTEGER      ISUR                       ! surrogate index
      INTEGER, ALLOCATABLE, SAVE :: INDX( : ) ! Variable indices for all IC species
      REAL,    ALLOCATABLE, SAVE :: ICBC_FAC( : ) ! Factor to be applied to ICs
      INTEGER      C, R, L, SPC, V            ! loop counters
      INTEGER      ASPC                       ! CGRID RHOJ pointer
      INTEGER      NCOLSDENS, NROWSDENS       ! local for DENS

      CHARACTER( 16 ) :: PNAME = 'LOAD_CGRID'
      CHARACTER( 16 ) :: VNAME
      CHARACTER( 16 ) :: CONCMIN
      CHARACTER( 96 ) :: XMSG = ' '
      CHARACTER( 40 ) :: CHWARN = 'Domain extents different from model for '
      CHARACTER( 24 ) :: ESTR1 = 'No IC found for species '
      CHARACTER( 34 ) :: ESTR2 = ' '

      LOGICAL, SAVE :: FIRSTIME = .TRUE.

      INTEGER, SAVE :: LOGDEV

C-----------------------------------------------------------------------

      IF ( FIRSTIME ) THEN
         FIRSTIME = .FALSE.
         LOGDEV = INIT3 ()
         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )
C IOFDESC common now loaded with MET_CRO_3D header

         MXSPC = N_GC_SPC + N_AE_SPC + N_NR_SPC + N_TR_SPC
         ALLOCATE ( INDX( MXSPC ), ICBC_FAC( MXSPC ), STAT = ASTAT )
         IF ( ASTAT .NE. 0 ) THEN
            XMSG = 'ERROR allocating INDX or ICBC_FAC'
            CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
         END IF
      END IF

      WRITE( CONCMIN,'(1PE8.2)' ) CMIN

      IF ( .NOT. OPEN3( FNAME, FSREAD3, PNAME ) ) THEN
         XMSG = 'Could not open ' // FNAME // ' file'
         CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF
 
      IF ( .NOT. DESC3( FNAME ) ) THEN
         XMSG = 'Could not get ' // FNAME // ' file description'
         CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF
 
      IF ( GL_NCOLS .NE. NCOLS3D ) THEN
         WRITE( LOGDEV,* ) ' '
         WRITE( LOGDEV,* ) '    WARNING: ' // CHWARN // FNAME
         WRITE( LOGDEV,* ) '>>  GL_NCOLS: ', GL_NCOLS, '  NCOLS3D: ', NCOLS3D
      END IF
 
      IF ( GL_NROWS .NE. NROWS3D ) THEN
         WRITE( LOGDEV,* ) ' '
         WRITE( LOGDEV,* ) '    WARNING: ' // CHWARN // FNAME
         WRITE( LOGDEV,* ) '>>  GL_NROWS: ', GL_NROWS, '  NROWS3D: ', NROWS3D
      END IF
 
      IF ( NLAYS .NE. NLAYS3D ) THEN
         XMSG = 'Wrong number of layers in ' // FNAME // ' file'
         CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
      END IF

      ESTR2 = ' in ' // TRIM( FNAME ) // '; set to ' // TRIM( CONCMIN )

C The original policy for using surrogate names is first, check if the Namelist
C species is on the IC file; if so ignore any surrogate. If the Namelist species
C is not on the IC file, then check if the surrogate name is; if so also use the
C scale factor (default = 1.0).
C Note: parsing in CGRID_SPCS follows this policy for all the Namelist surrogate
C types (EMIS, DEPV, ICBC, and SCAV).
C => Change this for ICBC:
C First check if there's a surrogate name in the Namelist and use it (and the
C corresponding scale factor) if it exists. If it's not on the IC file, which it
C wouldn`t be if it were blank, then look for the Namelist species name.

C Get INDX
!     INDX = 0   ! array assignment
      DO SPC = 1, MXSPC
         INDX( SPC ) = 0
      END DO

      IF ( SPC_CAT .EQ. 'GC' ) THEN
         WRITE( LOGDEV,1009 ) 'transported gas-phase species'
         SPC_STRT = GC_STRT
         N_SPCS = N_GC_SPC
         DO SPC = 1, N_SPCS
C is there a surrogate name?
            ISUR = FINDEX ( SPC, N_GC_ICBC, GC_ICBC_MAP )
!           write( logdev,* ) '=c=spc,isur: ', spc, isur
            IF ( ISUR .NE. 0 ) THEN
C is it on the IC file?
               NDX = INDEX1( GC_ICBC( ISUR ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
C if there`s a surrogate name, CGRID_SPCS handles setting GC_ICBC_FAC
                  INDX( SPC ) = NDX   ! index in the IC file
                  ICBC_FAC( SPC ) = GC_ICBC_FAC( ISUR )
!                 write( logdev,* ) '=c=_fac in sur: ', icbc_fac( spc )
               ELSE
                  XMSG = ESTR1 // TRIM( GC_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            ELSE
C is the (main) species name on the IC file?
               NDX = INDEX1( GC_SPC( SPC ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX
                  ICBC_FAC( SPC ) = 1.0
               ELSE
                  XMSG = ESTR1 // TRIM( GC_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            END IF

#ifdef Verbose3
            write( logdev,* ) '=c=spc,indx: ', spc, indx( spc ), trim( gc_spc( spc ) ),
     &                        '   icbc_fac:', icbc_fac( spc )
            write( logdev,* ) ' '
#endif
            IF ( INDX( SPC ) .GT. 0 )
     &         WRITE( LOGDEV,1013 ) INDX( SPC ), GC_SPC( SPC ), ICBC_FAC( SPC )

         END DO

      ELSE IF ( SPC_CAT .EQ. 'AE' ) THEN
         WRITE( LOGDEV,1009 ) 'transported aerosol species'
         SPC_STRT = AE_STRT
         N_SPCS = N_AE_SPC
         DO SPC = 1, N_SPCS
C is there a surrogate name?
            ISUR = FINDEX ( SPC, N_AE_ICBC, AE_ICBC_MAP )
!           write( logdev,* ) '=c=spc,isur: ', spc, isur
            IF ( ISUR .NE. 0 ) THEN
C is it on the IC file?
               NDX = INDEX1( AE_ICBC( ISUR ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX   ! index in the IC file
                  ICBC_FAC( SPC ) = AE_ICBC_FAC( ISUR )
!                 write( logdev,* ) '=c=_fac in sur: ', icbc_fac( spc )
               ELSE
                  XMSG = ESTR1 // TRIM( AE_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            ELSE
C is the (main) species name on the IC file?
               NDX = INDEX1( AE_SPC( SPC ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX
                  ICBC_FAC( SPC ) = 1.0
               ELSE
                  XMSG = ESTR1 // TRIM( AE_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            END IF

#ifdef Verbose3
            write( logdev,* ) '=c=spc,indx: ', spc, indx( spc ), trim( ae_spc( spc ) ),
     &                        '   icbc_fac:', icbc_fac( spc )
            write( logdev,* ) ' '
#endif
            IF ( INDX( SPC ) .GT. 0 )
     &         WRITE( LOGDEV,1013 ) INDX( SPC ), AE_SPC( SPC ), ICBC_FAC( SPC )
 
         END DO

      ELSE IF ( SPC_CAT .EQ. 'NR' ) THEN
         WRITE( LOGDEV,1009 ) 'transported non-reactive gas species'
         SPC_STRT = NR_STRT
         N_SPCS = N_NR_SPC
         DO SPC = 1, N_SPCS
C is there a surrogate name?
            ISUR = FINDEX ( SPC, N_NR_ICBC, NR_ICBC_MAP )
!           write( logdev,* ) '=c=spc,isur: ', spc, isur
            IF ( ISUR .NE. 0 ) THEN
C is it on the IC file?
               NDX = INDEX1( NR_ICBC( ISUR ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX   ! index in the IC file
                  ICBC_FAC( SPC ) = NR_ICBC_FAC( ISUR )
!                 write( logdev,* ) '=c=_fac in sur: ', icbc_fac( spc )
               ELSE
                  XMSG = ESTR1 // TRIM( NR_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            ELSE
C is the (main) species name on the IC file?
               NDX = INDEX1( NR_SPC( SPC ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX
                  ICBC_FAC( SPC ) = 1.0
               ELSE
                  XMSG = ESTR1 // TRIM( NR_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            END IF

#ifdef Verbose3
            write( logdev,* ) '=c=spc,indx: ', spc, indx( spc ), trim( nr_spc( spc ) ),
     &                        '   icbc_fac:', icbc_fac( spc )
            write( logdev,* ) ' '
#endif
            IF ( INDX( SPC ) .GT. 0 )
     &         WRITE( LOGDEV,1013 ) INDX( SPC ), NR_SPC( SPC ), ICBC_FAC( SPC )

         END DO

      ELSE IF ( SPC_CAT .EQ. 'TR' ) THEN
         WRITE( LOGDEV,1009 ) 'transported inert tracer gas species'
         SPC_STRT = TR_STRT
         N_SPCS = N_TR_SPC
         DO SPC = 1, N_SPCS
C is there a surrogate name?
            ISUR = FINDEX ( SPC, N_TR_ICBC, TR_ICBC_MAP )
!           write( logdev,* ) '=c=spc,isur: ', spc, isur
            IF ( ISUR .NE. 0 ) THEN
C is it on the IC file?
               NDX = INDEX1( TR_ICBC( ISUR ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX   ! index in the IC file
                  ICBC_FAC( SPC ) = TR_ICBC_FAC( ISUR )
!                 write( logdev,* ) '=c=_fac in sur: ', icbc_fac( spc )
               ELSE
                  XMSG = ESTR1 // TRIM( TR_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            ELSE
C is the (main) species name on the IC file?
               NDX = INDEX1( TR_SPC( SPC ), NVARS3D, VNAME3D )
               IF ( NDX .NE. 0 ) THEN
                  INDX( SPC ) = NDX
                  ICBC_FAC( SPC ) = 1.0
               ELSE
                  XMSG = ESTR1 // TRIM( TR_SPC( SPC ) ) // ESTR2
                  CALL M3MESG( XMSG )
               END IF
            END IF

#ifdef Verbose3
            write( logdev,* ) '=c=spc,indx: ', spc, indx( spc ), trim( tr_spc( spc ) ),
     &                        '   icbc_fac:', icbc_fac( spc )
            write( logdev,* ) ' '
#endif
            IF ( INDX( SPC ) .GT. 0 )
     &         WRITE( LOGDEV,1013 ) INDX( SPC ), TR_SPC( SPC ), ICBC_FAC( SPC )

         END DO

      ELSE IF ( SPC_CAT .EQ. 'RJ' ) THEN
         N_SPCS = 0
!        WRITE( LOGDEV,'(/ 5X, A)' ) 'loading Density*Jacobian into CGRID'
      ELSE
         XMSG = 'Species categories incorrect for CGRID '
         CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT2 )
      END IF
        
C Read into CGRID

      CALL SUBHFILE ( FNAME, GXOFF, GYOFF,
     &                STRTCOLINI, ENDCOLINI, STRTROWINI, ENDROWINI )
C IOFDESC common now loaded with FNAME header

      DO SPC = 1, N_SPCS
         V = SPC_STRT - 1 + SPC
         NDX = INDX( SPC )

         IF ( NDX .GT. 0 ) THEN
#ifdef Verbose3
            write( logdev,* ) '=vname3d=: ', spc, v, ndx, icbc_fac( spc ), vname3d( ndx )
#endif
            IF ( .NOT. XTRACT3( FNAME, VNAME3D ( NDX ),
     &           1,NLAYS, STRTROWINI,ENDROWINI, STRTCOLINI,ENDCOLINI,
     &           JDATE, JTIME, DBUFF ) ) THEN
               XMSG = 'Could not read ' // TRIM( VNAME3D( NDX ) )
     &              // ' from ' // FNAME
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS
                     CGRID( C,R,L,V ) = ICBC_FAC( SPC ) * DBUFF( C,R,L )
                  END DO
               END DO
            END DO

         END IF   ! INDX .GT. 0

      END DO

      IF ( N_SPCS .NE. 0 ) WRITE( LOGDEV,'(/ 5X, A)' )
     &                            SPC_CAT // ' loaded into CGRID'

      IF ( SPC_CAT .EQ. 'RJ' ) THEN

C Load RHOJ for transport and mixing ratio advection adjustment

         VNAME = 'DENSA_J'
         IF ( .NOT. XTRACT3( MET_CRO_3D, VNAME,
     &              1,NLAYS, STRTROWMC3,ENDROWMC3, STRTCOLMC3,ENDCOLMC3,
     &              JDATE, JTIME, RHOJ ) ) THEN
             XMSG = 'Could not read DENSA_J from ' // MET_CRO_3D
            CALL M3EXIT( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
         END IF

         ASPC = GC_STRT - 1 + N_GC_SPCD
         DO L = 1, NLAYS
            DO R = 1, MY_NROWS
               DO C = 1, MY_NCOLS
                  CGRID( C,R,L,ASPC ) = RHOJ( C,R,L )
               END DO
            END DO
         END DO

         WRITE( LOGDEV,'(/ 5X, A)' ) 'Density*Jacobian loaded into CGRID'

!        write( logdev,'( a,i7,i7.6,1pe15.7 )' ) 'rhoj sum1:', jdate, jtime, sum( rhoj )

      END IF

      IF ( SPC_CAT .EQ. 'AE' ) THEN

C are ASO4J IC`s available on the file?

         VNAME = 'ASO4J'
         NDX = INDEX1( VNAME, NVARS3D, VNAME3D )
     
         IF ( NDX .EQ. 0 ) THEN  ! ASO4J not on file

C Set pointers for gas (vapor) phase sulfur species

            NDX = INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( NDX .NE. 0 ) THEN
               ISO4AJ = AE_STRT - 1 + NDX
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'SULF'
            NDX = INDEX1( VNAME, N_GC_G2AE, GC_G2AE )
            IF ( NDX .NE. 0 ) THEN
               LSULF   = GC_STRT - 1 + GC_G2AE_MAP( NDX )
               MWH2SO4 = GC_MOLWT( GC_G2AE_MAP( NDX ) )
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in gas chem aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            VNAME = 'ASO4I'
            NDX = INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( NDX .NE. 0 ) THEN
               ISO4AI = AE_STRT - 1 + NDX
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF
            VNAME = 'NUMATKN'
            NDX = INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( NDX .NE. 0 ) THEN
               INUMATKN = AE_STRT - 1 + NDX
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF
            VNAME = 'NUMACC'
            NDX = INDEX1( VNAME, N_AE_SPC, AE_SPC )
            IF ( NDX .NE. 0 ) THEN
               INUMACC = AE_STRT - 1 + NDX
            ELSE
               XMSG = 'Could not find ' // VNAME // 'in aerosol table'
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT3 )
            END IF

            NCOLSDENS = ENDCOLMC3 - STRTCOLMC3 + 1
            NROWSDENS = ENDROWMC3 - STRTROWMC3 + 1

            IF ( NCOLSDENS .NE. MY_NCOLS .OR.
     &           NROWSDENS .NE. MY_NROWS ) THEN
               WRITE( XMSG,'( A, 4I8 )' ) 'Local Columns or Rows incorrect',
     &         NCOLSDENS, MY_NCOLS, NROWSDENS, MY_NROWS
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

C IOFDESC now loaded with MET_CRO_3D header

            VNAME = 'DENS'
!           IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, PNAME,
!    &                          STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,
!    &                          1,NLAYS,
!    &                          JDATE, JTIME, DENS ) ) THEN
            IF ( .NOT. XTRACT3( MET_CRO_3D, VNAME, 1,NLAYS,
     &                          STRTROWMC3,ENDROWMC3, STRTCOLMC3,ENDCOLMC3,
     &                          JDATE, JTIME, DENS ) ) THEN
               XMSG = 'Could not read ' // VNAME // ' from ' // MET_CRO_3D
               CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
            END IF

C Partition the aerosol sulfate arrays with a fraction of the initial SO4 

            H2SO4CONV = 1.0E3 * MWH2SO4 / MWAIR * SO4VAPTOAER

            DO L = 1, NLAYS
               DO R = 1, MY_NROWS
                  DO C = 1, MY_NCOLS

C total accumulation mode sulfate:

                     CGRID( C,R,L,ISO4AJ )   = MAX ( AEROCONCMIN,
     &                                         ( 1.0 - IFRACATKN )
     &                                       * H2SO4CONV
     &                                       * DENS ( C,R,L )
     &                                       * CGRID( C,R,L,LSULF ) )

C Accumulation mode number:
    
                     CGRID( C,R,L,INUMACC )  = NUMFACT_J
     &                                       * CGRID( C,R,L,ISO4AJ )

C Aitken mode sulfate:
    
                     CGRID( C,R,L,ISO4AI )   = MAX ( AEROCONCMIN,
     &                                         IFRACATKN
     &                                       * H2SO4CONV
     &                                       * DENS ( C,R,L )
     &                                       * CGRID( C,R,L,LSULF ) )
    
C Aitken mode number:
    
                     CGRID( C,R,L,INUMATKN ) = NUMFACT_I
     &                                       * CGRID( C,R,L,ISO4AI )
    
C correct sulfate vapor concentration for part removed:
    
                     CGRID( C,R,L,LSULF )    = ( 1.0 - SO4VAPTOAER )
     &                                       * CGRID( C,R,L,LSULF)
    
                  END DO
               END DO
            END DO

            XMSG = 'No IC''s found for aerosol sulfate. ' //
     &             'Gas Chem sulfate used for partitioning.'
            CALL M3MESG( XMSG )

         END IF  ! NDX .EQ. 0

      END IF  !  SPC_CAT .EQ. 'AE'

C Close the file

!     IF ( .NOT. CLOSE3( FNAME ) ) THEN
!        XMSG = 'Could not close ' // FNAME // ' file'
!        CALL M3EXIT ( PNAME, JDATE, JTIME, XMSG, XSTAT1 )
!     END IF

      RETURN

1009  FORMAT( / 5X, 'IC/BC Factors used for ', A )
1013  FORMAT( 5X, I3, 2X, A, 1PG13.5 )
      END
