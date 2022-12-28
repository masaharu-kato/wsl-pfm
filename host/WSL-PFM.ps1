#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."
$DIR_WSL_PFM = "$ROOT_DIR\data"
$DIR_DISTROS = "$DIR_WSL_PFM\distro"

$FW_RULE_NAME = "WSL2_FW_Unlock"

$SYNC_SLEEP_SEC = 1

# Start initialization
Write-Output "-------------------------------------------- "
Write-Output "    wsl-pfm: WSL Port Forwarding Manager "
Write-Output "-------------------------------------------- "

Write-Output "Init ..."
New-Item $DIR_WSL_PFM -ItemType Directory -Force | Out-Null  # mkdir -p
New-Item $DIR_DISTROS -ItemType Directory -Force | Out-Null  # mkdir -p
$distroList = $data = [System.Collections.Generic.List[string]]::new()
foreach ($path in Get-ChildItem $DIR_DISTROS) {
    $distroList.Add($path.BaseName)
}


function setFirewall($port) {
    $fw_name = "${FW_RULE_NAME}_$port"
    $fw = Get-NetFirewallRule -DisplayName $fw_name 2> $null
    if (!$fw) {
        $fw = New-NetFireWallRule -DisplayName $fw_name -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP | Out-Null
        $fw = Get-NetFirewallRule -DisplayName $fw_name 2> $null
        if (!$fw) { throw "Failed to set Firewall for port $port" }
    }
}

