
. ./src/hyperv/get-ips.ps1
. ./src/update-hosts.ps1
. ./src/update-remote-hosts.ps1
. ./src/utils/ssh.ps1

function Validate {
    # validate VMs exist and are on
    $vms = Get-VM | Where-Object { $nodeNames -contains $_.Name -and $_.State -eq 'Running' }
    if ($vms.Count -eq 0) {
        Write-Error 'Failed. No Running Hyper-VMs found'
    }
    ValidateSSH -nodeNames $nodeNames
    SshRunScript -nodeName $nodeNames[0] -scriptPath './src/remote-scripts/check-cluster.sh' -cli_args ($nodeCount) -allowError $true | Tee-Object -Variable result
    if (-not ($result -match 'Success: Cluster is ready')) {
        Write-Error 'Failed. check-cluster.sh failed'
    }

    Write-Output 'Checking host kubeconfig...'
    if ((kubectl config get-contexts -o name) -notcontains 'kubernetes-super-admin@kubernetes') {
        Write-Error 'kubectl is not configured'
    }

    Write-Output "Checking host connectivity..."
    kubectl version --request-timeout=2s 2>&1

    Write-Output 'Validation successful!'
}


function Setup {
    UpdateHosts -HostMappings (GetNodeIPs -VMs $nodeNames)
    RemoveSshKnownHosts -nodeNames $nodeNames
    ValidateSSH -nodeNames $nodeNames

    foreach ($node in $nodeNames) {
        UpdateRemoteHosts -nodeName $node -nodeIPs (GetNodeIPs -VMs $nodeNames)
        SshRunScript `
            -nodeName $node `
            -scriptPath './src/remote-scripts/node-init.sh' `
            -cli_args ($node, $nodeCount) `
            | Tee-Object -Variable result
        if (-not ($result -match 'Success: node-init.sh completed')) {
            Write-Error "Failed to initialize node $node"
        }
    }

    SshRunScript -nodeName $nodeNames[0] -scriptPath './src/remote-scripts/check-cluster.sh' -cli_args ($nodeCount) -allowError $true `
        | Tee-Object -Variable result
    if (-not ($result -match 'Success: Cluster is ready')) {
        SshRunScript -nodeName $nodeNames[0] -scriptPath './src/remote-scripts/master-init.sh' -cli_args ($nodeCount) `
            | Tee-Object -Variable result
        if (-not ($result -match 'Success: master-init.sh completed')) {
            Write-Error 'Failed to initialize master node'
        }
        SshRunCommand -nodeName $nodeNames[0] -command 'kubeadm token create --print-join-command' `
            | Tee-Object -Variable join_command
        $join_command += ' | tee kubeadm-join-output.txt'
        for ($i = 1; $i -lt $nodeCount; $i++) {
            SshRunCommand -nodeName $nodeNames[$i] -command $join_command
        }
    }

    Write-Output 'Retrieving kubeconfig...'
    if (-not (Test-Path './data')) {
        New-Item -ItemType Directory -Path './data'
    }
    $kubeConfig = (SshRunCommand -nodeName $nodeNames[0] -command 'cat /root/.kube/config')
    if ($kubeConfig -match 'kubernetes-super-admin@kubernetes') {
        Set-Content -Path './data/kubeconfig' -Value $kubeConfig
        Write-Output 'Kubeconfig saved to ./data/kubeconfig'
        Copy-Item -Path './data/kubeconfig' -Destination "$env:USERPROFILE\.kube\config" -Force
    }
    else {
        Write-Error 'Failed to get kubeconfig'
    }
    if ((kubectl config get-contexts -o name) -notcontains 'kubernetes-super-admin@kubernetes') {
        Write-Error 'kubectl is not configured'
    }
}

function StartNodes {
    foreach ($node in $nodeNames) {
        Write-Output "Starting VM '$node'"
        Start-VM -Name $node
    }
}

function StopNodes {
    foreach ($node in $nodeNames) {
        Write-Output "Stopping VM '$node'"
        Stop-VM -Name $node -Force -TurnOff
    }
}
