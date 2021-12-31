$disks                      = Get-Disk
$global:DISKPART_SCRIPT     = "unattend.txt"
$global:disk_Id_To_Sanitize = "xxx"
$global:number_Of_Passes
$confirm_To_Sanitize
$disk_IDs                   = [System.Collections.ArrayList]@()
$SYSTEM_DRIVE = $Env:Systemdrive


Function gather-Input-From-User() {
    clear
    Write-Host
    Write-Host "----------------------------------- Disk Information -----------------------------------"
    Write-Host

    foreach ($disk in $disks) {
        Write-Host "Disk ID:        $($disk.Number)" -ForegroundColor Red
        Write-Host "Disk Name:      $($disk.FriendlyName)"
        Write-Host "Dize Size:      $($disk.Size / 1024 / 1024 / 1024) GB"
        Write-Host "Disk Partition: $($disk.PartitionStyle)"
        Write-Host
        $disk_IDs.Add($disk.Number) | Out-Null
    }
    Write-Host "----------------------------------------------------------------------------------------"

    if (($($disks).length -lt 2) -or ($($disks).length -eq $null)) {
         Write-Host "This system has less than 2 disks attached to it. Quitting to avoid wiping the USB drive" -BackgroundColor Black -ForegroundColor Red
         Exit
    }



    while (-Not ($disk_IDs -contains $global:disk_Id_To_Sanitize)) {
        Write-Host
        Write-Host "Enter the Disk ID for the disk you want to sanitize." -BackgroundColor Black -ForegroundColor Yellow
    
        $user_Input = Read-Host
        $global:disk_Id_To_Sanitize = $user_Input
        if ($global:disk_Id_To_Sanitize -eq "") {$global:disk_Id_To_Sanitize = "xxx"}
        if (-Not ($disk_IDs -contains $global:disk_Id_To_Sanitize)) {
            Clear
            Write-Host "Invalid Disk ID entered. See valid Disk IDs below:" -BackgroundColor Black -ForegroundColor DarkYellow
            Write-Host
            Write-Host "----------------------------------- Disk Information -----------------------------------"
            Write-Host
            Write-Host "Disk ID`t`tDisk Name`tDisk Size`tDisk Partition"
            foreach ($disk in $disks) {
                Write-Host "Disk ID:        $($disk.Number)" -ForegroundColor Red
                Write-Host "Disk Name:      $($disk.FriendlyName)"
                Write-Host "Dize Size:      $($disk.Size / 1024 / 1024 / 1024) GB"
                Write-Host "Disk Partition: $($disk.PartitionStyle)"
                Write-Host
            }
            Write-Host "----------------------------------------------------------------------------------------"
        }
     }

     Clear
     Write-Host
     while (-Not (([int]$global:number_Of_Passes -ge 1) -and ([int]$global:number_Of_Passes -le 99))) {
        Write-Host "Enter the desired number of passes.`nEach pass will 'zero' the drive. (Recommended 10)" -BackgroundColor Black -ForegroundColor Yellow
        $global:number_Of_Passes = Read-Host
        try{$global:number_Of_Passes = [int]$global:number_Of_Passes}
        catch{$global:number_Of_Passes = [int]0}
        if (-Not (([int]$global:number_Of_Passes -ge 1) -and ([int]$global:number_Of_Passes -le 99))) {
            Clear
            Write-Host "Invalid number of passes selected. Choose a number between 1-99:" -BackgroundColor Black -ForegroundColor DarkYellow
        }
    }

    Clear
    Write-Host
    while (-Not ($confirm_To_Sanitize -eq 'confirm')) {
        Write-Host "----------------------------------- Disk Information -----------------------------------"
            Write-Host
            foreach ($disk in $disks) {
                Write-Host "Disk ID:        $($disk.Number)"
                Write-Host "Disk Name:      $($disk.FriendlyName)"
                Write-Host "Dize Size:      $($disk.Size / 1024 / 1024 / 1024) GB"
                Write-Host "Disk Partition: $($disk.PartitionStyle)"
                Write-Host
            }
            Write-Host "----------------------------------------------------------------------------------------"
        Write-Host
        Write-Host "`t`t`tDisk to sanitize: $($global:disk_Id_To_Sanitize) (Disk Number/ID)" -ForegroundColor Cyan
        Write-Host "`t`t`tNumber of passes: $($global:number_Of_Passes)"    -ForegroundColor Cyan
        Write-Host
        Write-Host
        Write-Host "Please review your selection above. Type 'confirm' to sanitize." -BackgroundColor Black -ForegroundColor Yellow
        Write-Host "WARNING. After confirm, all data on disk will be lost. `nPress Ctrl+C if you wish to abort." -BackgroundColor Black -ForegroundColor Red
        $confirm_To_Sanitize = Read-Host
        if (-Not ($confirm_To_Sanitize -eq 'confirm')) {
            Clear
            Write-Host "You must confirm your selection to begin sanitation." -BackgroundColor Black -ForegroundColor DarkYellow
        }
    }
}

