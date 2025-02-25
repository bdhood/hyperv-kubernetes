
function GetNodeIPs {
    param (
        [array]$VMs
    )
    $result = @{}
    
    foreach ($vm in $VMs) {
        $networkAdapters = Get-VMNetworkAdapter -VMName $vm -ErrorAction SilentlyContinue
        if (-not $networkAdapters) {
            Write-Error "No network adapters found for VM '$($vm)'"
        }
        Write-Host "Waiting for IP address for VM '$($vm)'..."
        while (-not $result[$vm]) {
            foreach ($adapter in $networkAdapters) {
                $ipv4Addresses = $adapter.IPAddresses | Where-Object { $_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$' }
                foreach ($ip in $ipv4Addresses) {
                    $result[$vm] = $ip
                }
            }
            if ($result[$vm]) {
                break
            }
            Start-Sleep -Seconds 2
        }
    }
    return $result
}
