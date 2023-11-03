#!/lustre/f2/pdata/gfdl/gfdl_W/Kai-yuan.Cheng/software/miniconda3/bin/python

import numpy as np
from ctypes import *
import numpy.ctypeslib as ctl


def main():
# global-nest grid configuration
    res = 768
    target_lon = -97.5
    target_lat = 36.5
    refine_ratio = 3
    stretch_factor = 1.0
    ioffset = 0      #if center_nest > 0; use same value as in namelist, NOT supergrid!!
    joffset = 0      #if center_nest > 0; use same value as in namelist, NOT supergrid!!
    inest_size = 480  #in coarse grid cells; should be even
    jnest_size = 320  #in coarse grid cells; should be even

    nest_domain_position(res, target_lon, target_lat, refine_ratio, stretch_factor, ioffset, joffset, inest_size, jnest_size)


def nest_domain_position(res, target_lon, target_lat, refine_ratio, stretch_factor, ioffset, joffset, inest_size, jnest_size):
    #
    # prepare variables before calling create_gnomonic_cubic_grid()
    #
    if ioffset == 0:
        ioffset = ( res - inest_size ) / 2 + 1
    if joffset == 0:  
        joffset = ( res - jnest_size ) / 2 + 1

    istart_nest = int(ioffset * 2 - 1)
    iend_nest   = int(istart_nest + inest_size * 2 - 1)
    jstart_nest = int(joffset * 2 - 1)
    jend_nest   = int(jstart_nest + jnest_size * 2 - 1)
    
    print("--istart_nest {} --jstart_nest {} --iend_nest {} --jend_nest {}".format(str(istart_nest), str(jstart_nest), str(iend_nest), str(jend_nest)) )

    nlon = res * 2
    nested = True
    do_schmidt = 1
    parent_tile = 6
    halo = 3

    if nested:
        ntiles = 7
        nest_grid = 1
    else:
        ntiles = 6
        nest_grid = 0

    nxl = np.ones((ntiles), dtype=np.int32) * nlon
    nyl = np.ones((ntiles), dtype=np.int32) * nlon

    if nested:
        nx_nest = (iend_nest-istart_nest+1)*refine_ratio
        ny_nest = (jend_nest-jstart_nest+1)*refine_ratio
        nxl[-1] = nx_nest
        nyl[-1] = ny_nest

    nx = nlon
    ny = nlon
    nxp = nx+1
    nyp = ny+1

    size1 = nxp*nyp*ntiles
    size2 = nxp*(nyp+1)*ntiles
    size3 = (nxp+1)*nyp*ntiles
    size4 = nxp    *nyp*ntiles

    if nested:
        size1 += nxl[-1]*nyl[-1]
        size2 += nxl[-1]*nyl[-1]
        size3 += nxl[-1]*nyl[-1]
        size4 += nxl[-1]*nyl[-1]

    x = np.zeros(size1, dtype=np.float64)
    y = np.zeros(size1, dtype=np.float64)
    dx = np.zeros(size2, dtype=np.float64)
    dy = np.zeros(size3, dtype=np.float64)
    area = np.zeros(size4, dtype=np.float64)
    angle_dx = np.zeros(size1, dtype=np.float64)
    angle_dy = np.zeros(size1, dtype=np.float64)
    
    #
    #  import functions from make_hgrid and call create_gnomonic_cubic_grid
    #
    so_file = "/ncrc/home2/Kai-yuan.Cheng/jupyter/libmake_hgrid.so"

    make_hgrid = CDLL(so_file)

    create_gnomonic_cubic_grid = make_hgrid.create_gnomonic_cubic_grid

    #i_array = ctl.ndpointer(np.int64, flags='aligned, c_contiguous')
    d_array = ctl.ndpointer(np.float64, flags='aligned, c_contiguous')

    create_gnomonic_cubic_grid.argtypes = [c_char_p, c_void_p, c_void_p, d_array, d_array, d_array, d_array, d_array, d_array, d_array, c_double, c_int, c_double, c_double, c_double, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int]

    gtype = "gnomonic_ed"
    b_gtype = gtype.encode('utf-8')
    create_gnomonic_cubic_grid(b_gtype, nxl.ctypes, nyl.ctypes, x, y, dx, dy, area, angle_dx, angle_dy,
                               18., do_schmidt, stretch_factor, target_lon, target_lat, nest_grid, parent_tile, refine_ratio, istart_nest, iend_nest, jstart_nest, jend_nest, halo )

    #
    # plot domain position
    #
    import matplotlib.pyplot as plt
    from matplotlib.collections import LineCollection
    from cartopy.mpl.ticker import LongitudeFormatter, LatitudeFormatter
    import cartopy.crs as ccrs
    import cartopy.feature as cfeature


    projection = ccrs.Orthographic(target_lon, target_lat)
    fig, ax = plt.subplots(1, 1, figsize=(6, 6), dpi = 150 , subplot_kw={'projection': projection })
    ax.set_global()
    ax.add_feature(cfeature.NaturalEarthFeature(
        'cultural', 'admin_0_boundary_lines_land', '50m',
        edgecolor='k', facecolor='none',linewidth=0.75))

    ax.add_feature(cfeature.NaturalEarthFeature(
        'physical', 'coastline', '50m',
        edgecolor='k', facecolor='none',linewidth=0.75))

    ax.add_feature(cfeature.NaturalEarthFeature(
        'physical', 'lakes', '110m',
        edgecolor='grey', facecolor='none', linewidth=0.5))

    ax.add_feature(cfeature.NaturalEarthFeature(
        'cultural', 'admin_1_states_provinces_lines', '50m',
        edgecolor='gray', facecolor='none', linewidth=0.5))

    # line specifications
    global_bd = 1
    global_col = 'r'
    nest_bd = 1
    nest_lw = 0.5
    nest_col = 'b'

    # size for reshaping 1D array into 2D array
    segment = nxp*nyp
    # slice indices
    bd_ind = [(0,slice(None,None)), (slice(None,None),0), (-1,slice(None,None)), (slice(None,None),-1) ]
    # global domains
    for n in range(6):
        lon = x[n*segment:segment*(n+1)].reshape((nxp, nyp))
        lat = y[n*segment:segment*(n+1)].reshape((nxp, nyp))

        # plot edges
        for bd in bd_ind:
            # special treatment for lon = 180
            if np.amax(abs(np.diff(lon[bd]))) > 300.:
                lon_select = lon[bd]
                lon_select[lon_select > 180.] = lon_select[lon_select > 180.] - 360
                ax.plot(lon_select, lat[bd], color=global_col, lw = global_bd,transform=ccrs.PlateCarree())
            else:
                ax.plot(lon[bd], lat[bd], color=global_col, lw = global_bd,transform=ccrs.PlateCarree())

    # nest domain
    nx_nest = nxl[-1]+1
    ny_nest = nyl[-1]+1

    lon = x[segment*6:(segment*6+nx_nest*ny_nest)].reshape((ny_nest, nx_nest))
    lat = y[segment*6:(segment*6+nx_nest*ny_nest)].reshape((ny_nest, nx_nest))

    # plot edges
    for bd in bd_ind:
        ax.plot(lon[bd], lat[bd], color=nest_col, lw = nest_bd,transform=ccrs.PlateCarree())

    plt.show()


if __name__ == "__main__":
    main()

