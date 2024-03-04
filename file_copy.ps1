# Prompt the user to enter the path to the Git repository
try {

    $_ORIGINAL_PWD = (Get-Location).Path

    Write-Warning  "PWD: $_ORIGINAL_PWD"

    # Prompt the user to enter the path to the Git repository
    # $repoPath = 'D:\Big\My Work_Local\Coding\test_git'
    $repoPath = Read-Host "Enter the path to the Git repository (default: $_ORIGINAL_PWD)"

    if ([string]::IsNullOrWhiteSpace($repoPath)) {
        $repoPath = $_ORIGINAL_PWD
    }

    $repoPath = $repoPath.Trim()

    if (-not (Test-Path -Path (Join-Path $repoPath ".git"))) {
        throw "The specified path is not a valid Git repository."
    }

    # Change the working directory to the specified Git repository path
    
    Set-Location -Path $repoPath

    # Get the last commit ID
    $lastCommitId = git rev-parse HEAD

    # Prompt the user to enter the commit ID
    $commitId = Read-Host "Enter the commit ID (default: $($lastCommitId.Substring(0, 7)) )"
    $commitId = $commitId.Trim()

    # If no commit ID is provided, use the last commit ID
    if ([string]::IsNullOrWhiteSpace($commitId)) {
        $commitId = $lastCommitId
    }
    $_GIT_DEV_BRANCH = "origin/dev"
    $str_readme = "`n`n>> Compare the changes between the [$_GIT_DEV_BRANCH] and the $commitId branch <<`n`n"

    # Run 'git diff-tree --no-commit-id --name-only -r <commit_id>' command and store the output
    # $gitOutput = git diff-tree --no-commit-id --name-only -r $commitId

    # Run 'git show --stat <commit_id>' command and store the output
    $COMMAND = "git show --pretty="""" --name-only $($_GIT_DEV_BRANCH)..$($commitId)"
    $OUTPUT = Invoke-Expression $COMMAND
    Write-Host $OUTPUT

    if ([string]::IsNullOrWhiteSpace($OUTPUT)) {
        Write-Host "No changes found between the [$_GIT_DEV_BRANCH] and the $commitId branch."
        return
    }

    # Split the output into separate lines
    $lines = $OUTPUT -split '\r?\n'

    
    $str_file_change = "-----------files change----------`n"

    Write-Host $str_fileChange

    foreach ($line in $lines) {
        if (![string]::IsNullOrWhiteSpace($line)) {
            $str_file_change += $line + "`n"
        }
    }
    $str_file_change += "---------------------------------`n"
    $str_readme += $str_file_change

    Write-Host $str_file_change

    $dateStr = Get-Date -Format "yyyyMMdd"

    $pathFolder = ".file_change/"

    $prefixFolder = "evaluate-" + $dateStr + "-"

    $defaultFolderName = $pathFolder + $prefixFolder + $commitId.Substring(0, 7)
    $newFolderName = Read-Host "Enter the Folder Name (default: $defaultFolderName)"

    if ([string]::IsNullOrWhiteSpace($newFolderName)) {
        $newFolderName = $defaultFolderName
    }

    # Prompt the user to enter the destination folder path or use the original PowerShell working directory as the default
    $destinationFolder = Read-Host "Enter the destination New folder path (default: $($_ORIGINAL_PWD + '\' + $newFolderName))"
    $destinationFolder = $destinationFolder.Trim()

    # If no destination folder path is provided, use the original PowerShell working directory
    if ([string]::IsNullOrWhiteSpace($destinationFolder)) {
        $destinationFolder = Join-Path $_ORIGINAL_PWD $newFolderName
    }

    # Iterate through the lines and copy the files to the destination folder with the same path

    foreach ($line in $lines) {
        $line = $line.Trim()
        $sourceFile = Join-Path $repoPath $line
        $destinationFile = Join-Path $destinationFolder $line
        $destinationFileDirectory = Split-Path $destinationFile -Parent

        # Create the destination directory if it doesn't exist
        if (-not (Test-Path -Path $destinationFileDirectory)) {
            New-Item -ItemType Directory -Force -Path $destinationFileDirectory | Out-Null
        }

        # Copy the file to the destination folder
        Copy-Item -Path $sourceFile -Destination $destinationFile -Force -ErrorAction Stop
    }

    # Create README.txt and add a message
    $readmeFilePath = Join-Path $destinationFolder "README.txt"

    # Set the culture to en-US
    $culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

    # Get the current date and format it
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Create the message with the formatted date
    $message = "This folder was generated by a PowerShell script on $timestamp.`n"
    $message += $str_readme

    try {
        Set-Content -Path $readmeFilePath -Value $message -ErrorAction Stop
        Write-Host "README.txt created successfully."
    }
    catch {
        Write-Warning "Error creating README.txt: $_"
    }

    Write-Host "File copying completed successfully."

}
catch {
    Write-Error "Error copying file" $_.Exception.Message
}
finally {
    Set-Location -Path $_ORIGINAL_PWD

    # Clear variables
    $_ORIGINAL_PWD = $null
    $repoPath = $null
    $lastCommitId = $null
    $commitId = $null
    $gitOutput = $null
    $lines = $null
    $defaultFolderName = $null
    $newFolderName = $null
    $destinationFolder = $null
    $sourceFile = $null
    $destinationFile = $null
    $message = $null
    $destinationFileDirectory = $null
    $readmeFilePath = $null
    $timestamp = $null
}
