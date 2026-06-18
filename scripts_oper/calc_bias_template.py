"""
The script aims at computing the SLA bias of the model wrt observations.

Before executing the script make sure to:
`source /users_home/oda/godae/miniconda3/etc/profile.d/conda.sh`
`conda activate base`
Then launch:
`python calc_bias.py`
"""

import numpy as np
import sys, os
import netCDF4 as nc
from datetime import datetime, timedelta
import argparse
from scipy import ndimage


def calc_bias():

    # TODO Then move the body of the script in here. 
    # Leave out only argument parsing and the call to this function
    return None


def read_mesh_inputs(dir_gofs_mesh):

    print('Gofs mesh files taken from: {}'.format(dir_gofs_mesh))

    file_mesh = os.path.join(dir_gofs_mesh, 'mesh_mask.nc')
    print('Start reading {}'.format(file_mesh))
    fm = nc.Dataset(file_mesh)
    dx = fm.variables['e1t'][:, :, :]
    dy = fm.variables['e2t'][:, :, :]
    nav_lon = fm.variables['nav_lon'][:, :]
    nav_lat = fm.variables['nav_lat'][:, :]
    print('Loaded dx/y and nav_lat/lon variables.')
    fm.close()

    # mdt: mean dynamic topography
    file_mesh = os.path.join(dir_gofs_mesh, 'MDT.nc')
    print('Start reading {}'.format(file_mesh))
    fm = nc.Dataset(file_mesh)
    mdt = fm.variables['mdt'][:,:] 
    print('Loaded mdt variable.')
    fm.close()

    return dx, dy, nav_lon, nav_lat, mdt


def read_nc(file_name, variable):
      
    dataset = nc.Dataset(file_name)
    data = dataset.variables[variable][:]
    dataset.close()

    return data


def gauss_filt(masked_arr, sigma):

      masked_arr.data[masked_arr.mask==1] = 0
      data = masked_arr.data
      data_smooth = ndimage.gaussian_filter(data, sigma)
      masked_arr_out = np.ma.array(data_smooth, mask=masked_arr.mask)

      return masked_arr_out


def write_outputs():

    root_grp = nc.Dataset(file_out, 'w', format='NETCDF4')
    root_grp.description = 'File containing information on the SeaLevelAnomaly model bias.'
    
    # dimensions
    #root_grp.createDimension('time', None)
    dim_y = dx.shape[1]
    dim_x = dx.shape[2]
    root_grp.createDimension('y', dim_y)
    root_grp.createDimension('x', dim_x)
    
    # varibles initialization
    #time = root_grp.createVariable('time', 'f8', ('time',))
    lat_in = root_grp.createVariable('nav_lat', 'f4', ('y','x',))
    lon_in = root_grp.createVariable('nav_lon', 'f4', ('y','x',))
    y = root_grp.createVariable('y', 'f4', ('y',))
    x = root_grp.createVariable('x', 'f4', ('x',))
    bias_in = root_grp.createVariable('bias', 'f4', ('y','x',))
    bias_orig_in = root_grp.createVariable('bias_orig', 'f4', ('y','x',))
    bias_nodiv_in = root_grp.createVariable('bias_nodiv', 'f4', ('y','x',))
    
    # variables writing
    lat_in[:] = nav_lat
    lon_in[:] = nav_lon
    bias_in[:, :] = bias[0, :, :]
    bias_orig_in[:, :] = bias_orig[0, :, :]
    bias_nodiv_in[:, :] = bias_nodiv[0, :, :]
    
    # attrinutes
    lat_in.units = 'degrees_east'
    lon_in.units = 'degrees_north'

    root_grp.close()

    return None


