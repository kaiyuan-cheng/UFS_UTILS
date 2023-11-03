#!/bin/tcsh

#SBATCH --ntasks=32
#SBATCH --output=./%x.o%j
#SBATCH --cluster=c5
#SBATCH --qos=debug
#SBATCH --account=gfdl_w
#SBATCH --time=00:60:00


set echo
# Threads useful when ingesting spectral gfs sigio files.
# Otherwise set to 1.
setenv OMP_NUM_THREADS 1
setenv OMP_STACKSIZE 1024M

# case configurations
set res=424            # resolution of tile: 48, 96, 192, 384, 96, 1152, 3072
set CASE=C$res
if (! $?CDATE) then
  set CDATE=2020063000
endif
set bc_freq=6          # hour interval between two BCs 
set CDURATION=24       # simulation duration
set ICDIR=/lustre/f2/dev/${USER}/SHiELD_IC/REG_C$res
set UTILSDIR=/ncrc/home2/Kai-yuan.Cheng/software/UFS_UTILS
set FIXDIR=/lustre/f2/dev/gfdl/Kai-yuan.Cheng/UFS_UTILS_RETRO_DATA/my_grids
set GFSANLDIR=/lustre/f2/dev/gfdl/Kai-yuan.Cheng/UFS_UTILS_RETRO_DATA/GFSvOPER
set WORKDIR=/lustre/f2/scratch/gfdl/${USER}/wrk.chgres

# probably don't have to change anything below here.

set ymd=`echo $CDATE | cut -c 1-8`
set hhc=`echo $CDATE | cut -c 9-10`

# random folder name to avoid I/O race condition
set RANDEXT=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1` 
set WORKDIR=$WORKDIR/chgres_cube_$RANDEXT

# clean up and create folders
set CASEDIR=${ICDIR}/${ymd}.${hhc}Z_IC
rm -fr $CASEDIR
mkdir -p $CASEDIR

mkdir -p $WORKDIR
cd $WORKDIR

ln -sf $FIXDIR/$CASE $WORKDIR  

#
# set the links to use the 4 halo grid and orog files
# these are necessary for creating the boundary data
#
 ln -sf $FIXDIR/$CASE/${CASE}_grid.tile7.halo4.nc $WORKDIR/$CASE/${CASE}_grid.tile7.nc
 ln -sf $FIXDIR/$CASE/${CASE}_oro_data.tile7.halo4.nc $WORKDIR/$CASE/${CASE}_oro_data.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.vegetation_greenness.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.vegetation_greenness.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.soil_type.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.soil_type.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.slope_type.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.slope_type.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.substrate_temperature.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.substrate_temperature.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.facsf.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.facsf.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.maximum_snow_albedo.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.maximum_snow_albedo.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.snowfree_albedo.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.snowfree_albedo.tile7.nc
 ln -sf $FIXDIR/$CASE/fix_sfc/${CASE}.vegetation_type.tile7.halo4.nc $WORKDIR/$CASE/${CASE}.vegetation_type.tile7.nc


ln -s $UTILSDIR/exec/chgres_cube .

set bc_hour = 0


while ($bc_hour <= $CDURATION)
  set DATE = `date -d "$ymd $hhc+$bc_hour hour" +"%Y%m%d%H"`
  set yyyy=`echo $DATE | cut -c 1-4`
  set mm=`echo $DATE | cut -c 5-6`
  set dd=`echo $DATE | cut -c 7-8`
  set hh=`echo $DATE | cut -c 9-10`

  if ($bc_hour == 0) then
    set regional = 1
    set convert_sfc = .true.
  else
    set regional = 2
    set convert_sfc = .false.
  endif

cat <<EOF >$WORKDIR/fort.41
&config
 mosaic_file_target_grid="$WORKDIR/C$res/C${res}_mosaic.nc"
 fix_dir_target_grid="$WORKDIR/C$res"
 orog_dir_target_grid="$WORKDIR/C$res"
 orog_files_target_grid="C${res}_oro_data.tile7.halo4.nc"
 vcoord_file_target_grid="$UTILSDIR/fix/am/global_hyblev.l65.txt"
 mosaic_file_input_grid="NULL"
 orog_dir_input_grid="NULL"
 orog_files_input_grid="NULL"
 data_dir_input_grid="${GFSANLDIR}/${DATE}"
 atm_files_input_grid="gfs.t${hh}z.atmanl.nemsio"
 sfc_files_input_grid="gfs.t${hh}z.sfcanl.nemsio"
 nst_files_input_grid="gfs.t${hh}z.nstanl.nemsio"
 cycle_mon=$mm
 cycle_day=$dd
 cycle_hour=$hh
 convert_atm=.true.
 convert_sfc=$convert_sfc
 convert_nst=.false.
 input_type="gaussian_nemsio"
 tracers="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
 tracers_input="spfh","clwmr","o3mr","icmr","rwmr","snmr","grle"
 halo_bndy=4
 halo_blend=0
 regional=$regional
/
EOF


  srun --ntasks=32 ./chgres_cube

  if ($? != 0) then
    echo "Something is wrong. Exiting..."
    exit
  endif
#
# move output files to save directory
#
  if ($bc_hour == 0) then
    mv gfs_ctrl.nc $CASEDIR/gfs_ctrl.nc
    mv out.atm.tile7.nc $CASEDIR/gfs_data.tile7.nc
    mv out.sfc.tile7.nc $CASEDIR/sfc_data.tile7.nc
    mv gfs.bndy.nc $CASEDIR/gfs_bndy.tile7.000.nc
  else

   if ($bc_hour < 10) then
     set bc_hour2 = 00$bc_hour
   else if ($bc_hour < 100) then
     set bc_hour2 = 0$bc_hour
   else
     set bc_hour2 = $bc_hour
   endif 

    mv gfs.bndy.nc $CASEDIR/gfs_bndy.tile7.${bc_hour2}.nc
  endif

  @ bc_hour = $bc_hour + $bc_freq 

end


exit 0
