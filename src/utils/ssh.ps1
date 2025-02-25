function GenerateSSHKey {
    if (-not (Test-Path -Path 'data')) {
        New-Item -ItemType Directory -Path 'data'
    }
    if (-not (Test-Path -Path './data/id_rsa')) {
        ssh-keygen -t rsa -b 4096 -f "./data/id_rsa" -N '""'
    }
}

function ValidateSSH {
    param (
        [array]$nodeNames
    )

    foreach ($node in $nodeNames) {
        foreach ($i in 0..15) {
            Write-Output "Checking SSH from host to '$node'..."
            SshRunCommand -nodeName $node -command 'echo Success' -allowError $true | Tee-Object -Variable result
            if ($result -match "Success") {
                break
            }
            elseif ($i -lt 10) {
                Write-Warning "SSH from host to '$node' is not reachable. Retrying..."
                Start-Sleep -Seconds 1
            }
            else {
                Write-Error "SSH is NOT reachable on node '$node'."
            }
        }
    }
}

function SshUploadFile {
    param (
        [string]$nodeName,
        [string]$localPath,
        [string]$remotePath,
        [bool]$silent = $false
    )

    if (-not $silent) {
        Write-Output "Uploading file '$localPath' to node '${nodeName}:$remotePath'..."
    }
    scp -i "./data/id_rsa" `
      -o LogLevel=ERROR `
      -o ConnectTimeout=2 `
      -o StrictHostKeyChecking=no `
      -o UserKnownHostsFile=/dev/null `
      $localPath "node@${nodeName}:${remotePath}"
    if ($LASTEXITCODE -eq 0) {
        if (-not $silent) {
            Write-Output "File uploaded successfully."
        }
    }
    else {
        Write-Error "Failed to upload file."
    }
}

function SshRunCommand {
    param (
        [string]$nodeName,
        [string]$command,
        [bool]$sudo = $true,
        [bool]$allowError = $false
    )

    if ($sudo) {
        $command = "sudo -S `"$command`""
    }
    $originalErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    ssh -i "./data/id_rsa" `
      -o LogLevel=ERROR `
      -o ConnectTimeout=2 `
      -o StrictHostKeyChecking=no `
      -o UserKnownHostsFile=/dev/null `
      "node@$nodeName" "$command"
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $originalErrorActionPreference
    if ($exitCode -ne 0 -and -not $allowError) {
        Write-Error "'$nodeName' failed to execute command: exit code $exitCode"
    }
}

function SshRunScript {
    param (
        [string]$nodeName,
        [string]$scriptPath,
        [array]$cli_args = @(),
        [bool]$sudo = $true,
        [bool]$allowError = $false
    )

    $fileName = [System.IO.Path]::GetFileName($scriptPath)
    SshUploadFile `
        -nodeName $nodeName `
        -localPath $scriptPath `
        -remotePath "/tmp/$fileName" `
        -silent $true

    $command = "chmod +x /tmp/$fileName && sudo -S /tmp/$fileName " + ($cli_args -join ' ')
    Write-Output $command
    SshRunCommand `
        -nodeName $nodeName `
        -allowError $allowError `
        -sudo $sudo `
        -command $command
}
