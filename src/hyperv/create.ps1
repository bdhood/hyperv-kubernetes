function CreateNodes {
    param (
        [array]$nodeNames,
        [string]$VMPath,
        [int]$nodeCpus,
        [int]$nodeMemory
    )

    $vmcx = Get-ChildItem -Path "${VMPath}\node-base" -Recurse -Filter "*.vmcx" | Select-Object -ExpandProperty FullName
    if (-Not $vmcx) {
        Write-Error "Failed to find the .vmcx file for VM '$VMName'"
    }

    foreach ($node in $nodeNames) {
        # if the VM already exists, skip it
        if (Get-VM | Where-Object { $_.Name -eq $node }) {
            Write-Host "VM '$node' already exists. Skipping..."
            continue
        }

        # if the VM folder already exists, skip it
        if (Test-Path -Path "$VMPath\$node") {
            Write-Warning "VM folder '$VMPath\$node' already exists, but the VM is not registered. Removing the folder..."
            Remove-Item -Path "$VMPath\$node" -Recurse -Force
        }

        Start-Job -ScriptBlock {
            param($vmcx, $node, $VMPath, $nodeCpus, $nodeMemory)
            $vm = Import-VM -Path $vmcx -VhdDestinationPath "${VMPath}\${node}" -Copy -GenerateNewId -ErrorAction Stop
            Rename-VM -VM $vm -NewName $node -ErrorAction Stop
            Set-VMMemory -VMName $node -DynamicMemoryEnabled $false -StartupBytes ($nodeMemory * 1024 * 1024) -ErrorAction Stop
            Set-VMProcessor -VMName $node -Count $nodeCpus -ErrorAction Stop
        } -Name create-$node -ArgumentList $vmcx, $node, $VMPath, $nodeCpus, $nodeMemory | Out-Null
    }

    Write-OutPut "Waiting for VMs to be created..."
    Get-Job | Wait-Job | Out-Null

    # Check for errors
    $jobs = Get-Job
    $success = $true
    $ErrorActionPreference = 'Continue'
    foreach ($job in $jobs) {
        if ($job.State -eq "Failed") {
            Receive-Job -Job $job -Wait -AutoRemoveJob
            $success = $false
        }
    }
    $ErrorActionPreference = 'Stop'
    Get-Job | Remove-Job
    if (-not $success) {
        Write-Error "Failed to create all VMs."
    }


    $success = $false
    foreach ($i in 0..30) {
        Start-Sleep -Seconds 2
        $vms = Get-VM | Where-Object { $nodeNames -contains $_.Name }
        if ($vms.Count -eq $nodeNames.Count) {
            $success = $true
            break
        }
        if ($i -gt 5) {
            Write-Host "Waiting for VMs to be created..."
        }
    }
    if (-not $success) {
        Write-Error "Failed to create all VMs after 60 seconds."
    }
    else {
        [Console]::ResetColor()
        Write-Host "All VMs created."
    }
}
