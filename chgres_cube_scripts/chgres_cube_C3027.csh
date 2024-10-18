#!/bin/tcsh
#SBATCH --ntasks=288
#SBATCH --ntasks-per-node=48
#SBATCH --output=./%x.o%j
#SBATCH --cluster=c5
#SBATCH --qos=normal
#SBATCH --account=gfdl_w
#SBATCH --time=02:00:00


set echo
#
# case configurations
#

# analysistyp: the format of GFS analysis. It can be gaussian_netcdf, gaussian_nemsio, gfs_gaussian_nemsio, and gfs_sigio, depending on the version of GFS.
set analysistype='gaussian_nemsio' 
# gridtype: model grid configuration. It can be global or nest. Multiple nesting is not supported yet.
set gridtype='global'
# res: cubed-sphere resolution
set res=3072
# analysislevfile: vertical levels of the IC. Use the same as the GFS analysis is recommended.
set analysislevfile='global_hyblev.l65.txt'
if (! $?CDATE) then
  set CDATE=2020080100 
endif
set ICDIR=/gpfs/f5/gfdl_w/world-shared/${USER}/SHiELD_IC/GLOBAL_C${res}
set UTILSDIR=/ncrc/home2/Kai-yuan.Cheng/software/UFS_UTILS
set GRIDDIR=$ICDIR/GRID
set GFSANLDIR=/gpfs/f5/gfdl_w/world-shared/Kai-yuan.Cheng/UFS_UTILS_RETRO_DATA/GFSvOPER
set WORKDIR=/gpfs/f5/gfdl_w/world-shared/${USER}/wrk.chgres

# probably don't have to change anything below here.

# Threads useful when ingesting spectral gfs sigio files.
# Otherwise set to 1.
setenv OMP_NUM_THREADS 1
setenv OMP_STACKSIZE 1024M

if ($analysistype == 'gaussian_nemsio') then
  set atmext='atmanl.nemsio'
  set sfcext='sfcanl.nemsio'
  set tracerout='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
  set tracerin='"spfh","clwmr","o3mr","icmr","rwmr","snmr","grle"'
else if ($analysistype == 'gaussian_netcdf') then
  set atmext='atmanl.nc'
  set sfcext='sfcanl.nc'
  set tracerout='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
  set tracerin='"spfh","clwmr","o3mr","icmr","rwmr","snmr","grle"'
else if ($analysistype == 'gfs_gaussian_nemsio') then
  setenv OMP_NUM_THREADS 6
  set atmext='atmanl.nemsio'
  set sfcext='sfcanl.nemsio'
  set tracerout='"sphum","liq_wat","o3mr"'
  set tracerin='"spfh","clwmr","o3mr"'
else if ($analysistype == 'gfs_sigio') then
  setenv OMP_NUM_THREADS 6
  set atmext='sanl'
  set sfcext='sfcanl'
  set tracerout='"sphum","o3mr","liq_wat"'
  set tracerin='"spfh","o3mr","clwmr"'
endif
# chop timestamp into pieces
set ymd=`echo $CDATE | cut -c 1-8`
set mm=`echo $CDATE | cut -c 5-6`
set dd=`echo $CDATE | cut -c 7-8`
set hh=`echo $CDATE | cut -c 9-10`

