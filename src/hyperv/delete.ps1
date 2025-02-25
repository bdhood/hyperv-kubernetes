function DeleteAllNodes {
    param (
        [array]$nodeNames,
        [string]$VMPath
    )

    foreach ($node in $nodeNames) {
        $vm = Get-VM | Where-Object { $_.Name -eq $node }
        if (-Not $vm) {
            Write-Host "HyperV-VM '$node' not found."
            continue
        }
        $path = "$VMPath\$node"
        Start-Job -ScriptBlock {
            param($node, $path)
            $vm = Get-VM | Where-Object { $_.Name -eq $node }
            Stop-VM -VM $vm -Force
            Remove-VM -VM $vm -Force
            Remove-Item -Path $path -Recurse -Force
        } -Name delete-$node -ArgumentList $node, $path | Out-Null
    }
    
    Write-OutPut "Waiting for VMs to be removed..."
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
        Write-Error "Failed to remove VMs."
    }

    $success = $false
    foreach ($i in 0..30) {
        Start-Sleep -Seconds 2
        $nodeDirs = $nodeNames | ForEach-Object { "${VMPath}\$_" }
        $nodeDirs = $nodeDirs | Where-Object { Test-Path -Path $_ }
        if (-not $nodeDirs) {
            $success = $true
            break
        }
        if ($i -gt 5) {
            [Console]::WriteLine("Waiting for VM folders to be removed...")
        }
    }
    if (-not $success) {
        Write-Error "Failed to remove VM folders after 60 seconds."
    }
    else {
        [Console]::ResetColor()
        Write-Host "All VMs removed."
    }
}
