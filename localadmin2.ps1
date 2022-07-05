<#
.Synopsis
    Script to allow time-limited assignment of domain user to the group/s on local computer
.Description
    Can be run both by pasting the code with hardcoded values, as well as running the script with attributes attached. In such cases, include quotation marks at start and end of each value. The script checks the date value in the access.ini file, hidden in the username path within the operation system. Please, note, the deletion of the access.ini file will cause new creation with rights used in the attributes of the called script. If it is required to revoke the access to the user earlier, simply go to the access.ini file, and change the date-time value to some earlier and run the script again. Eventually, you can manualy remove the membership from GUI of MMC or by Powershell commandlet. The run of script always checks the time granted. If it got already expired, the user will be removed from the group. The resolution of the accounts to be provided the membership is based on the username profile path.
.Example
    run the script in PS console like this:
    localadmin2.ps1 "jdoe" "Administrators" "2"
    Calling of the script like that, will grant to the domain user jdoe the membership in local Administrators group for 2 days (or till the next check of the time granted in the access.ini file).
.INPUTS
    Username in the format like "jdoe" (the domain is hardcoded in the code).
    Local group, to be assigned the membership to, in the format like "Administrators" or "Administradores".
    The length of the membership of the group provided, defined in days "2".
.OUTPUTS
    To work as expected, it is required to uncomment the Powershell Commandlets, that will Add or Remove the user from the local group. Currently commented, not to cause any issues in OS.
                                                                                                                                                                                                        
                                                                                                                                                             (##/                                       
                                                                                                                                                            .#####/                                     
                                                                                                                                                              *#####*                                   
                                                                                                                                                                /#####,                                 
                                                                                                                                                                  /#####,                               
                                                                                                                                                                    /#####,           ,((.              
                   ,(##########*           ,(##########*        ###(          (##/  /#################*  ####        /##########(.         ,(#########(*              (#####.       *#####,             
                 #####/,.  ,*#####.      (####/,.  ,*#####,     #####(        (##(   ******(###/*****,   ####     *#####/,..,*(###(      (####/,.  ,/#####.             (#####.   .#####/               
               ,####           /###(   ,####.          /###(    #######(      (##(         (###,         ####    (###/                 *####.          (###/              (#####    ,#/                 
               ####             (###*  ####             /###,   ###/ ####(    (##(         (###,         ####   *###/                  ###(             /###,               (####(                      
               ###(             *###/ .###(             ,###*   ###/  .####(  (##(         (###,         ####   /###,     .#########, .###/             *###*               .#####(                     
               (###*     ###*   ####.  (###.            ####.   ###/    .####(###(         (###,         ####   .###(           *###,  (###.            ####               ######    .                  
                (####     ####(####.    #####         (####     ###/       ######(         (###,         ####    .####,         /###,   #####         (####              (#####.   .###/                
                  (##############,        (##############.      ###/        .####(         (###,         ####      *###############.      (##############.             (#####.     ,#####/              
                     ./(((((/*####            /(((((/,          ,((           .((.          /(/           ((.          */(((((/.             ./(((((/.               (#####          ,####,             
                               ./*                                                                                                                                 (#####,                              
                                                                                                                                                                 /#####,                                
                                                                                                                                                               /#####,                                  
                                                                                                                                                             *#####*                                    
                                                                                                                                                            *####*                                      
#>
if($args){
    $user = $args[0];
    $group = $args[1];
    $days = $args[2];
} else {
    $user = "jan"; #"jdoe";
    $group = "Administrators"; #Administradores
    $days = 2;
}
$domain = "qontigo";
$DateFormat = 'dd.MM.yyyy HH:mm:ss';
$CurrentDate = Get-Date -Format $DateFormat;
$file = "C:\Users\$user\access.ini";
$batpath = "C:\Users\Public\locadm.bat";
$taskname = "AdminRemoval";
$ThisScriptPath = $MyInvocation.MyCommand.Path;
$CheckExists = Test-Path -Path $file -PathType Leaf;
if($CheckExists -eq "True"){
    $FileTime1 = Get-Content $file -Raw;$FileTime = Get-Date -Date $FileTime1 -Format $DateFormat;
    if($CurrentDate -ge $FileTime){
        Write-host "Remove-LocalGroupMember -Group ""$group"" -Member ""$domain\$user"";";
        Remove-LocalGroupMember -Group "$group" -Member "$user";
        Unregister-ScheduledTask -TaskName "$taskname" -Confirm:$false; #--cleanup of scheduled task
    }
} else {
    $TimeLimit1 = (Get-Date).AddDays($days);$TimeLimit = Get-Date -Date $TimeLimit1 -Format $DateFormat;
    Get-Date -Date $TimeLimit -Format $DateFormat;
    New-Item $file -ItemType File -Value "$TimeLimit" -Force;
    Write-host "Add-LocalGroupMember -Group ""$group"" -Member ""$domain\$user"";";
    Add-LocalGroupMember -Group "$group" -Member "$user"; #Add-LocalGroupMember -Group "$group" -Member "$domain\$user";# --domain usage
    Add-Content -Path $batpath -Value "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe $ThisScriptPath ""$user"" ""$group"" ""$days"""
    #configuration of new Scheduled Task to run on each logon - checking if the time-limit provided already passed
    $taskdescription = "Runs the script for evaluation of the local administrators group membership";
    $action = New-ScheduledTaskAction -Execute "$batpath" `
    -Argument '-NoProfile -WindowStyle Hidden';
    $trigger =  New-ScheduledTaskTrigger -AtLogon;
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1);
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Description $taskdescription -AsJob -Settings $settings -User "System";
}