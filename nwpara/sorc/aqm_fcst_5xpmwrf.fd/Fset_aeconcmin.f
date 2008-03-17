
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/cloud/cloud_acm/set_aeconcmin.F,v 1.1.1.1 2005/09/09 18:56:05 sjr Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

      SUBROUTINE SET_AECONCMIN ( AECONCMIN )
C-----------------------------------------------------------------------
C
C  FUNCTION:
C       set minimum concentrations for aerosol species
C
C  PRECONDITIONS REQUIRED:
C       Dates and times represented YYYYDDD:HHMMSS.
C
C  REVISION  HISTORY:
C       5/05 copied code from aero_depv to begin subroutine
C-----------------------------------------------------------------------

      IMPLICIT NONE

C...........INCLUDES and their descriptions

      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/AE_SPC.EXT"              ! aerosol species table
      INCLUDE "/meso/save/wx20jy/cctm/BLD_u5a/CONST.EXT"               ! constants

C...........PARAMETERS and their descriptions:

C...mathematical constants used in this code

      REAL, PARAMETER :: PI6     = PI / 6.0
      REAL, PARAMETER :: F6DPI   = 6.0 / PI
      REAL, PARAMETER :: F6DPI9  = 1.0E+9 * F6DPI
      REAL, PARAMETER :: F6DPIM9 = 1.0E-9 * F6DPI

C...aerosol bulk densities

      REAL, PARAMETER :: RHOSO4 = 1.8E3    ! bulk density of aerosol sulfate
      REAL, PARAMETER :: RHOANTH = 2.2E3   ! bulk density for anthropogenic aerosol

C...factors for converting aerosol mass concentration [ ug/m**3] to
C...  3rd moment concentration [ m**3/m**3]

      REAL, PARAMETER :: SO4FAC  = F6DPIM9 / RHOSO4
      REAL, PARAMETER :: ANTHFAC = F6DPIM9 / RHOANTH

C...background aerosol distribution parameters

      REAL, PARAMETER :: SGINIAT = 1.70      ! background sigma-G for Aitken mode
      REAL, PARAMETER :: SGINIAC = 2.0       ! background sigma-G for accumulation mode
      REAL, PARAMETER :: SGINICO = 2.2       ! background fixed sigma-G for coarse mode
      REAL, PARAMETER :: DGINIAT = 0.01E-6   ! background mean diameter for Aitken mode [ m ]
      REAL, PARAMETER :: DGINIAC = 0.07E-6   ! background mean diameter for accumulation mode [ m ]
      REAL, PARAMETER :: DGINICO = 1.0E-6    ! background mean diameter for coarse mode [ m ]

C...minimum concentrations

      REAL, PARAMETER :: CMIN = 1.0E-25   ! minimum concentration for most species

C...  minimum values for aerosol mass concentrations (ug/m3)

      REAL, PARAMETER :: SO4MIN_AC = 1.0E-6   ! minimum aerosol sulfate concentration
                                              ! for acccumulation mode 1 pg
      REAL, PARAMETER :: SO4MIN_AT = 1.0E-6 * SO4MIN_AC ! minimum aerosol sulfate
                                                        ! concentration for Aitken mode
      REAL, PARAMETER :: ACORSMIN_CO = 1.889544E-05 ! minimum coarse mode concentration
                                                    ! Set to give NUMMIN_C = 1.0

C...........ARGUMENTS and their descriptions

      REAL AECONCMIN( N_AE_SPCD ) ! array of minimum concentrations (mol/mol)

C...........SCRATCH LOCAL VARIABLES and their descriptions:

      CHARACTER( 16 ) :: PNAME = 'SET_AECONCMIN'   ! program name

      INTEGER SPC      ! species loop counter

      REAL NUMMIN_AT   ! minimum Aitken mode number concentrations (#/m3)
      REAL NUMMIN_AC   ! minimum accumulation mode number concentrations (#/m3)
      REAL NUMMIN_C    ! minimum coarse mode number concentrations (#/m3)
      REAL SRFMIN_AT   ! minimum Aitken mode surface area concentrations (m2/m3)
      REAL SRFMIN_AC   ! minimum accumulation mode surface area concentrations (m2/m3)

C...........EXTERNAL FUNCTIONS and their descriptions:

      INTEGER, EXTERNAL :: TRIMLEN

C-----------------------------------------------------------------------
C   begin body of subroutine  SET_AECONCMIN

C...set minimum values for aerosol surface area concentrations (m2/m3)

      NUMMIN_AT = SO4FAC  * SO4MIN_AT
     &          / ( DGINIAT**3 * EXP( 4.5 * LOG( SGINIAT )**2 ) )
      NUMMIN_AC = SO4FAC  * SO4MIN_AC
     &          / ( DGINIAC**3 * EXP( 4.5 * LOG( SGINIAC )**2 ) )
      NUMMIN_C  = ANTHFAC * ACORSMIN_CO
     &          / ( DGINICO**3 * EXP( 4.5 * LOG( SGINICO )**2 ) )

C...set minimum values for aerosol surface area concentrations (m2/m3)

      SRFMIN_AT = PI * NUMMIN_AT * DGINIAT**2
     &          * EXP( 2.0 * LOG( SGINIAT )**2 )
      SRFMIN_AC = PI * NUMMIN_AC * DGINIAC**2
     &          * EXP( 2.0 * LOG( SGINIAC )**2 )

C create an array of minimum concentrations (mol-kg/mol-m3)

      DO SPC = 1, N_AE_SPC

        SELECT CASE ( AE_SPC( SPC )( 1:TRIMLEN( AE_SPC( SPC ) ) ) )
        CASE ( 'NUMATKN' )
          AECONCMIN( SPC ) = NUMMIN_AT   * MWAIR * 1.0E-3 / AVO
        CASE ( 'NUMACC' )
          AECONCMIN( SPC ) = NUMMIN_AC   * MWAIR * 1.0E-3 / AVO
        CASE ( 'NUMCOR' )
          AECONCMIN( SPC ) = NUMMIN_C    * MWAIR * 1.0E-3 / AVO
        CASE ( 'SRFATKN' )
          AECONCMIN( SPC ) = SRFMIN_AT   * MWAIR * 1.0E-3
        CASE ( 'SRFACC' )
          AECONCMIN( SPC ) = SRFMIN_AC   * MWAIR * 1.0E-3
        CASE ( 'ASO4I' )
          AECONCMIN( SPC ) = SO4MIN_AT   * MWAIR * 1.0E-9 / AE_MOLWT( SPC )
        CASE ( 'ASO4J' )
          AECONCMIN( SPC ) = SO4MIN_AC   * MWAIR * 1.0E-9 / AE_MOLWT( SPC )
        CASE ( 'ACORS' )
          AECONCMIN( SPC ) = ACORSMIN_CO * MWAIR * 1.0E-9 / AE_MOLWT( SPC )
        CASE DEFAULT
          AECONCMIN( SPC ) = CMIN
        END SELECT

      END DO
      	
      RETURN

      END
