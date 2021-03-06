SUBROUTINE chkgrib (gribgrid,lyrct)

!-------------------------------------------------------------------------------
! Name:     Check GRIB Domain
! Purpose:  Verifies that the input GRIB domain is one we expect for AQF.
! Revised:  31 Mar 2004  Original version.  (T. Otte)
!           10 May 2010  Additions to incluse other domains (Hsin-mu Lin)
!-------------------------------------------------------------------------------

  USE metinfo
  USE premaqparm

  IMPLICIT NONE

  INTEGER     ,  INTENT(IN)    :: gribgrid, lyrct
  CHARACTER*16,  PARAMETER     :: pname     = 'CHKGRIB'

!-------------------------------------------------------------------------------
! Check basic grid information got from meteorology data & running script
! against expected AQF grids
!-------------------------------------------------------------------------------

  IF ( gribgrid == 144 ) THEN
     IF ( .NOT. ( ( ncols == 166   ) .AND.  &         ! 1x-domain
                  ( nrows == 142   ) .AND.  &
                  ( nlays <= lyrct ) ) ) THEN
        WRITE (6,9200) ncols, nrows, nlays
        GOTO 1001
     ENDIF
  ELSEIF ( gribgrid == 138 ) THEN
     IF ( .NOT. ( ( ( ncols == 268   ) .AND.  &       ! 3x-domain
                    ( nrows == 259   ) .AND.  &
                    ( nlays <= lyrct ) .AND.  &
                    ( x0    == 199   ) .AND.  &
                    ( y0    ==   1   ) )      &
          .OR.    ( ( ncols == 415   ) .AND.  &       ! Launcher 5x-domain
                    ( nrows == 265   ) .AND.  &
                    ( nlays <= lyrct ) .AND.  &
                    ( x0    ==  25   ) .AND.  &
                    ( y0    ==   1   ) )      &
          .OR.    ( ( ncols == 442   ) .AND.  &       ! 5x-domain
                    ( nrows == 265   ) .AND.  &
                    ( nlays <= lyrct ) .AND.  &
                    ( x0    ==  25   ) .AND.  &
                    ( y0    ==   1   ) ) ) ) THEN
        WRITE (6,9300) ncols, nrows, nlays, x0, y0
        GOTO 1001
     ENDIF
  ELSEIF ( gribgrid == 139 ) THEN
     IF ( .NOT. ( ( ( ncols ==  64   ) .AND.  &       ! HI-domain
                    ( nrows ==  44   ) .AND.  &
                    ( nlays <= lyrct ) .AND.  &
                    ( x0    ==   1   ) .AND.  &
                    ( y0    ==   1   ) )      &
          .OR.    ( ( ncols ==  80   ) .AND.  &       ! HI-domain Large
                    ( nrows ==  52   ) .AND.  &
                    ( nlays <= lyrct ) .AND.  &
                    ( x0    ==   1   ) .AND.  &
                    ( y0    ==   1   ) ) ) ) THEN
        WRITE (6,9400) ncols, nrows, nlays, x0, y0
        GOTO 1001
     ENDIF
  ELSEIF ( gribgrid == 140 ) THEN
     IF ( .NOT. ( ( ncols == 199   ) .AND.  &       ! AK-domain
                  ( nrows == 163   ) .AND.  &
                  ( nlays <= lyrct ) .AND.  &
                  ( x0    ==   1   ) .AND.  &
                  ( y0    ==   1   ) ) )  THEN
        WRITE (6,9500) ncols, nrows, nlays, x0, y0
        GOTO 1001
     ENDIF
  ELSEIF ( gribgrid == 255 ) THEN
     IF ( .NOT. ( (       ( ncols == 442   )        &    ! CONUS
                    .AND. ( nrows == 265   )        &
                    .AND. ( nlays <= lyrct )        &
                  ! .AND. ( x0    == 226   )        &
                  ! .AND. ( y0    == 231   )        &
                                             ) ) )  THEN
        WRITE (6,9600) ncols, nrows, nlays, x0, y0
        GOTO 1001
     ENDIF
  ELSEIF ( gribgrid == 145 ) THEN
     WRITE (6,9000)
     GOTO 1001
  ELSE
     WRITE (6,9100) gribgrid
     GOTO 1001
  ENDIF

  RETURN

!-------------------------------------------------------------------------------
! Error-handling section.
!-------------------------------------------------------------------------------

 9000 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PREMAQ WILL NO LONGER WORK FOR GRID 145',         &
              /, 1x, 70('*'))

 9100 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   EXPECTING INPUT GRID 138 OR 144 FOR AQF',         &
              /, 1x, '***   INPUT GRID ID:  ', i3,                            &
              /, 1x, 70('*'))

 9200 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PROCESSING FOR GRID 144 TO OUTPUT ON GRID 146',   &
              /, 1x, '***   GRID DIMENSION MISMATCH SUSPECTED',               &
              /, 1x, '***   NCOLS, NROWS, NLAYS = ', 3(2x, i3),               &
              /, 1x, 70('*'))

 9300 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PROCESSING FOR GRID 138 TO OUTPUT ON ',           &
              /, 1x, '***   EITHER GRID 147 ("3x") OR 148 ("5x")',            &
              /, 1x, '***   GRID DIMENSION MISMATCH SUSPECTED',               &
              /, 1x, '***   NCOLS, NROWS, NLAYS = ', 3(2x, i3),               &
              /, 1x, '***   CORNER AT (X0, Y0) = ', 2(2x, i3),                &
              /, 1x, 70('*'))

 9400 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PROCESSING FOR GRID 139 TO OUTPUT ON GRID 139',   &
              /, 1x, '***   GRID DIMENSION MISMATCH SUSPECTED',               &
              /, 1x, '***   NCOLS, NROWS, NLAYS = ', 3(2x, i3),               &
              /, 1x, '***   CORNER AT (X0, Y0) = ', 2(2x, i3),                &
              /, 1x, 70('*'))

 9500 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PROCESSING FOR GRID 140 TO OUTPUT ON GRID 140',   &
              /, 1x, '***   GRID DIMENSION MISMATCH SUSPECTED',               &
              /, 1x, '***   NCOLS, NROWS, NLAYS = ', 3(2x, i3),               &
              /, 1x, '***   CORNER AT (X0, Y0) = ', 2(2x, i3),                &
              /, 1x, 70('*'))

 9600 FORMAT (/, 1x, 70('*'),                                                 &
              /, 1x, '*** SUBROUTINE: CHKGRIB',                               &
              /, 1x, '***   PROCESSING FOR GRID 255 TO OUTPUT ON GRID 255',   &
              /, 1x, '***   GRID DIMENSION MISMATCH SUSPECTED',               &
              /, 1x, '***   NCOLS, NROWS, NLAYS = ', 3(2x, i3),               &
              /, 1x, '***   CORNER AT (X0, Y0) = ', 2(2x, i3),                &
              /, 1x, 70('*'))

 1001 CALL graceful_stop (pname)
      RETURN

END SUBROUTINE chkgrib
