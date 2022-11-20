
$fwRuleName = "WSL 2 Firewall Unlock"
$port = 3000
$con_addr = "" # TODO: Load the current (previous) WSL addresses

# Add
function add($port, $con_addr) {
    New-NetFireWallRule -DisplayName $fwRuleName -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=* connectport=$port connectaddress=$con_addr
}

# Delete
function delete($port, $con_addr) {
    Remove-NetFireWallRule -DisplayName $fwRuleName
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=*
}

# Show
function show() {
    Get-NetFireWallRule -DisplayName $fwRuleName | Get-NetFireWallPortFilter
    netsh interface portproxy show v4tov4
}

# Main
# TODO: Implement