# random folder name to avoid I/O race condition
set RANDEXT=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1` 
set WORKDIR=$WORKDIR/chgres_cube_$RANDEXT

# clean up and create folders
set CASEDIR=${ICDIR}/${ymd}.${hh}Z_IC
rm -fr $CASEDIR
mkdir -p $CASEDIR

rm -fr $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

# Threads useful when ingesting spectral gfs sigio files.
# Otherwise set to 1.
setenv OMP_NUM_THREADS 1
setenv OMP_STACKSIZE 1024M

# link executable
ln -s $UTILSDIR/exec/chgres_cube .

#
# process global domains
#
if ($gridtype == 'global') then
  ln -s $GRIDDIR/C${res}_mosaic.nc $WORKDIR/C${res}_mosaic.nc
else if ($gridtype == 'nest') then
  ln -s $GRIDDIR/C${res}_coarse_mosaic.nc $WORKDIR/C${res}_mosaic.nc
else
  echo "$gridtype is not supported yet. Stop"
  exit 1
endif

# set up namelist 
cat <<EOF >$WORKDIR/fort.41
&config
 mosaic_file_target_grid="$WORKDIR/C${res}_mosaic.nc"
 fix_dir_target_grid="$GRIDDIR/fix_sfc"
 orog_dir_target_grid="$GRIDDIR"
 orog_files_target_grid="C${res}_oro_data.tile1.nc","C${res}_oro_data.tile2.nc","C${res}_oro_data.tile3.nc","C${res}_oro_data.tile4.nc","C${res}_oro_data.tile5.nc","C${res}_oro_data.tile6.nc",
 vcoord_file_target_grid="$UTILSDIR/fix/am/${analysislevfile}"
 mosaic_file_input_grid="NULL"
 orog_dir_input_grid="NULL"
 orog_files_input_grid="NULL"
 data_dir_input_grid="${GFSANLDIR}/${CDATE}"
 atm_files_input_grid="gfs.t${hh}z.${atmext}"
 sfc_files_input_grid="gfs.t${hh}z.${sfcext}"
 nst_files_input_grid="gfs.t${hh}z.nstanl.nemsio"
 cycle_mon=$mm
 cycle_day=$dd
 cycle_hour=$hh
 convert_atm=.true.
 convert_sfc=.true.
 convert_nst=.false.
 input_type=$analysistype
 tracers=$tracerout
 tracers_input=$tracerin
 regional=0
 halo_bndy=0
 halo_blend=0 
/
EOF


srun --ntasks=$SLURM_NTASKS ./chgres_cube

#
# move output files to save directory
#
mv gfs_ctrl.nc $CASEDIR/gfs_ctrl.nc
set i = 1
while ($i <= 6 )
  mv out.atm.tile${i}.nc $CASEDIR/gfs_data.tile${i}.nc
  mv out.sfc.tile${i}.nc $CASEDIR/sfc_data.tile${i}.nc
  @ i++
end


if ($gridtype == 'nest') then
  #
  #  process the nest domain
  #
  rm $WORKDIR/C${res}_mosaic.nc
  ln -s $GRIDDIR/C${res}_nested_mosaic.nc $WORKDIR/C${res}_mosaic.nc

  # set up namelist 
cat <<EOF >$WORKDIR/fort.41
&config
 mosaic_file_target_grid="$WORKDIR/C${res}_mosaic.nc"
 fix_dir_target_grid="$GRIDDIR/fix_sfc"
 orog_dir_target_grid="$GRIDDIR"
 orog_files_target_grid="C${res}_oro_data.tile7.nc",
 vcoord_file_target_grid="$UTILSDIR/fix/am/${analysislevfile}"
 mosaic_file_input_grid="NULL"
 orog_dir_input_grid="NULL"
 orog_files_input_grid="NULL"
 data_dir_input_grid="${GFSANLDIR}/${CDATE}"
 atm_files_input_grid="gfs.t${hh}z.${atmext}"
 sfc_files_input_grid="gfs.t${hh}z.${sfcext}"
 nst_files_input_grid="gfs.t${hh}z.nstanl.nemsio"
 cycle_mon=$mm
 cycle_day=$dd
 cycle_hour=$hh
 convert_atm=.true.
 convert_sfc=.true.
 convert_nst=.false.
 input_type=$analysistype
 tracers=$tracerout
 tracers_input=$tracerin
 regional=0
 halo_bndy=0
 halo_blend=0 
/
EOF

  srun --ntasks=$SLURM_NTASKS ./chgres_cube

  #
  # move output files to save directory
  #
  mv out.atm.tile1.nc $CASEDIR/gfs_data.tile7.nc
  mv out.sfc.tile1.nc $CASEDIR/sfc_data.tile7.nc

endif

exit 0
