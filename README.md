# WSL-Port-Forwarding-Manager (WSL-PFM)

Port Forwarding Manager for WSL (Windows Subsystem for Linux)

## Installation

1. Run `.\Install.ps1 -d Ubuntu` on PowerShell with administrator on Windows. (Replace `Ubuntu` to your WSL distro name)
1. (Option) Set `wsl-pfm set-ip` command to run on the WSL startup   
(consider using WSL-RC-Local: https://github.com/masaharu-kato/wsl-rc-local )
1. Reboot the host (Windows) machine (NOT shutdown and boot, but Reboot)

## How to use
* On the WSL, run following commands.
* You can set port forwardings by multiple WSL distributions.  
(Run commands on each distribution.)
* For more information, try `wsl-pfm --help`.

### Add
* `wsl-pfm add from 8080`  
`wsl-pfm add to 8080`  
`wsl-pfm add 8080`  
Add a new port forwarding: Host `:8080` -> WSL `:8080`

* `wsl-pfm add from 8080 to 80`  
`wsl-pfm add to 80 from 8080`  
`wsl-pfm add 80 from 8080`  
Add a new port forwarding: Host `:8080` -> WSL `:80`

### Delete
* `wsl-pfm delete from 8080`  
`wsl-pfm delete 8080`  
Delete the port forwarding: Host `:8080` -> WSL `:8080`

* `wsl-pfm delete from 8080 to 80`  
`wsl-pfm delete to 80 from 8080`  
`wsl-pfm delete 80 from 8080`  
Delete the port forwarding: Host `:8080` -> WSL `:80`

### Show
* `wsl-pfm show`  
Show informations about port forwardings.


## Uninstallation

1. Run `.\Uninstall.ps1 -d Ubuntu` on PowerShell with administrator on Windows. (Replace `Ubuntu` to your WSL distro name)
1. (Option) Unset `wsl-pfm set-ip` command to run on the WSL startup 
1. Reboot the host (Windows) machine
