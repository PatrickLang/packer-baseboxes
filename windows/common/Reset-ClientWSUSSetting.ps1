$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

for ([byte]$c = [char]'A'; $c -le [char]'Z'; $c++)  
{  
    $variablePath = [char]$c + ':\variables.ps1'

    if (test-path $variablePath) {
        . $variablePath
        break
    }
}

"Starting SetClientWSUSSettingTask" | Out-File -Filepath "$($env:TEMP)\BoxImageCreation_SetClientWSUSSettingTask.started.txt" -Append

Function Set-ClientWSUSSetting {
    <#  
    .SYNOPSIS  
        Sets the wsus client settings on a local or remove system.

    .DESCRIPTION
        Sets the wsus client settings on a local or remove system.

    .PARAMETER UpdateServer
        URL of the WSUS server. Must use Https:// or Http://

    .PARAMETER TargetGroup
        Name of the Target Group to which the computer belongs on the WSUS server.
    
    .PARAMETER DisableTargetGroup
        Disables the use of setting a Target Group
    
    .PARAMETER Options
        Configure the Automatic Update client options. 
        Accepted Values are: "Notify","DownloadOnly","DownloadAndInstall","AllowUserConfig"

    .PARAMETER DetectionFrequency
        Specifed time (in hours) for detection from client to server.
        Accepted range is: 1-22
    
    .PARAMETER DisableDetectionFrequency
        Disables the detection frequency on the client.
    
    .PARAMETER RebootLaunchTimeout
        Set the timeout (in minutes) for scheduled restart.
        Accepted range is: 1-1440
    
    .PARAMETER DisableRebootLaunchTimeout              
        Disables the reboot launch timeout.
    
    .PARAMETER RebootWarningTimeout
        Set the restart warning countdown (in minutes)
        Accepted range is: 1-30
     
    .PARAMETER DisableRebootWarningTimeout
        Disables the reboot warning timeout  
        
    .PARAMETER RescheduleWaitTime
        Time (in minutes) that Automatic Updates should wait at startup before applying updates from a missed scheduled installation time.
      
    .PARAMETER DisableRescheduleWaitTime
        Disables the RescheduleWaitTime   
    
    .PARAMETER ScheduleInstallDay                  
        Specified Day of the week to perform automatic installation. Only valid when Options is set to "DownloadAndInstall"
        Accepted values are: "Everyday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
    
    .PARAMETER ElevateNonAdmins
        Allow non-administrators to approve or disapprove updates
        Accepted values are: "Enable","Disable"
    
    .PARAMETER AllowAutomaticUpdates
        Enables or disables Automatic Updates
        Accepted values are: "Enable","Disable"
    
    .PARAMETER UseWSUSServer
        Enables or disables use of a Windows Update Server
        Accepted values are: "Enable","Disable"
    
    .PARAMETER AutoInstallMinorUpdates
        Enables or disables silent installation of minor updates.
        Accepted values are: "Enable","Disable"
    
    .PARAMETER AutoRebootWithLoggedOnUsers
        Enables or disables automatic reboots after patching completed whether users or logged into the machine or not.
        Accepted values are: "Enable","Disable"

    .NOTES  
        Name: Set-WSUSClient
        Author: Boe Prox
        https://learn-powershell.net
        DateCreated: 02DEC2011 
        DateModified: 28Mar2014
        
        To do: Add -PassThru support
               
    .LINK  
        http://technet.microsoft.com/en-us/library/cc708449(WS.10).aspx
        
    .EXAMPLE
    Set-ClientWSUSSetting -UpdateServer "http://testwsus.com" -UseWSUSServer Enable -AllowAutomaticUpdates Enable -DetectionFrequency 4 -Options DownloadOnly

    Description
    -----------
    Configures the local computer to enable automatic updates and use testwsus.com as the update server. Also sets the update detection
    frequency to occur every 4 hours and only downloads the updates. 
    
    .EXAMPLE
    Set-ClientWSUSSetting -UpdateServer "http://testwsus.com" -UseWSUSServer Enable -AllowAutomaticUpdates Enable -DetectionFrequency 4 -Options DownloadAndInstall -RebootWarningTimeout 15 
    -ScheduledInstallDay Monday -ScheduledInstallTime 20
    
    Description
    -----------
    Configures the local computer to enable automatic updates and use testwsus.com as the update server. Also sets the update detection
    frequency to occur every 4 hours and performs the installation automatically every Monday at 8pm and configured to reboot 15 minutes (with a timer for logged on users) after updates
    have been installed.

    #>
    [cmdletbinding(
        SupportsShouldProcess = $True
    )]
    Param (
        [parameter(Position=0)]
        [string]$UpdateServer,
        [parameter(Position=1)]
        [string]$TargetGroup,
        [parameter(Position=2)]
        [switch]$DisableTargetGroup,         
        [parameter(Position=3)]
        [ValidateSet('Notify','DownloadOnly','DownloadAndInstall','AllowUserConfig')]
        [string]$Options,
        [parameter(Position=4)]
        [ValidateRange(1,22)]
        [Int32]$DetectionFrequency,
        [parameter(Position=5)]
        [switch]$DisableDetectionFrequency,        
        [parameter(Position=6)]
        [ValidateRange(1,1440)]
        [Int32]$RebootLaunchTimeout,
        [parameter(Position=7)]
        [switch]$DisableRebootLaunchTimeout,        
        [parameter(Position=8)]
        [ValidateRange(1,30)]  
        [Int32]$RebootWarningTimeout,
        [parameter(Position=9)]
        [switch]$DisableRebootWarningTimeout,        
        [parameter(Position=10)]
        [ValidateRange(1,60)]
        [Int32]$RescheduleWaitTime,
        [parameter(Position=11)]
        [switch]$DisableRescheduleWaitTime,        
        [parameter(Position=12)]
        [ValidateSet('EveryDay','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
        [ValidateCount(1,1)]
        [string[]]$ScheduleInstallDay,
        [parameter(Position=13)]
        [ValidateRange(0,23)]
        [Int32]$ScheduleInstallTime,
        [parameter(Position=14)]
        [ValidateSet('Enable','Disable')]
        [string]$ElevateNonAdmins,    
        [parameter(Position=15)]
        [ValidateSet('Enable','Disable')]
        [string]$AllowAutomaticUpdates,  
        [parameter(Position=16)]
        [ValidateSet('Enable','Disable')]
        [string]$UseWSUSServer,
        [parameter(Position=17)]
        [ValidateSet('Enable','Disable')]
        [string]$AutoInstallMinorUpdates,
        [parameter(Position=18)]
        [ValidateSet('Enable','Disable')]
        [string]$AutoRebootWithLoggedOnUsers                                              
    )
    Begin {
    }
    Process {
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose ("{0}" -f $_)
        }

        Push-Location
        Set-Location HKLM:        

        $WSUSEnvhash = @{}
        $WSUSConfigHash = @{}

        #Set WSUS Client Environment Options
        $WSUSEnv = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        
        #Check to see if WSUS registry keys exist
        If (!(Test-Path $WSUSEnv)) {
            New-Item $WSUSEnv
        }

        If (!(Test-Path "$WSUSEnv\AU")) {
            New-Item "$WSUSEnv\AU"
        }

        If ($PSBoundParameters['ElevateNonAdmins']) {
            If ($ElevateNonAdmins -eq 'Enable') {
                If ($pscmdlet.ShouldProcess("Elevate Non-Admins","Enable")) {
                    Set-ItemProperty -Path $WSUSEnv -Name "ElevateNonAdmins" -Value 1 -Type DWord
                }
            } ElseIf ($ElevateNonAdmins -eq 'Disable') {
                If ($pscmdlet.ShouldProcess("Elevate Non-Admins","Disable")) {
                    Set-ItemProperty -Path $WSUSEnv -Name "ElevateNonAdmins" -Value 0 -Type DWord
                }
            }
        }
        If ($PSBoundParameters['UpdateServer']) {
            If ($pscmdlet.ShouldProcess("WUServer","Set Value")) {
                Set-ItemProperty -Path $WSUSEnv -Name "WUServer" -Value $UpdateServer -Type String
            }
            If ($pscmdlet.ShouldProcess("WUStatusServer","Set Value")) {
                Set-ItemProperty -Path $WSUSEnv -Name "WUStatusServer" -Value $UpdateServer -Type String
            }
        }
        If ($PSBoundParameters['TargetGroup']) {
            If ($pscmdlet.ShouldProcess("TargetGroup","Enable")) {
                Set-ItemProperty -Path $WSUSEnv -Name "TargetGroupEnabled" -Value 1 -Type DWord
            }
            If ($pscmdlet.ShouldProcess("TargetGroup","Set Value")) {
                Set-ItemProperty -Path $WSUSEnv -Name "TargetGroup" -Value $TargetGroup -Type String
            }
        }    
        If ($PSBoundParameters['DisableTargetGroup']) {
            If ($pscmdlet.ShouldProcess("TargetGroup","Disable")) {
                Set-ItemProperty -Path $WSUSEnv -Name "TargetGroupEnabled" -Value 0 -Type DWord
            }
        }      
                               
        #Set WSUS Client Configuration Options
        $WSUSConfig = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        If ($PSBoundParameters['Options']) {
            If ($pscmdlet.ShouldProcess("Options","Set Value")) {
                If ($Options -eq 'Notify') {
                    Set-ItemProperty -Path $WSUSConfig -Name "AUOptions" -Value 2 -Type DWord
                } ElseIf ($Options = 'DownloadOnly') {
                    Set-ItemProperty -Path $WSUSConfig -Name "AUOptions" -Value 3 -Type DWord
                } ElseIf ($Options = 'DownloadAndInstall') {
                    Set-ItemProperty -Path $WSUSConfig -Name "AUOptions" -Value 4 -Type DWord
                } ElseIf ($Options = 'AllowUserConfig') {
                    Set-ItemProperty -Path $WSUSConfig -Name "AUOptions" -Value 5 -Type DWord
                }
            }
        } 
        If ($PSBoundParameters['DetectionFrequency']) {
            If ($pscmdlet.ShouldProcess("DetectionFrequency","Enable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "DetectionFrequencyEnabled" -Value 1 -Type DWord
            }
            If ($pscmdlet.ShouldProcess("DetectionFrequency","Set Value")) {
                Set-ItemProperty -Path $WSUSConfig -Name "DetectionFrequency" -Value $DetectionFrequency -Type DWord
            }
        }
        If ($PSBoundParameters['DisableDetectionFrequency']) {
            If ($pscmdlet.ShouldProcess("DetectionFrequency","Disable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "DetectionFrequencyEnabled" -Value 0 -Type DWord
            }
        } 
        If ($PSBoundParameters['RebootWarningTimeout']) {
            If ($pscmdlet.ShouldProcess("RebootWarningTimeout","Enable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootWarningTimeoutEnabled" -Value 1 -Type DWord
            }
            If ($pscmdlet.ShouldProcess("RebootWarningTimeout","Set Value")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootWarningTimeout" -Value $RebootWarningTimeout -Type DWord
            }
        }
        If ($PSBoundParameters['DisableRebootWarningTimeout']) {
            If ($pscmdlet.ShouldProcess("RebootWarningTimeout","Disable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootWarningTimeoutEnabled" -Value 0 -Type DWord
            }
        }   
        If ($PSBoundParameters['RebootLaunchTimeout']) {
            If ($pscmdlet.ShouldProcess("RebootLaunchTimeout","Enable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootLaunchTimeoutEnabled" -Value 1 -Type DWord
            }
            If ($pscmdlet.ShouldProcess("RebootLaunchTimeout","Set Value")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootLaunchTimeout" -Value $RebootLaunchTimeout -Type DWord
            }
        }
        If ($PSBoundParameters['DisableRebootLaunchTimeout']) {
            If ($pscmdlet.ShouldProcess("RebootWarningTimeout","Disable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RebootLaunchTimeoutEnabled" -Value 0 -Type DWord
            }
        } 
        If ($PSBoundParameters['ScheduleInstallDay']) {
            If ($pscmdlet.ShouldProcess("ScheduledInstallDay","Set Value")) {
                If ($ScheduleInstallDay = 'EveryDay') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 0 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Monday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 1 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Tuesday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 2 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Wednesday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 3 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Thursday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 4 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Friday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 5 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Saturday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 6 -Type DWord
                } ElseIf ($ScheduleInstallDay = 'Sunday') {
                    Set-ItemProperty -Path $WSUSConfig -Name "ScheduledInstallDay" -Value 7 -Type DWord
                }
            }
        }   
        If ($PSBoundParameters['RescheduleWaitTime']) {
            If ($pscmdlet.ShouldProcess("RescheduleWaitTime","Enable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RescheduleWaitTimeEnabled" -Value 1 -Type DWord
            }
            If ($pscmdlet.ShouldProcess("RescheduleWaitTime","Set Value")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RescheduleWaitTime" -Value $RescheduleWaitTime -Type DWord
            }
        }
        If ($PSBoundParameters['DisableRescheduleWaitTime']) {
            If ($pscmdlet.ShouldProcess("RescheduleWaitTime","Disable")) {
                Set-ItemProperty -Path $WSUSConfig -Name "RescheduleWaitTimeEnabled" -Value 0 -Type DWord
            }
          } 
        If ($PSBoundParameters['ScheduleInstallTime']) {
            If ($pscmdlet.ShouldProcess("ScheduleInstallTime","Set Value")) {
                $WsusConfig.SetValue('ScheduleInstallTime',$ScheduleInstallTime,[Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }   
        If ($PSBoundParameters['AllowAutomaticUpdates']) {
            If ($AllowAutomaticUpdates -eq 'Enable') {
                If ($pscmdlet.ShouldProcess("AllowAutomaticUpdates","Enable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "NoAutoUpdate" -Value 1 -Type DWord
                }
            } ElseIf ($AllowAutomaticUpdates -eq 'Disable') {
                If ($pscmdlet.ShouldProcess("AllowAutomaticUpdates","Disable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "NoAutoUpdate" -Value 0 -Type DWord
                }
            }
        } 
        If ($PSBoundParameters['UseWSUSServer']) {
            If ($UseWSUSServer -eq 'Enable') {
                If ($pscmdlet.ShouldProcess("UseWSUSServer","Enable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "UseWUServer" -Value 1 -Type DWord
                }
            } ElseIf ($UseWSUSServer -eq 'Disable') {
                If ($pscmdlet.ShouldProcess("UseWSUSServer","Disable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "UseWUServer" -Value 0 -Type DWord
                }
            }
        }
        If ($PSBoundParameters['AutoInstallMinorUpdates']) {
            If ($AutoInstallMinorUpdates -eq 'Enable') {
                If ($pscmdlet.ShouldProcess("AutoInstallMinorUpdates","Enable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "AutoInstallMinorUpdates" -Value 1 -Type DWord
                }
            } ElseIf ($AutoInstallMinorUpdates -eq 'Disable') {
                If ($pscmdlet.ShouldProcess("AutoInstallMinorUpdates","Disable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "AutoInstallMinorUpdates" -Value 0 -Type DWord
                }
            }
        }  
        If ($PSBoundParameters['AutoRebootWithLoggedOnUsers']) {
            If ($AutoRebootWithLoggedOnUsers -eq 'Enable') {
                If ($pscmdlet.ShouldProcess("AutoRebootWithLoggedOnUsers","Enable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
                }
            } ElseIf ($AutoRebootWithLoggedOnUsers -eq 'Disable') {
                If ($pscmdlet.ShouldProcess("AutoRebootWithLoggedOnUsers","Disable")) {
                    Set-ItemProperty -Path $WSUSConfig -Name "NoAutoRebootWithLoggedOnUsers" -Value 0 -Type DWord
                }
            }
        }      

        Pop-Location
    }
}

if ($WSUSServer){
    Set-ClientWSUSSetting -UpdateServer '' -UseWSUSServer Disable
}