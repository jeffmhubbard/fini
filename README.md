# fini

simple Arch Linux install script  

Get install script  
`curl -sLo fini.sh git.io/Je83b`

Get everything (to CWD)  
`sh fini.sh --fetch`

Install  
`sh fini.sh`

Install with custom package list  
`sh fini.sh -l file.txt`

Install additional package list (while mounted)  
`sh fini.sh --pacstrap file.txt`

# ps

post-install AUR builder  

Install `auracle` and build from `build.txt`  
`sh ps.sh`

Or  
`sh ps.sh -l file.txt`

Specify build directory  
`sh ps.sh -d path`