if __name__ == "__main__":

    debug = False #True
    
    file_out = 'bias.nc'
    sigma = 4 #std of the gaussian kernel to be used for smoothing

    parser = argparse.ArgumentParser()
    parser.add_argument('-s','--start', help='Starting date: date being processed minus N days. Formatted as %%Y%%m%%d, e.g. 20211015.', required=True)
    parser.add_argument('-e','--end', help='Ending date: date being processed plus M days. Formatted as %%Y%%m%%d, e.g. 20211015.', required=True)
    parser.add_argument('-d','--dir-sla-unbias', help='Directory hosting output nc files.', required=True)
    parser.add_argument('-a','--arch-gofs-mesh', help='Directory hosting GOFS nc files.', required=True)

    args = parser.parse_args()

    start = args.start
    stop = args.end
    dir_sla = args.dir_sla_unbias
    dir_gofs_mesh = args.arch_gofs_mesh
    dir_sla_obs = "/work/cmcc/cp1/CPS/CMCC-OIS2/inputdata/SLA/INTERP_SLA_eORCA025/"
    dir_sla_mod = "/work/cmcc/cp1/CPS/CMCC-OIS2/run_oce_assim/dummy_member/SSH"
     
    print('Starting the debiasing process...')
    print('First valid date: {}'.format(start))
    print('Last valid date: {}'.format(stop))
     
    #print('Outputs will be saved in {} and {}'.format(dir_sla_obs, dir_sla_mod))
    
    dx, dy, nav_lon, nav_lat, mdt = read_mesh_inputs(dir_gofs_mesh)

    nlat = dx.shape[1]
    nlon = dx.shape[2]
    
    sla = np.ma.array(np.zeros((nlat, nlon)), mask=False)
    err = np.ma.array(np.zeros((nlat, nlon)), mask=False)
    mod = np.ma.array(np.zeros((nlat, nlon)), mask=False)
    md2 = np.ma.array(np.zeros((nlat, nlon)), mask=False)

    date = datetime.strptime(start, "%Y%m%d")
    date_stop = datetime.strptime(stop, "%Y%m%d")
    n_days = (date_stop - date).days + 1
    print('Starting to process {} days...'.format(n_days))
    
    while(date <= date_stop):
  
        print('  Starting to process {}...'.format(datetime.strftime(date, "%Y%m%d")))
        YYYY=date.year
        file_sla = '{}/cesm_sla/{}/sla_reg-eORCA25_{}.nc'.format(dir_sla_obs,YYYY, datetime.strftime(date, "%Y%m%d"))
        file_err = '{}/cesm_err_sla/{}/err_reg-eORCA25_{}.nc'.format(dir_sla_obs,YYYY,datetime.strftime(date, "%Y%m%d"))
        file_mod = '{}/dummy_member_SSH_{}.nc'.format(dir_sla_mod, datetime.strftime(date, "%Y%m%d"))
        
        # sla processing
        sla_tmp = read_nc(file_sla, 'sla')
        sla_tmp = sla_tmp - np.sum((sla_tmp*dx*dy)[sla_tmp.mask==0]) / (np.sum((dx*dy)[sla_tmp.mask==0])) 
        sla = sla + sla_tmp/n_days
        
        # error processing
        err_tmp = read_nc(file_err, 'err') 
        err = err + err_tmp/n_days

        # model processing
        tmp = read_nc(file_mod, 'zos')
        tmp.mask = sla_tmp.mask # forcing model mask to be equal to measure mask, as done in original R script
        tmp = tmp - (mdt - np.sum((mdt*dx*dy)[tmp.mask==0]) / np.sum((dx*dy)[tmp.mask==0])) - np.sum((tmp*dx*dy)[tmp.mask==0]) / np.sum((dx*dy)[tmp.mask==0])
        mod = mod + tmp/n_days
        md2 = md2 + tmp**2/n_days

        date = date + timedelta(days=1)
    
    print('Applying gaussian smoothing...')
    sla_smooth = gauss_filt(sla, sigma)
    err_smooth = gauss_filt(err, sigma)
    mod_smooth = gauss_filt(mod, sigma)
    md2_smooth = gauss_filt(md2, sigma)

    print('Computing bias...')
    bias = sla_smooth - mod_smooth

    # computing weighted bias (std belongs to model, err belongs to satellite product)
    std = np.ma.array(np.zeros((mod_smooth.data.shape[0], mod_smooth.data.shape[1], mod.data.shape[2])), mask=mod_smooth.mask)
    std.data[std.mask==False] = np.sqrt(md2_smooth.data[std.mask==False]-mod_smooth.data[std.mask==False]**2)
    
    bias_orig = bias
    bias_nodiv = bias * (std/(std+err_smooth)) * (np.abs(bias)/np.abs(bias)+std)
    bias = bias_orig * (std**2/(std**2+err_smooth**2)) * (bias**2/(bias**2+std**2))

    # masking values
    bias_orig.data[(bias_orig.mask==1) | (np.abs(bias_orig.data)>1)] = 0
    bias_nodiv.data[(bias_nodiv.mask==1) | (np.abs(bias_nodiv.data)>1)] = 0
    bias.data[(bias.mask==1) | (np.abs(bias.data)>1)] = 0

    #======================================
    print('Creating output netCDF file...')
    #======================================
    write_outputs()

    print('Finished.\n')
    
    if debug:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt 
        
        print('spme plotting for debugging...')
        plt.figure(1); plt.imshow(np.flipud(sla[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(2); plt.imshow(np.flipud(sla_smooth[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(3); plt.imshow(np.flipud(sla_smooth[0, :, :]-sla[0, :, :]), vmin=-0.05, vmax=+0.05); plt.colorbar(); #plt.show(block=True)
        plt.figure(4); plt.imshow(np.flipud(err[0, :, :])); plt.colorbar(); #plt.show(block=True)
        plt.figure(5); plt.imshow(np.flipud(err_smooth[0, :, :])); plt.colorbar(); #plt.show(block=True)
        plt.figure(6); plt.imshow(np.flipud(err_smooth[0, :, :]-err[0, :, :])); plt.colorbar(); #plt.show(block=True)
        plt.figure(7); plt.imshow(np.flipud(mod[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(8); plt.imshow(np.flipud(mod_smooth[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(9); plt.imshow(np.flipud(mod_smooth[0, :, :]-mod[0, :, :]), vmin=-0.05, vmax=+0.05); plt.colorbar(); #plt.show(block=True)
        plt.figure(10); plt.imshow(np.flipud(md2[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(11); plt.imshow(np.flipud(md2_smooth[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(12); plt.imshow(np.flipud(md2_smooth[0, :, :]-md2[0, :, :]), vmin=-0.05, vmax=+0.05); plt.colorbar(); #plt.show(block=True)
        plt.figure(13); plt.imshow(np.flipud(bias_orig[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(14); plt.imshow(np.flipud(bias_nodiv[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); #plt.show(block=True)
        plt.figure(15); plt.imshow(np.flipud(bias[0, :, :]-md2[0, :, :]), vmin=-0.5, vmax=+0.5); plt.colorbar(); plt.show(block=True)
        plt.show()
    
