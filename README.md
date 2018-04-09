# scan_hmc
- this tool will generate report of logical IO Drawer architecture and affectations of VIOS and lpars

# prerequisite
- "ssh client" and "expect" installed on your machine

# How to use it
1 - insure that "scan_hmc_make_xls.ksh" and "get_hmc_data.exp" live in the same directoy and have execution permission.

2 - ./scan_hmc_make_xls.ksh \<HMC_ADDRESS\> \<HMC_USER\>

3 - Provide the right information about password \<HMC_USER\>.

4 - Wait for the generated report


