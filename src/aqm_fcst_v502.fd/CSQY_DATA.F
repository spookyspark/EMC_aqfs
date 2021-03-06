
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
C $Header: /project/yoj/arc/CCTM/src/phot/phot_inline/CSQY_DATA.F,v 1.2 2011/10/21 16:11:27 yoj Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      MODULE CSQY_DATA

      IMPLICIT NONE

      CHARACTER( 32 ), SAVE :: JTABLE_REF

      INTEGER, SAVE :: NPHOT_REF  ! # ref phot reactions 
      INTEGER, SAVE :: NTEMP_REF  ! # ref temperatures 
      INTEGER, SAVE :: NWL_REF    ! # ref wavelengths 

C...Names of the mapped photolysis reactions (available to chemical)
C... mechanisms) and their pointers to the reference photolysis rxn

      CHARACTER( 16 ), ALLOCATABLE, SAVE :: PNAME_REF( : )

C...Setup the Mapping from CMAQ chemical reactions to the reference data

      INTEGER, SAVE :: NPHOT_MAP  ! #  phot mapped reactions 

      CHARACTER( 16 ), ALLOCATABLE, SAVE :: PNAME_MAP( : )
      INTEGER, ALLOCATABLE,         SAVE :: PHOT_MAP ( : )
      
      REAL, SAVE, ALLOCATABLE :: STWL_REF ( : ) 
      REAL, SAVE, ALLOCATABLE :: EFFWL_REF( : ) 
      REAL, SAVE, ALLOCATABLE :: ENDWL_REF( : ) 

      REAL, ALLOCATABLE, SAVE :: CLD_BETA_REF    ( : )  ! cloud extinction coef divided by LWC
      REAL, ALLOCATABLE, SAVE :: CLD_COALBEDO_REF( : )  ! cloud coalbedo
      REAL, ALLOCATABLE, SAVE :: CLD_G_REF       ( : )  ! cloud asymmetry factor

      REAL, ALLOCATABLE, SAVE :: FSOLAR_REF( : )        ! initial solar flux [photons*cm-2*s-1]

      REAL, ALLOCATABLE, SAVE :: TEMP_BASE ( : )        ! reference temperatures
      REAL, ALLOCATABLE, SAVE :: TEMP_REF( :,: )        ! reference temperatures

      REAL, ALLOCATABLE, SAVE :: CS_REF ( :,:,: )       ! effective cross sections
      REAL, ALLOCATABLE, SAVE :: QY_REF ( :,:,: )       ! effective quantum yields
      REAL, ALLOCATABLE, SAVE :: ECS_REF( :,:,: )       ! CS*QY averaged UCI Solar Flux

      INTEGER,           SAVE :: NTEMP_STRAT_REF        ! number of stratos temperatures
      REAL, ALLOCATABLE, SAVE :: TEMP_STRAT_REF( : )    ! temperature for stratos O3 xcross, K
      REAL, ALLOCATABLE, SAVE :: O3_CS_STRAT_REF( :,: ) ! ozone xcross at stratos temperatures, cm2

C...    effective quantum yields were computed by performing separate
C...    interval integrations for the cross sections and for the
C...    effective cross sections (cs*qy) (calculated on the finer
C...    wavelength grid.  The effective quantum yield values
C...    were then calculated for the 7 wavelength intervals by 
C...    dividing the effective cross sections by the interval average
C...    cross sections (eQY=eCS/CS).

      REAL, ALLOCATABLE, SAVE :: EQY_REF( :,:,: ) ! eCS/CS averaged 77 bins in UCI Model

      INTEGER  :: IWLR  ! wavelength loop variable
      INTEGER  :: ITTR   ! temperature loop variable
            
      END MODULE CSQY_DATA
