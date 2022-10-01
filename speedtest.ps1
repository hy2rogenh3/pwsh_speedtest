function Get-InternetSpeed {

    <#
        .SYNOPSIS
        Uses Speedtest-Cli to get speed test at specifed server

        .DESCRIPTION
        Using Speedtest-cli function will get speed test to server specified, log to a directory of choosing,
        then email the result if the speed is over a specified amount.

        .PARAMETER STARTDIR
        Specifies the start directory for future references in function

        .PARAMETER SPEEDTEST
        Specifies the exe for the speedtest-cli application

        .PARAMETER SPEEDTEST
        Specifies the exe for the speedtest-cli application

        .PARAMETER TO
        Specifies the address to send the result email to

        .PARAMETER FROM
        Specifies the from address to send email from. Best to create a new account for running services.

        .PARAMETER SUBJECT
        Specifies the subject of the email

        .PARAMETER SPEEDTESTSERVER
        Specifies the speedtest.net server to test against

        .PARAMETER EXCEEDEDSPEED
        Specifies the speed as an integer to exceed before sending an email (in Mbps)

        .EXAMPLE
        Create a scheduled task 
        Set to run daily/hourly as desired
        Action Run: powershell.exe -NoProfile -File "PATH\TO\Script\getspeedtest.ps1"


    #>

    [CmdletBinding()]
    param(
        
        [string]$startDir = 'C:\Speedtest',
        [string]$speedtest = 'C:\Speedtest\bin\speedtest.exe',
        [string]$to = "your_email@gmail.com",
        [string]$from = "service_account@gmail.com",
        [string]$subject = "New Speedtest",
        [string]$emailServer = 'smtp.gmail.com',
        [int]$emailServerPort = '587',
        [int]$speedtestServer = "1774",
        [int]$exceededSpeed = "100",
        [Parameter(Mandatory)]
        [ValidateSet("Y", "N")]
        $emailResults,
        [Parameter(Mandatory)]
        [ValidateSet("Y", "N")]
        $exportResults
    )
   
    begin {
   
        #Set File date-time
        $fileDate = Get-Date -Format FileDateTime
   
        if ($emailResults -eq "Y") {
            
            #Check if stored credential exists for sending email

            if (!(Test-Path -Path "$startDir\bin\service.ss")) {

                #Create Secure String file credentail store
                New-Item -Path "$startDir\bin\service.ss"

                Write-Host "No stored email credentail found for sending email. Creating stored credential"
                $secPass = Read-Host -Prompt "Enter Email Service Account Password" -AsSecureString
                ConvertFrom-SecureString $secPass | Add-Content -Path $startDir\bin\service.ss

            }

            #Set Email service account and settings
            $username = $from
            $password = Get-Content $startDir\bin\service.ss | ConvertTo-SecureString
   
            #Set TLS version
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
            #Build PS Credential object
            $cred = New-Object System.Management.Automation.PSCredential ("$username", $password)
        
        }
       
    }
     
    process {
   
        try {

            try {
   
                #Run speedtest
                $currentTest = & $speedtest --server-id=$speedtestServer --precision=2 --format=json
 
            }
   
            catch {
   
                Write-Host "Unable to run speedtest: $($_.Exception.Message)."
                break
   
            }
   
            #Convert result from json
            $currentTest = $currentTest | ConvertFrom-Json

            #Calculate bandwidth and set result variables
            $downloadSpeed = $currentTest.download.bandwidth / 125000
            $uploadSpeed = $currentTest.upload.bandwidth / 125000
            $testTime = $currentTest.timestamp
            $validation = $currentTest.result.url

            switch ("$emailResults") {

                "Y" {

                    if ($downloadSpeed -ge "$exceededSpeed") {
   
                        $body = @"
           
                    <html>
                    <head></head>
                    <body>
                    <table cellpadding="0" cellspacing="0" width="740" align="center" border="1">     
                    <tr>         
                    <td>             
                    <table cellpadding="0" cellspacing="0" width="740" align="left" border="1">                 
                    <tr>                     
                    <td>Speedtest Date<td>                     
                    <td>$testTime</td>                 
                    </tr>  
                    <tr>                     
                    <td>Download Speed<td>                     
                    <td>$downloadSpeed</td>                 
                    </tr>    
                    <tr>                     
                    <td>Upload Speed<td>                     
                    <td>$uploadSpeed</td>                 
                    </tr>     
                    <tr>                     
                    <td>Validation<td>                     
                    <td>$validation</td>                 
                    </tr>     
                    </table>            
                    </body>      
                    </html>
"@
           
                        #Send email if speed exceeds set amount in $exceededSpeed
                        Send-MailMessage -Credential $cred -SmtpServer $emailServer -Port $emailServerPort -From $from -To $to -Subject $subject -Body $body -BodyAsHtml -UseSsl
           
                    }

                }
            
                "N" {

                    break

                }

            }

            switch ("$exportResults") {

                "Y" {

                    if (!(Test-Path -Path "$startDir\results")) {

                        New-Item -ItemType Directory "$startDir\results"

                    }

                    #Export to CSV
                    $currentTest | Export-Csv "$startdir\results\speedtest.$fileDate.csv"

                }

                "N" {

                    break
               
                }

            }

        }

        catch {

            Write-Host "Unable to process speed test due to $($_.Exception.Message)."

        }
        
    }
   
    end {
     
        return $downloadSpeed, $uploadSpeed

    }
   
}