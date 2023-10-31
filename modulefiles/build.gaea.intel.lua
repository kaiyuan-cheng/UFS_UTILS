help([[
Load environment to compile UFS_UTILS on Gaea C5
]])

load(pathJoin("cmake/3.23.1"))
load(pathJoin("intel-classic/2022.2.1"))

--load(pathJoin("craype/2.7.20"))
--load(pathJoin("cray-mpich/8.1.25"))
--
prepend_path( "CMAKE_PREFIX_PATH", "/lustre/f2/pdata/gfdl/gfdl_W/Kai-yuan.Cheng/software/C5/UFS_UTILS_libs/install") 
prepend_path( "LD_LIBRARY_PATH", "/lustre/f2/pdata/gfdl/gfdl_W/Kai-yuan.Cheng/software/C5/UFS_UTILS_libs/install/lib") 
prepend_path( "LD_LIBRARY_PATH", "/lustre/f2/pdata/gfdl/gfdl_W/Kai-yuan.Cheng/software/C5/UFS_UTILS_libs/install/lib64") 
setenv("ESMFMKFILE","/lustre/f2/pdata/gfdl/gfdl_W/Kai-yuan.Cheng/software/C5/UFS_UTILS_libs/install/lib/esmf.mk")

--setenv("CMAKE_C_COMPILER","cc")
--setenv("CMAKE_CXX_COMPILER","CC")
--setenv("CMAKE_Fortran_COMPILER","ftn")

whatis("Description: UFS_UTILS build environment")
