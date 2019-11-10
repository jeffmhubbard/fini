# fini

simple menu-driven Arch Linux install script  

Get everything (to CWD)  
`curl -sL git.io/Je83b | bash -s -- --fetch`

Install  
`./fini.sh`

Install with custom package list  
`./fini.sh -l FILE`

Install additional package lists (while mounted)  
`./fini.sh --pacstrap FILE`

# ps

post-install AUR builder  

Install `auracle` and build from `build.txt`  
`./ps.sh`

Or  
`./ps.sh -l FILE`

Specify build directory  
`./ps.sh -d PATH`

