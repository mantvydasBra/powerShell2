Function Get-ComputerInfo {
    Write-Host "Getting computer name..." -ForegroundColor Cyan
    Get-WMIObject –Class Win32_Bios | Select @{Name = "Computer name"; e = {$_.PSComputername}} > .\Process.txt #Gets computer name

    Write-Host "Getting disk information..." -ForegroundColor Cyan
    "Logical disk information:" >> .\Process.txt
    Get-WmiObject -Class Win32_logicaldisk >> .\Process.txt #Gets logical disk information

    Write-Host "Getting CPU %..." -ForegroundColor Cyan
    Get-WmiObject Win32_Processor | Select @{Name="CPU usage %"; e = {$_.LoadPercentage}} | Format-List >> .\Process.txt #Gets current cpu usage %

    Write-Host "Getting disk space information..." -ForegroundColor Cyan
    Get-WmiObject -Class win32_logicaldisk |`
     ft @{Name="Drive letter"; e = {$_.deviceID}}, @{Name="Free Disk Space (GB)";e={$_.FreeSpace /1GB}}, `
     @{Name="Total Disk Size (GB)";e={$_.Size /1GB}} -AutoSize >> .\Process.txt #Gets all drive free space and total space

    Write-Host "Getting RAM information..." -ForegroundColor Cyan
    Get-WmiObject -Class win32_operatingsystem |`
    ft @{Name="Total Visible Memory Size (GB)";e={[math]::truncate($_.TotalVisibleMemorySize /1MB)}}, ` 
    @{Name="Free Physical Memory (GB)";e={[math]::truncate($_.FreePhysicalMemory /1MB)}} -AutoSize >> .\Process.txt #Gets free and total RAM in GB
}

Function Get-ServiceInfo($serviceName) {
    try {
        Get-Service $serviceName -ErrorAction Stop
    }
    catch [System.Management.Automation.RuntimeException] {
        Write-Host "There is no such service." -ForegroundColor DarkYellow
    }
}

Function Get-AppEvents($programName, $numberOfEvents) {
    Write-Host "Checking if application exists." -ForegroundColor Cyan
    try {
        Get-EventLog -LogName Application -Source $programName -ErrorAction Stop | Out-Null
    }
    catch [System.ArgumentException] {
        Write-Host "There is no such application" -ForegroundColor Red
        return
    }

    $num = (Get-EventLog -LogName Application -Source $programName | Select -First $numberOfEvents | Measure-Object).Count
    Write-Host "Getting and writing logs to a file..." -ForegroundColor Cyan
    if ($num -eq $numberOfEvents) {
        
    } else {
        Write-Host "We only found $num of events. Writing them all..." -ForegroundColor Cyan
    }
    
    Get-EventLog -LogName Application -Source $programName | `
    Select-Object -Property Source, EventID, InstanceId, Message | ` #Getting logs for chosen application
    Select -First $numberOfEvents | ` #Choose specified number of latest events
    format-table -wrap | ` #Formatting table to get full message
    Out-File -FilePath "${programName}_$((Get-Date).ToString("yyyyMMdd")).txt" #Writing to a text file with current time and date

    Write-Host "Done! check for $programName-DATE.txt" -ForegroundColor Green
}



#infinite loop for menu
do {
    #printing menu
    Write-Host "`n1. Create VMI objects and write output to a file."
    Write-Host "2. Get running and stopped processes and write to separate files. Check given service status."
    Write-Host "3. Get newest 10 events from system event log. Check for specific program events and write them to a file."
    Write-Host "4. Call a 'Clockres' sysinternal tool."
    Write-Host "5. Create a Windows Scheduled Task which will run this script at specified time."
    Write-Host "6. Close"

    $number = Read-Host -Prompt 'Choose a number'
    switch($number) {
        1 {
            Get-ComputerInfo
            Write-Host "Done! Check for a 'Process' file." -ForegroundColor Green
            break
        }

        2 {
            Write-Host "Getting running processes... " -ForegroundColor Cyan
            Get-Service | Where-Object {$_.Status -eq "Running"} > .\Running.txt
            Write-Host "Getting stopped processes... " -ForegroundColor Cyan
            Get-Service | Where-Object {$_.Status -eq "Stopped"} > .\Stopped.txt
            Write-Host "Done!" -ForegroundColor Green

            $serviceName = Read-Host "Enter service name to check status"
            Get-ServiceInfo($serviceName)
            break
        }

        3 {
            Write-Host "Getting newest 10 events from system... " -ForegroundColor Cyan
            Get-EventLog -LogName System -Newest 10
            Write-Host "Done!`n" -ForegroundColor Green

            $programName = Read-Host "Enter a program name you want to check logs for"
            $numberOfEvents = Read-Host "How many events to output?"
            
            Get-AppEvents $programName $numberOfEvents
            
            break
        }

        4 {
            Invoke-Expression .\Clockres.exe | Out-File -FilePath "Clockres.txt"
            Write-Host "Done! Check 'Clockres.txt' file." -ForegroundColor Green
            break
        }

        5 {
            $workingDir = Get-Location #Getting current working directory
            try {
                $action = New-ScheduledTaskAction -WorkingDirectory $workingDir -Execute 'powershell.exe' -Argument '-File .\second_script.ps1' -ErrorAction Stop #Creating an action which windows will perform
                $time = Read-Host "Enter hour when to execute (hh:mm)" 
                $trigger =  New-ScheduledTaskTrigger -Daily -At $time -ErrorAction Stop #Setting custom time
           
                Register-ScheduledTask -TaskName "Scripting" -Action $action -Trigger $trigger -Description "Cheeky script! :)" -ErrorAction Stop #Saving the task in windows scheduler
            }
            catch {
                Write-Host "Something went wrong..." -ForegroundColor Red
            }
            
            break
        }

        6 {
            Write-Host "bye" -ForegroundColor Green
            break
        }
         
        default{
            Write-Host "There is no such option!" -ForegroundColor Red
        }
    }
} while ($number -ne 6)