function unsetFirewall($port) {
    $fw_name = "${FW_RULE_NAME}_$port"
    $fw = Get-NetFirewallRule -DisplayName $fw_name 2> $null
    if ($fw) {
        Remove-NetFirewallRule -DisplayName $fw_name | Out-Null
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
    $data = [System.Collections.Generic.List[PortForwardData]]::new()
    foreach ($line in $res) {
        if ($is_main) {
            $values = $line -split "\s+"
            $cdata = [PortForwardData]::new()
            $cdata.lisAddr = $values[0]
            $cdata.lisPort = $values[1]
            $cdata.conAddr = $values[2]
            $cdata.conPort = $values[3]
            $data.Add($cdata)
        }
        if ($line.StartsWith("-")) { $is_main = 1 }
    }
    return $data
}

function getPortForwardRequests($distro) {
    $data = [System.Collections.Generic.List[PortForwardData]]::new()
    if (Test-Path "$DIR_DISTROS/$distro/ports") {
        foreach ($con_port_path in Get-ChildItem "$DIR_DISTROS/$distro/ports/*") {
            foreach ($lis_port_path in Get-ChildItem "$con_port_path/*") {
                $cdata = [PortForwardData]::new()
                $cdata.lisPort = $lis_port_path.BaseName
                $cdata.conport = $con_port_path.BaseName
                $data.Add($cdata)
            }
        }
    }
    return $data
}


function GetContentIfExists($path) {
    if (!(Test-Path "$path")) { return "" }
    return Get-Content "$path"
}


function refreshDistroPortForwards($distro) {
    $old_ip = GetContentIfExists("$DIR_DISTROS/$distro/forwarded-ip")
    $new_ip = GetContentIfExists("$DIR_DISTROS/$distro/ip")

    if (!$new_ip) { throw "IP Address is not set." }
    
    # Remove the current port forwardings to the forwarded (old) ip address.
    $old_forwarded_ports = @{} # conPort -> lisPort
    if ($old_ip) {
        $_old_port_fwds = getForwardedPorts | Where-Object { $_.conAddr -eq $old_ip }
        foreach ($pf in $_old_port_fwds) { $old_forwarded_ports[$pf.conPort] = $pf.lisPort }
    }

    # Refresh ports
    $pf_reqs = getPortForwardRequests $distro
    foreach ($pf in $pf_reqs) {
        $lisPort = $pf.lisPort
        $conPort = $pf.conport

        # If the IP address has changed, or the target is a new port 
        if (($old_ip -ne $new_ip) -or (!$old_forwarded_ports[$conPort])) {

            Write-Output "[$distro]   Setting port forwarding *:$lisPort -> ${new_ip}:$conPort ..."
            
            try {
                # If there is a existing port forwarding, delete it
                if ($old_forwarded_ports[$conPort]) {
                    $res = netsh interface portproxy delete v4tov4 listenport=$lisPort
                    if ($res -match "\S") { Write-Output "[$distro] Warn: delete: $($res.trim())" }
                }

                # Add a new port forwarding
                $res = netsh interface portproxy add v4tov4 listenport=$lisPort listenaddress=* connectport=$conPort connectaddress=$new_ip
                if ($res -match "\S") { throw "Failed to add v4tov4: $($res.trim())" }

                # Set a Firewall
                setFirewall $lisPort

                Write-Output "[$distro]    -> Successfully done."

            }
            catch {
                Write-Output "[$distro]    -> Failed: $_"
            }
            
        }
        $old_forwarded_ports[$conPort] = $null  # Still forward this port
    }

    # Delete unforwarded ports
    foreach ($conPort in $old_forwarded_ports.Keys) {
        # Non-null values of $old_forwarded_ports are unused ports.
        $lisPort = $old_forwarded_ports[$conPort]
        if ($lisPort) {
            Write-Output "[$distro]   Delete port forwarding  *:$lisPort -> ${old_ip}:$conPort"
            
            try {
                # Delete the port forwarding
                $res = netsh interface portproxy delete v4tov4 listenport=$lisPort
                if ($res -match "\S") { Write-Output "[$distro] Warn: delete: $($res.trim())" }

                # Unset the Firewall
                unsetFirewall $lisPort
                
                Write-Output "[$distro]    -> Successfully done."

            }
            catch {
                Write-Output "[$distro]    -> Failed: $_"
            }
        }
    }

    # Output new IP as forwarded IP
    $new_ip | Out-File "$DIR_DISTROS/$distro/forwarded-ip" -NoNewline -Encoding utf8
}


$DIR_DISTROS_FOR_REGEX = $DIR_DISTROS.Replace("\", "\\")
$REGEX_DISTRO_PATH = "^$DIR_DISTROS_FOR_REGEX\\(?<distro>[^\\]+).*$"
# Write-Output "REGEX_DISTRO_PATH: $REGEX_DISTRO_PATH"

function getDistroFromPath($path) {
    if ($path -match $REGEX_DISTRO_PATH) { return $Matches.distro }
    return ""
}

# Main

# Watch files

$distroRefreshRequested = @{}
foreach ($distro in $distroList) {
    $distroRefreshRequested[$distro] = $false
}

$distroRefreshNeeded = @{}

function global:onFileChanged($path) {
    $distro = getDistroFromPath $path
    if ($distro) {
        if (!($distroList -contains $distro)) {
            Write-Output "New distro detected: $distro"
            $distroList.Add($distro)
            $distroRefreshNeeded[$distro] = $false
        }
        $distroRefreshRequested[$distro] = $true
        Write-Output "[$distro] Detected file change: $path"
    }
}

$action = {
    $path = $Event.SourceEventArgs.FullPath
    # $changeType = $Event.SourceEventArgs.ChangeType
    # Write-Output "$(Get-Date)`t$changeType`t$path"
    if (($path -match "(\\ip|\\ports\\\d+\\\d+)")) {
        try {
            onFileChanged $path
        }
        catch {
            Write-Output 'An error has occured inside onFileChanged().'
            Write-Output $_
        }
    }
}


Write-Output "Start file watch jobs ..."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "$DIR_DISTROS"
$watcher.Filter = "*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$obj_events = @(
    (Register-ObjectEvent $watcher "Created" -Action $action),
    (Register-ObjectEvent $watcher "Changed" -Action $action),
    (Register-ObjectEvent $watcher "Deleted" -Action $action),
    (Register-ObjectEvent $watcher "Renamed" -Action $action)
)

foreach ($distro in $distroList) {
    $distroRefreshNeeded[$distro] = $true
}

Write-Output "Watching files ..."
try {
    while ($true) {
        foreach ($distro in $distroList) {
            if ($distroRefreshRequested[$distro]) {
                $distroRefreshNeeded[$distro] = $true
                $distroRefreshRequested[$distro] = $false
            }
            else {
                if ($distroRefreshNeeded[$distro]) {
                    Write-Output "[$distro] Refresh port forwards ..."
                    try {
                        refreshDistroPortForwards $distro
                        Write-Output "[$distro]  -> Done."
                    }
                    catch {
                        Write-Output "[$distro]  -> Failed: $_"
                    }
                }
                $distroRefreshNeeded[$distro] = $false
            }
        }
        Start-Sleep $SYNC_SLEEP_SEC
    }
}
finally {
    
    Write-Output "Removing file watch jobs ..."
    foreach ($event in $obj_events) {
        Remove-Job -Id $event.Id -Force
    }

    Write-Output "exit"
}