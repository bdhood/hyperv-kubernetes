function UpdateRemoteHosts {
    param (
        [string]$nodeName,
        [hashtable]$nodeIPs
    )

    $hostsContent = @"
127.0.0.1       localhost

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
"@

    $hostsContent += "`n`n# Nodes"
    foreach ($node in $nodeIPs.Keys) {
        $ip = $nodeIPs[$node]
        if ($node -eq $nodeName) {
            $hostsContent += "`n127.0.0.1   $node"
        } else {
            $hostsContent += "`n$ip   $node"
        }
    }
    $hostsContent += "`n"

    ssh -i "./data/id_rsa" `
      -o LogLevel=ERROR -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
      "node@$nodeName" "echo '$hostsContent' | sudo tee /etc/hosts > /dev/null"
}