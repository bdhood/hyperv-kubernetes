<#
.SYNOPSIS
    Manage a Kubernetes cluster on Hyper-V.

.DESCRIPTION
    This script manages a Kubernetes cluster on Hyper-V. It uses Packer to create a base VM image, then creates multiple VMs from that image. 
    The script then initializes the VMs to create a Kubernetes cluster. The script can also stop, start, or delete the VMs.

    ./hyperv-kubernetes.ps1 start
        - Creates and starts the VMs, initializes the cluster, and validates the cluster.
    ./hyperv-kubernetes.ps1 stop 
        - Stops the VMs.
    ./hyperv-kubernetes.ps1 restart 
        - Restarts the VMs, validates the cluster
    ./hyperv-kubernetes.ps1 delete-nodes 
        - Deletes the VMs. Does not delete the base VM image.
    ./hyperv-kubernetes.ps1 delete-all 
        - Deletes the VMs, the base VM image, and the data directory.
    ./hyperv-kubernetes.ps1 rebuild 
        - Deletes the VMs, rebuilds the base VM image, creates and starts the VMs, initializes the cluster, and validates the cluster.


.PARAMETER Command
    The command to run, one of 'validate', 'start', 'stop', 'restart', 'delete-nodes', 'rebuild', 'delete-all'.

.NOTES
    Version: 1.0
#>

[CmdletBinding()]
Param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('validate', 'start', 'stop', 'restart', 'delete-nodes', 'rebuild', 'delete-all')]
    [string]$Command
)

$ErrorActionPreference = 'Stop'

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'This script must be run as an administrator'
}


. ./src/hyperv/create.ps1
. ./src/hyperv/delete.ps1
. ./src/utils/ssh.ps1
. ./src/utils/packer.ps1
. ./src/cluster.ps1

# Read and parse the JSON file
$configContent = Get-Content ".\config.json" -Raw | ConvertFrom-Json

# Access Config Values
$nodeCount = $configContent.nodeCount
$nodeCpus = $configContent.nodeCpus
$nodeMemory = $configContent.nodeMemory
$nodeDisk = $configContent.nodeDisk
$VMPath = $configContent.VMPath
$nodeNames = 1..$nodeCount | ForEach-Object { 'node-' + ($_.ToString().PadLeft(2, '0')) }

switch ($Command) {
    validate { 
        Validate
    }
    start {
        GenerateSSHKey
        RunPacker -VMPath $VMPath -nodeCpus $nodeCpus -nodeMemory $nodeMemory -nodeDisk $nodeDisk
        CreateNodes -nodeNames $nodeNames -VMPath $VMPath -nodeCpus $nodeCpus -nodeMemory $nodeMemory
        StartNodes
        Setup
        Validate
    }
    stop { 
        StopNodes
    }
    restart { 
        StopNodes
        StartNodes
        Validate
    }
    delete-nodes { 
        DeleteAllNodes -nodeNames $nodeNames -VMPath $VMPath
    }
    delete-all { 
        DeleteAllNodes -nodeNames $nodeNames -VMPath $VMPath
        foreach ($path in @("$VMPath\node-base", './data', "./packer/http/preseed.cfg")) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -Confirm:$false -Verbose
            }
        }
    }
    rebuild { 
        DeleteAllNodes -nodeNames $nodeNames -VMPath $VMPath
        RunPacker -VMPath $VMPath -nodeCpus $nodeCpus -nodeMemory $nodeMemory -nodeDisk $nodeDisk -force $true
        CreateNodes -nodeNames $nodeNames -VMPath $VMPath -nodeCpus $nodeCpus -nodeMemory $nodeMemory
        StartNodes
        Setup
        Validate
    }
    Default {
        Write-Error 'Invalid command'
    }
}
