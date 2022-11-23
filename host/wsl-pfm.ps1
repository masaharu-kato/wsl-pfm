#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."
$DATA_DIR = "$ROOT_DIR\data"
$DISTROS_DIR = "$DATA_DIR\distros"

$FW_RULE_NAME = "WSL2_FW_Unlock"

$SYNC_SLEEP_SEC = 1

$global:ErrorActionPreference = 'Stop'

Write-Host "-------------------------------------------- " -ForegroundColor Cyan
Write-Host "    WSL-PFM: WSL Port Forwarding Manager     " -ForegroundColor Cyan
Write-Host "-------------------------------------------- " -ForegroundColor Cyan

Write-Output "Start WSL-PFM on $(Get-Date -UFormat "%Y/%m/%d %H:%M:%S")"

function setFirewall($port) {
    $fwName = "${FW_RULE_NAME}_$port"
    $fw = $null
    try {
        $fw = Get-NetFirewallRule -DisplayName $fwName 2> $null
    } catch {}
    if(!$fw) {
        New-NetFireWallRule -DisplayName $fwName -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP | Out-Null
        $fw = Get-NetFirewallRule -DisplayName $fwName 2> $null
        if(!$fw) { throw "Failed to set Firewall for port $port" }
    }
}

function unsetFirewall($port) {
    $fwName = "${FW_RULE_NAME}_$port"
    $fw = Get-NetFirewallRule -DisplayName $fwName 2> $null
    if($fw) {
        Remove-NetFirewallRule -DisplayName $fwName | Out-Null
    }
}


# Add
# function add_port_fwd($port, $con_addr) {
#     New-NetFireWallRule -DisplayName $fwRuleName -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP
#     netsh interface portproxy add v4tov4 listenport=$port listenaddress=* connectport=$port connectaddress=$con_addr
# }

# Delete
# function delete_port_fwd($lisport, $con_addr) {
#     Remove-NetFireWallRule -DisplayName $fwRuleName
# }

# Show
# function show_port_fwds() {
#     Get-NetFireWallRule -DisplayName $fwRuleName | Get-NetFireWallPortFilter
#     netsh interface portproxy show v4tov4
# }


class PortForwardData {
    [string]$lisAddr
    [string]$lisPort
    [string]$conAddr
    [string]$conPort
}

function getForwardedPorts() {
    $res = netsh interface portproxy show v4tov4
    $is_main = 0
    $portFwds = [System.Collections.Generic.List[PortForwardData]]::new()
    foreach($line in $res) {
        if($is_main) {
            $values = $line -split "\s+"
            $portFwd = [PortForwardData]::new()
            $portFwd.lisAddr = $values[0]
            $portFwd.lisPort = $values[1]
            $portFwd.conAddr = $values[2]
            $portFwd.conPort = $values[3]
            $portFwds.Add($portFwd)
        }
        if($line.StartsWith("-")) { $is_main = 1 }
    }
    return $portFwds
}

function getPortForwardRequests([string]$distro) {
    $portFwds = [System.Collections.Generic.List[PortForwardData]]::new()
    $portsDir = "$DISTROS_DIR/$distro/ports"
    if(Test-Path "$portsDir") {
        foreach($conPortPath in Get-ChildItem "$portsDir/*") {
            foreach($lisPortPath in Get-ChildItem "$conPortPath/*") {
                $portFwd = [PortForwardData]::new()
                $portFwd.lisPort = $lisPortPath.BaseName
                $portFwd.conport = $conPortPath.BaseName
                $portFwds.Add($portFwd)
            }
        }
    }
    return $portFwds
}


function GetContentIfExists($path) {
    if(!(Test-Path "$path")) { return "" }
    return Get-Content "$path"
}


function refreshDistroPortForwards([string]$distro) {
    
    Write-Output "[$distro] Refresh port forwards ..."
    $changed = $false

    $distroDir = "$DISTROS_DIR/$distro"
    $oldIP = GetContentIfExists("$distroDir/forwarded-ip")
    $newIP = GetContentIfExists("$distroDir/ip")

    if(!$newIP) { throw "IP Address is not set." }

    
    # Remove the current port forwardings to the forwarded (old) ip address.
    $old_forwarded_ports = @{} # conPort -> lisPort
    if($oldIP) {
        $old_port_fwds = getForwardedPorts | Where-Object {$_.conAddr -eq $oldIP}
        foreach($pf in $old_port_fwds) { $old_forwarded_ports[$pf.conPort] = $pf.lisPort }
    }

    # Refresh ports
    $pf_reqs = getPortForwardRequests $distro
    foreach($pf in $pf_reqs) {
        $lisPort = $pf.lisPort
        $conPort = $pf.conport

        # If the IP address has changed, or the target is a new port 
        if(($oldIP -ne $newIP) -or (!$old_forwarded_ports[$conPort])) {

            Write-Output "[$distro]   Setting port forwarding *:$lisPort -> ${_newIP}:$conPort ..."
            
            try {
                # If there is a existing port forwarding, delete it
                if($old_forwarded_ports[$conPort]) {
                    $res = netsh interface portproxy delete v4tov4 listenport=$lisPort
                    if($res -match "\S") { Write-Output "[$distro] Warn: delete: $($res.trim())" }
                }

                # Add a new port forwarding
                $res = netsh interface portproxy add v4tov4 listenport=$lisPort listenaddress=* connectport=$conPort connectaddress=$newIP
                if($res -match "\S") { throw "Failed to add v4tov4: $($res.trim())" }

                # Set a Firewall
                setFirewall $lisPort

                Write-Output "[$distro]    -> Successfully done."

            } catch {
                Write-Output "[$distro]    -> Failed: $_"
            }
            $changed = $true
            
        }
        $old_forwarded_ports[$conPort] = $null  # Still forward this port
    }

    # Delete unforwarded ports
    foreach($conPort in $old_forwarded_ports.Keys) {
        # Non-null values of $old_forwarded_ports are unused ports.
        $lisPort = $old_forwarded_ports[$conPort]
        if($lisPort) {
            Write-Output "[$distro]   Delete port forwarding  *:$lisPort -> ${_oldIP}:$conPort"
            
            try {
                # Delete the port forwarding
                $res = netsh interface portproxy delete v4tov4 listenport=$lisPort
                if($res -match "\S") { Write-Output "[$distro] Warn: delete: $($res.trim())" }

                # Unset the Firewall
                unsetFirewall $lisPort
                
                Write-Output "[$distro]    -> Successfully done."

            } catch {
                Write-Output "[$distro]    -> Failed: $_"
            }
            $changed = $true
        }
    }

    # Output new IP as forwarded IP
    $newIP | Out-File "$distroDir/forwarded-ip" -NoNewline -Encoding utf8

    if($changed) {
        Write-Output "[$distro]  -> Done."
    }else{
        Write-Output "[$distro]  -> Nothing to do."
    }
}


