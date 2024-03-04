function Get-GitRepositoryPath {
    $originalPwd = (Get-Location).Path
    Write-Warning "PWD: $originalPwd"
    
    $repoPath = Read-Host "Enter the path to the Git repository (default: $originalPwd)"
    if ([string]::IsNullOrWhiteSpace($repoPath)) {
        $repoPath = $originalPwd
    }
    return $repoPath.Trim()
}

function Test-GitRepository {
    param($repoPath)
    if (-not (Test-Path -Path (Join-Path $repoPath ".git"))) {
        throw "The specified path is not a valid Git repository."
    }
}

function Get-LastCommitId {
    return git rev-parse HEAD
}

function Get-CommitId {
    param($lastCommitId)
    $commitId = Read-Host "Enter the commit ID (default: $($lastCommitId.Substring(0, 7)) )"
    if (-not [string]::IsNullOrWhiteSpace($commitId)) {
        return $commitId.Trim()
    }
    return $lastCommitId
}

function Get-FileChanges {
    param($gitDevBranch, $commitId)
    $command = "git show --pretty="""" --name-only $gitDevBranch..$commitId"
    return Invoke-Expression $command
}

function New-ReadmeMessage {
    param($gitDevBranch, $commitId, $output)
    $readme = "`n`n>> Compare the changes between the [$gitDevBranch] and the $commitId branch <<`n`n"
    $readme += "-----------files change----------`n"
    $output = $output -split '\r?\n' | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $output) {
        $readme += $line.Trim() + "`n"
    }
    $readme += "---------------------------------`n"
    return $readme
}

function Get-DestinationFolderName {
    param($originalPwd, $commitId)
    $dateStr = Get-Date -Format "yyyyMMdd"
    $prefixFolder = "evaluate-$dateStr-"
    $defaultFolderName = ".file_change/$prefixFolder" + $commitId.Substring(0, 7)
    $newFolderName = Read-Host "Enter the Folder Name (default: $defaultFolderName)"
    if (-not [string]::IsNullOrWhiteSpace($newFolderName)) {
        return $newFolderName.Trim()
    }
    return $defaultFolderName
}

function Get-DestinationFolderPath {
    param($originalPwd, $newFolderName)
    $destinationFolder = Read-Host "Enter the destination New folder path (default: $originalPwd/$newFolderName)"
    if (-not [string]::IsNullOrWhiteSpace($destinationFolder)) {
        return $destinationFolder.Trim()
    }
    return Join-Path $originalPwd $newFolderName
}

function Copy-FilesToDestination {
    param($repoPath, $lines, $destinationFolder)
    foreach ($line in $lines) {
        $line = $line.Trim()
        $sourceFile = Join-Path $repoPath $line
        $destinationFile = Join-Path $destinationFolder $line
        $destinationFileDirectory = Split-Path $destinationFile -Parent
        if (-not (Test-Path -Path $destinationFileDirectory)) {
            New-Item -ItemType Directory -Force -Path $destinationFileDirectory | Out-Null
        }
        Copy-Item -Path $sourceFile -Destination $destinationFile -Force -ErrorAction Stop
    }
}

try {
    $repoPath = Get-GitRepositoryPath
    Test-GitRepository -repoPath $repoPath

    Set-Location -Path $repoPath

    $lastCommitId = Get-LastCommitId
    $commitId = Get-CommitId -lastCommitId $lastCommitId

    $gitDevBranch = "origin/dev"
    $output = Get-FileChanges -gitDevBranch $gitDevBranch -commitId $commitId

    if ([string]::IsNullOrWhiteSpace($output)) {
        Write-Host "No changes found between the [$gitDevBranch] and the $commitId branch."
        return
    }

    $readme = New-ReadmeMessage -gitDevBranch $gitDevBranch -commitId $commitId -output $output

    $newFolderName = Get-DestinationFolderName -originalPwd $repoPath -commitId $commitId
    $destinationFolder = Get-DestinationFolderPath -originalPwd $repoPath -newFolderName $newFolderName

    $lines = $output -split '\r?\n'
    Copy-FilesToDestination -repoPath $repoPath -lines $lines -destinationFolder $destinationFolder

    $readmeFilePath = Join-Path $destinationFolder "README.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $message = "This folder was generated by a PowerShell script on $timestamp.`n"
    $message += $readme

    Set-Content -Path $readmeFilePath -Value $message -ErrorAction Stop
    Write-Host "README.txt created successfully."
    Write-Host "File copying completed successfully."

}
catch {
    Write-Error "Error copying file: $($_.Exception.Message)"
}
finally {
    Set-Location -Path (Get-Location).Path
    Clear-Variable -Name "_ORIGINAL_PWD", "repoPath", "lastCommitId", "commitId", "output", "lines", "newFolderName", "destinationFolder", "sourceFile", "destinationFile", "message", "destinationFileDirectory", "readmeFilePath", "timestamp" -ErrorAction SilentlyContinue
}
