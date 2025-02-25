function RunPacker {
    param (
        [string]$VMPath,
        [int]$nodeCpus,
        [int]$nodeMemory,
        [int]$nodeDisk,
        [bool]$force = $false
    )

    # Generate hashed passwords for preseed

    $nodePassword = (openssl rand -base64 12)
    $nodePasswordHashed = (openssl passwd -6 $nodePassword)
    $Env:PACKER_VAR_ssh_password = $nodePassword
    $templateData = (Get-Content "./packer/http/preseed.template.cfg" -Raw)
    $templateData = ($templateData -replace 'NODE_PASSWORD', $nodePasswordHashed)
    $templateData | Set-Content -Path "./packer/http/preseed.cfg" -Force
    @{
        "node" = $nodePassword
    } | ConvertTo-Json | Set-Content -Path "./data/user-passwords.json" -Force

    # Run packer build

    if (-not $force -and (Test-Path "$VMPath\node-base")) {
        Write-Output 'Skipping packer build...'
        return
    }

    $packerArgs = @(
        "-var", "ssh_password=${nodePassword}"
        "-var", "vm_path=${VMPath}"
        "-var", "memory=${nodeMemory}"
        "-var", "cpus=${nodeCpus}"
        "-var", "disk_size=${nodeDisk}"
    )

    if ($force) {
        $packerArgs += "-force"
    }

    $packerArgs += "node-base.pkr.hcl"
    packer build @packerArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Packer build failed'
    }
}