function prepareDir($path) {
    # Prepare a directory (make a directory if not exists)
    New-Item "$path" -ItemType Directory -Force | Out-Null
}

# Main

# Init: Get host users and WSL distros
Write-Output "Init ..."
prepareDir "$DISTROS_DIR"

$gDistroList = [System.Collections.Generic.List[string]]::new()

foreach($user in Get-ChildItem $DISTROS_DIR) {
    foreach($distroName in Get-ChildItem "$DISTROS_DIR\$user") {
        $distro = "$user\$distroName"
        $gDistroList.Add($distro)
        Write-Output "Detected: $distro"
    }
}

if(!$gDistroList.Count) {
    Write-Output "Warning: No WSL distros found."
    Write-Output "         To detect, run the script 'bin\set-ip-to-host' on the WSL distro."
}


# Watch files

$gDistroRefreshRequested = @{}
foreach($distro in $gDistroList) {
    $gDistroRefreshRequested[$distro] = $false
}

$gDistroRefreshNeeded = @{}

$REGEX_DISTROS_DIR = "^$($DISTROS_DIR.Replace("\", "\\"))\\(?<user>[^\\]+)\\(?<distro>[^\\]+).*$"

function global:onFileChanged($path) {
    if(!($path -match $REGEX_DISTROS_DIR)) { return }
    $distro = "$($Matches.user)\$($Matches.distro)"

    if($distro) {
        if(!($gDistroList -contains $distro)) {
            Write-Output "New distro detected: $distro"
            $gDistroList.Add($distro)
            $gDistroRefreshNeeded[$distro] = $false
        }
        $gDistroRefreshRequested[$distro] = $true
        Write-Output "[$distro] Detected file change: $path"
    }
}

$action = {
    $path = $Event.SourceEventArgs.FullPath

    # Show the details of event:
    # $changeType = $Event.SourceEventArgs.ChangeType
    # Write-Output "$(Get-Date)`t$changeType`t$path"

    # If $path match **\ip or **\ports\*\*
    if(($path -match "(\\ip|\\ports\\\d+\\\d+)")) {
        try {
            onFileChanged $path
        } catch {
            Write-Output 'An error has occured inside onFileChanged().'
            Write-Output $_
        }
    }
}


Write-Output "Start file watch jobs ..."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "$DISTROS_DIR"
$watcher.Filter = "*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents   = $true

$obj_events = @(
    (Register-ObjectEvent $watcher "Created" -Action $action),
    (Register-ObjectEvent $watcher "Changed" -Action $action),
    (Register-ObjectEvent $watcher "Deleted" -Action $action),
    (Register-ObjectEvent $watcher "Renamed" -Action $action)
)

foreach($distros in $gDistroList) {
    foreach($distro in $distros) {
        $gDistroRefreshNeeded[$distro] = $true
    }
}

Write-Output "Watching files on '$DISTROS_DIR'..."
try {
    while ($true) {
        foreach($distro in $gDistroList) {
            if($gDistroRefreshRequested[$distro]) {
                $gDistroRefreshNeeded[$distro] = $true
                $gDistroRefreshRequested[$distro] = $false
            }
            else{
                if($gDistroRefreshNeeded[$distro]) {
                    try {
                        refreshDistroPortForwards $distro
                    } catch {
                        Write-Output "[$distro]  -> Failed: $_"
                    }
                }
                $gDistroRefreshNeeded[$distro] = $false
            }
        }
        Start-Sleep $SYNC_SLEEP_SEC
    }
} catch {
    Write-Output "An Error has occured."
    Write-Output $_
} finally {
    Write-Host "Removing file watch jobs ..." -ForegroundColor DarkCyan
    foreach($event in $obj_events) {
        Remove-Job -Id $event.Id -Force
    }
}
Write-Output "exit"
