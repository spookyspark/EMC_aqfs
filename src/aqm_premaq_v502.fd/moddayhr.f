
        MODULE MODDAYHR

!***********************************************************************
!  Module body starts at line 
!
!  DESCRIPTION:
!     This module contains the public allocatable arrays for the day- and
!     hour-specific data import and processing.
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 12/99 by M. Houyoux
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id: moddayhr.f,v 1.6 2004/06/21 17:23:02 cseppan Exp $
!
! COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
! All Rights Reserved
! 
! Carolina Environmental Program
! University of North Carolina at Chapel Hill
! 137 E. Franklin St., CB# 6116
! Chapel Hill, NC 27599-6116
! 
! smoke@unc.edu
!
! Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/emmod/moddayhr.f,v $
! Last updated: $Date: 2004/06/21 17:23:02 $ 
!
!****************************************************************************

        IMPLICIT NONE

        INCLUDE 'EMPRVT3.EXT'   !  emissions private parameters

!.........  Sparsely stored day-specific or hour-specific emissions array
!           for writing data
!.........  Contains the number, source indices, and daily emissions
        REAL   , ALLOCATABLE, PUBLIC:: PDEMOUT( :,: )  
        REAL   , ALLOCATABLE, PUBLIC:: PDTOTL ( :,: ) ! daily totals from hourly

!.........  Unsorted record-day information from day- or hour-specific inputs
!.........  First dimension is time steps. Second dimension is max period-
!           specific source number over all periods.
        INTEGER, ALLOCATABLE, PUBLIC:: MXPDPT( : )   ! Max part-day recs per hr
        INTEGER, ALLOCATABLE, PUBLIC:: NPDPT ( : )   ! No. part-day recs per hr
        INTEGER, ALLOCATABLE, PUBLIC:: CODEA ( :,: ) ! pol/act index to EANAM
        INTEGER, ALLOCATABLE, PUBLIC:: IDXSRC( :,: ) ! sorting index
        INTEGER, ALLOCATABLE, PUBLIC:: SPDIDA( :,: ) ! index to CSOURC

        REAL   , ALLOCATABLE, PUBLIC:: EMISVA( :,: ) ! period-specific emis
        REAL   , ALLOCATABLE, PUBLIC:: DYTOTA( :,: ) ! daily total (if present)

!.........  Logical flag for which sources in inventory appear in day- or hour-
!           specific inputs. Dim: NSRC
        LOGICAL, ALLOCATABLE, PUBLIC:: LPDSRC( : )

!.........  Variables for reading day- and hour-specific data
        INTEGER, PUBLIC :: NDYSRC = 0  ! actual no. day-specific sources
        INTEGER, PUBLIC :: NHRSRC = 0  ! actual no. hour-specific sources
        INTEGER, PUBLIC :: NDYPOA = 0  ! no. of pols/acts in day-spec file
        INTEGER, PUBLIC :: NHRPOA = 0  ! no. of pols/acts in hr-spec file

!.........  Arrays for reading day- and hour-specific data...

!.........  Indicator for inventory pol/act having day- or hour-specific data
        LOGICAL, ALLOCATABLE, PUBLIC :: LDSPOA( : )  ! true: data exists
        LOGICAL, ALLOCATABLE, PUBLIC :: LHSPOA( : )

!.........  Indicator for inventory pol/act having temporal profiles for
!           hour-specific file (instead of hourly emissions)
        LOGICAL, ALLOCATABLE, PUBLIC :: LHPROF( : )  ! true: profile not data

!.........  Day- and hour-specific pol/act names
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: DYPNAM( : )
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: HRPNAM( : )

!.........  Day- and hour-specific pol/act descriptions
        CHARACTER(IODLEN3), ALLOCATABLE, PUBLIC :: DYPDSC( : )
        CHARACTER(IODLEN3), ALLOCATABLE, PUBLIC :: HRPDSC( : )

        INTEGER, ALLOCATABLE :: INDXD( : )   ! SMOKE source IDs
        REAL   , ALLOCATABLE :: EMACD( : )   ! day-specific emis or activities

        INTEGER, ALLOCATABLE :: INDXH( : )   ! SMOKE source IDs
        REAL   , ALLOCATABLE :: EMACH( : )   ! hour-specific emis or activities

!.........  Array for reporting about day- and hour-specific data...

C...........   List of ORIS IDs in hour-specific data not in inventory
        INTEGER, PUBLIC :: NUNFDORS
        CHARACTER(ORSLEN3), ALLOCATABLE, PUBLIC :: UNFDORS( : )

        END MODULE MODDAYHR