Function build-Diskpart-Script() {
    Remove-Item -Path "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Force -ErrorAction SilentlyContinue
    "sel disk $global:disk_Id_To_Sanitize" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "clean all" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "create partition primary" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "format fs=ntfs quick" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "assign letter j" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "exit" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
}

Function build-Diskpart-Script-Final() {
    Remove-Item -Path $global:DISKPART_SCRIPT -Force -ErrorAction SilentlyContinue
    "sel disk $global:disk_Id_To_Sanitize" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "clean all" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
    "exit" | Out-File "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" -Append -Encoding ascii
}

Function zero-With-Diskpart() {
    build-Diskpart-Script
    Write-Host
    Write-Host "Pass $count of $global:number_Of_Passes" -ForegroundColor Cyan
    Write-Host
    Write-Progress "Zeroing disk($($global:disk_Id_To_Sanitize)). Please wait..."
    & diskpart.exe /s "$($SYSTEM_DRIVE)\$($global:DISKPART_SCRIPT)" #| Out-Null
}



Function final-Zero-With-Diskpart() {
    Write-Progress "FINAL: Zeroing disk($($global:disk_Id_To_Sanitize)). Please wait..."
    build-Diskpart-Script-Final
    & diskpart.exe /s $global:DISKPART_SCRIPT | Out-Null
}

Function sanitize-Drive() {
    Clear
    $count = 1
    while ($count -le $global:number_Of_Passes) {
        zero-With-Diskpart
        #fill-Drive-With-Junk
	#"zero"
	#Start-Sleep -Seconds 1
	#"fill"
	#Start-Sleep -Seconds 1
        $count++
        Clear
    }
    Write-Host "Drive sanitation complete!" -ForegroundColor Green
}

Function copy-Files-To-Ram-Drive() {
    if (-Not ((Test-Path "$($SYSTEM_DRIVE)\jwipe.bat") -And (Test-Path "$($SYSTEM_DRIVE)\jwipe.ps1"))) {
        Write-Host ""
        Write-Host "RAM Drive missing jwipe files. Copying files necessary to be able to remove USB..." -ForegroundColor Green
        $JUNK | Out-File .\_._
        Copy-Item -Path .\_._ -Destination "$($SYSTEM_DRIVE)\_._"
        Copy-Item -Path .\jwipe.bat -Destination "$($SYSTEM_DRIVE)\jwipe.bat"
        Copy-Item -Path .\jwipe.ps1 -Destination "$($SYSTEM_DRIVE)\jwipe.ps1"
    }
    else {
        return #Files already exist, do exit function
    }
    Set-Location $ENV:SystemDrive
    Write-Host "Relaunching jwipe from Ram Drive." -ForegroundColor Green
    Start-Sleep -Seconds 3
    Powershell.exe -File .\jwipe.ps1
    Exit
}

#copy-Files-To-Ram-Drive
gather-Input-From-User
sanitize-Drive
final-Zero-With-Diskpart
