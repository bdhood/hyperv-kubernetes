function UpdateHosts {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$HostMappings
    )

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

    # Ensure the hosts file is writable
    if ((Get-Item $hostsPath).Attributes -match 'ReadOnly') {
        attrib -r $hostsPath
    }

    # Read the existing hosts file
    $hostsContent = Get-Content $hostsPath

    # Initialize updated content list
    $updatedContent = @()
    $existingHostnames = @()

    $changesMade = $false

    # Process each line in the hosts file
    foreach ($line in $hostsContent) {
        $trimmedLine = $line.Trim()
        $matched = $false

        foreach ($hostname in $HostMappings.Keys) {
            $pattern = "^\s*(\d{1,3}(\.\d{1,3}){3})\s+$hostname\s*$"

            if ($trimmedLine -match $pattern) {
                $existingIP = $Matches[1]
                $newIP = $HostMappings[$hostname]

                if ($existingIP -ne $newIP) {
                    # Update IP if it differs
                    $updatedContent += "$newIP`t$hostname"
                    $changesMade = $true
                    Write-Host "Updated: $hostname from $existingIP to $newIP"
                } else {
                    # Keep existing correct entry
                    $updatedContent += $line
                    Write-Host "No change: $hostname ($existingIP)"
                }

                $existingHostnames += $hostname
                $matched = $true
                break
            }
        }

        if (-not $matched) {
            $updatedContent += $line
        }
    }

    # Add new entries that didn't exist
    foreach ($hostname in $HostMappings.Keys) {
        if (-not ($existingHostnames -contains $hostname)) {
            $newEntry = "$($HostMappings[$hostname])`t$hostname"
            $updatedContent += $newEntry
            Write-Host "Added: $newEntry"
            $changesMade = $true
        }
    }

    if (-not $changesMade) {
        Write-Host "No changes made to hosts file."
        return
    }

    # Write back to the hosts file
    $success = $false
    $ErrorActionPreference = 'SilentlyContinue'
    foreach ($i in 0..10) {
        if ($success) {
            break
        }
        try {
            $updatedContent | Set-Content -Path $hostsPath -Force
            
            # read the host file and assert the context
            $hostsContent = Get-Content $hostsPath
            Write-OutPut "Hosts file content: $hostsContent"
            Write-OutPut "Updated content: $updatedContent"
            if (($hostsContent -join "`n") -eq ($updatedContent -join "`n")) {
                $success = $true
                break
            }
            else {
                Write-Output "Changes not reflected in hosts file. Retrying in 1 second..."
                Start-Sleep -Seconds 1
            }
        } catch {
            Write-Output "Failed to write to hosts file. Retrying in 1 second..."
            Start-Sleep -Seconds 1
        }
    }
    $ErrorActionPreference = 'Stop'
    if (-not $success) {
        Write-Error "Failed to write to hosts file after 10 retries."
    }
    
    Write-Output "Successfully updated hosts file."
}


function RemoveSshKnownHosts {
    param (
        [Parameter(Mandatory = $true)]
        [array]$nodeNames
    )
    
    foreach ($node in $nodeNames) {
        ssh-keygen -R $node
    }
}
