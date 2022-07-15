<#
.Synopsis
    Script to allow time-limited assignment of domain user to the group/s on local computer
.Description
    Can be run both by pasting the code with hardcoded values, as well as running the script with attributes attached. In such cases, include quotation marks at start and end of each value. The script checks the date value in the access.ini file, hidden in the username path within the operation system. Please, note, the deletion of the access.ini file will cause new creation with rights used in the attributes of the called script. If it is required to revoke the access to the user earlier, simply go to the access.ini file, and change the date-time value to some earlier and run the script again. Eventually, you can manualy remove the membership from GUI of MMC or by Powershell commandlet. The run of script always checks the time granted. If it got already expired, the user will be removed from the group. The resolution of the accounts to be provided the membership is based on the username profile path. Scheduled Task calls the file stored in public folder, because of rights needed, and not to allow users to screw it up. The batch file is built on each time from scratch based on the attributes provided to the script.
.Example
    run the script in PS console like this:
    localadmin3.ps1 "jdoe" "Administrators" "2"
    Calling of the script like that, will grant to the domain user jdoe the membership in local Administrators group for 2 days, and also creates new Scheduled Task for check on each logon to the system, if the granted time already passed. The script also remove the Scheduled Task once the local administrator privileges got removed after the given time.
.INPUTS
    Username in the format like "jdoe" (the domain is hardcoded in the code).
    Local group, to be assigned the membership to, in the format like "Administrators" or "Administradores".
    The length of the membership of the group provided, defined in days "2".
.OUTPUTS
    To work as expected, it is required to uncomment the Powershell Commandlets, that will Add or Remove the user from the local group. Currently commented, not to cause any issues in OS.                                   
#>
if($args){ #if the script is called with attributes, create the variables
    $user = $args[0]; #just username, domain is configured further below
    $group = $args[1]; #local computer group name
    $days = $args[2]; #digit - count of days
} else { #without attributes, default values setup
    $user = "kopl.michal"; #"doe.john";
    $group = "Administrators"; #Administradores
    $days = 2;
}
$domain = "domain"; #the name of the domain, so it is possible to use it later on, in the format like qontigo\doe.john
$CurrentDate = (Get-Date -Date ((Get-Date).DateTime) -UFormat %s);
$batpath = "C:\Users\Public\locadm.bat";
$taskname = "AdminRemoval";
$ThisScriptPath = $MyInvocation.MyCommand.Path; #grabs the full path to this script - use in Scheduled Task creation
$file = "C:\Users\$user\access.ini"; #where will be stored the file with the date limit for group membership
$CheckExists = Test-Path -Path $file -PathType Leaf;
if($CheckExists -eq "True"){
    $FileTime = Get-Content $file -Raw;
    if($CurrentDate -ge $FileTime){        
        Remove-LocalGroupMember -Group "$group" -Member "$user";#Write-host "Remove-LocalGroupMember -Group ""$group"" -Member ""$domain\$user"";"
        Unregister-ScheduledTask -TaskName "$taskname" -Confirm:$false; #cleanup of Scheduled Task
    }
} else {
    $TimeLimit = (($days*86400)+$CurrentDate);
    New-Item $file -ItemType File -Value "$TimeLimit" -Force;
    #Write-host "Add-LocalGroupMember -Group ""$group"" -Member ""$domain\$user"";";
    Add-LocalGroupMember -Group "$group" -Member "$domain\$user";#Add-LocalGroupMember -Group "$group" -Member "$user"; --local username
    Set-Content -Path $batpath -Value "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe $ThisScriptPath ""$user"" ""$group"" ""$days"""
    $taskdescription = "Runs the script for evaluation of the local administrators group membership";
    $action = New-ScheduledTaskAction -Execute "$batpath" `
    -Argument '-NoProfile -WindowStyle Hidden';
    $trigger =  New-ScheduledTaskTrigger -AtLogon;
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1);
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Description $taskdescription -AsJob -Settings $settings -User "System";
}
