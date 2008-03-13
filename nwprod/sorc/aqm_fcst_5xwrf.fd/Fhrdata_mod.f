
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
C $Header: /project/air5/sjr/CMAS4.5/rel/models/CCTM/src/chem/ebi_cb4/hrdata_mod.F,v 1.1.1.1 2005/09/09 18:56:05 sjr Exp $ 

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%



      MODULE  HRDATA

C*************************************************************************
C
C  FUNCTION:  Mechanism & solver data for EBI solver
C             
C  PRECONDITIONS: For CB4 family of mechanisms only
C 
C  KEY SUBROUTINES/FUNCTIONS CALLED: None
C
C  REVISION HISTORY: Prototype created by Jerry Gipson, April, 2003
C                   C*************************************************************************

c..EBI solver fixed parameters
      INTEGER, PARAMETER ::  NEBITER = 1000  ! No. of iterations for EBI

      REAL, PARAMETER    ::  DELTAT = 2.5D+00     ! EBI time step

c..Mechanism specific variables
      INTEGER   N_SPEC       ! No. of species in mechanism
      INTEGER   N_RXNS       ! No. of reactions in mechanism
      INTEGER   N_EBISP      ! No. of species solved by EBI
      INTEGER   NING1        ! No. of species in group 1
      INTEGER   NING2        ! No. of species in group 2

c..Control flags
      LOGICAL   L_AE_VRSN    ! Flag for aerosol version of mech
      LOGICAL   L_AQ_VRSN    ! Flag for aqueous chemistry version of mech

c..Miscellaneous variables
      INTEGER   LOGDEV       ! Unit number of output log
      INTEGER   N_EBI_IT     ! No. of iterations for EBI
      INTEGER   N_EBI_STEPS  ! No. of time steps for EBI
      INTEGER   N_INR_STEPS  ! No. of inner time steps for EBI

      REAL    EBI_TMSTEP   ! Time step for EBI loops (min)

c...Allocatable arrays
      INTEGER, ALLOCATABLE :: EBISP( : )         ! Index of EBI species

      REAL*8, ALLOCATABLE ::  RKI(   : )     ! Rate constants 
      REAL, ALLOCATABLE ::  RXRAT( : )     ! Reaction rates 
      REAL, ALLOCATABLE ::  RTOL(  : )     ! Species tolerances 
      REAL, ALLOCATABLE ::  YC(    : )     ! Species concentrations
      REAL, ALLOCATABLE ::  YC0(   : )     ! Species concentrations
      REAL, ALLOCATABLE ::  YCP(   : )     ! Species concentrations
      REAL, ALLOCATABLE ::  PROD(  : )     ! Prod of species 
      REAL, ALLOCATABLE ::  LOSS(  : )     ! Loss of species 
      REAL, ALLOCATABLE ::  PNEG(  : )     ! Negative production rates


c..Gas species indices
      INTEGER   NO2
      INTEGER   NO
      INTEGER   O
      INTEGER   O3
      INTEGER   NO3
      INTEGER   O1D
      INTEGER   OH
      INTEGER   HO2
      INTEGER   N2O5
      INTEGER   HNO3
      INTEGER   HONO
      INTEGER   PNA
      INTEGER   H2O2
      INTEGER   CO
      INTEGER   FORM
      INTEGER   ALD2
      INTEGER   C2O3
      INTEGER   XO2
      INTEGER   PAN
      INTEGER   PAR
      INTEGER   XO2N
      INTEGER   ROR
      INTEGER   NTR
      INTEGER   OLE
      INTEGER   ETH
      INTEGER   TOL
      INTEGER   CRES
      INTEGER   TO2
      INTEGER   OPEN
      INTEGER   CRO
      INTEGER   XYL
      INTEGER   MGLY
      INTEGER   ISOP
      INTEGER   ISPD
      INTEGER   SO2
      INTEGER   SULF

c..Aerosol counter species
      INTEGER   TOLAER
      INTEGER   CSLAER
      INTEGER   XYLAER
      INTEGER   SULAER
      INTEGER   TERP
      INTEGER   TERPAER

c..AQ chemistry species
      INTEGER   PACD
      INTEGER   FACD
      INTEGER   AACD
      INTEGER   UMHP


      END MODULE HRDATA
