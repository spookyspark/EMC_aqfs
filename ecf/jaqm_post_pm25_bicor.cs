#!/bin/ksh
#
##BSUB -oo /ptmpp2/Jianping.Huang/com/output/para1/today/jaqm_post_pm25_biascorr_cs.out.o%J
#BSUB -oo /ptmpp2/Jianping.Huang/com2/output/para1/today/jaqm_post_pm25_biascorr_cs_new.out
##BSUB -eo /ptmpp2/Jianping.Huang/com/output/para1/today/jaqm_post_pm25_biascorr_cs.out.o%J 
#BSUB -eo /ptmpp2/Jianping.Huang/com2/output/para1/today/jaqm_post_pm25_biascorr_cs_new.out
#BSUB -J jaqm_post_pm25_biascorr_cs
#BSUB -n 1 
#BSUB -x
#BSUB -R span[ptile=1]
##BSUB -R rusage[mem=2500]
#BSUB -W 00:20
#BSUB -q dev2
#BSUB -P CMAQ-T2O 
##BSUB -a poe

module load ics
module load ibmpe

ulimit -s unlimited

export LANG=en_US
export MP_EAGER_LIMIT=65536
export MP_COREFILE_FORMAT=core.txt
export MP_EUIDEVELOP=min
export MP_EUIDEVICE=sn_all
export MP_EUILIB=us
export MP_MPILIB=mpich2

export MP_LABELIO=yes
export MP_SINGLE_THREAD=yes
export MP_TASK_AFFINITY=cpu
#export MP_USE_BULK_XFER=yes
export MPICH_THROTTLE_ALLTOALL=0

#export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usrx/local/NetCDF/4.2/serial/lib/:/usrx/local/HDF5/1.8.9/serial/lib:/usrx/local/szip-2.1/lib"

# EXPORT list here
set -ax
export RUN_ENVIR=notnco
export COMROOT=/ptmpp2/${USER}/com2
export NWROOT=/naqfc/save/${USER}/nwdev
export cmaq_ver=v4.6.6
export envir=para1
export job=aqm_post_pm25_bicor
#
export PARAFLAG=YES

export SENDCOM=YES
export SENDDBN=NO
export SENDECF=NO

export PARAFLAG=YES
 
${HOMEaqm}/jobs/JAQM_POST_BICOR_CS

err=$?
if [ "${PARAFLAG}" = "YES" ]
then
 #err=$?
  if [ ${err} -ne 0 ]
  then
    exit 249
  fi
fi



