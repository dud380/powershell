
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Devices.Sms.SmsDevice2,Windows.Devices.Sms,ContentType=WindowsRuntime] > $null
[Windows.Devices.Sms.SmsTextMessage2,Windows.Devices.Sms,ContentType=WindowsRuntime] > $null
[Windows.Devices.Sms.SmsSendMessageResult,Windows.Devices.Sms,ContentType=WindowsRuntime] > $null
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]


Function Await($WinRtTask, $ResultType) {

    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}
Function AwaitAction($WinRtAction) {
    $netTask = $asTask.Invoke($null, @($WinRtAction))
    $netTask.Wait(-1) | Out-Null
}

function Send-SMS {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string] $To,

        [Parameter(Mandatory=$True)]
        [string] $Body
    )
    
    begin {
        $Device = [Windows.Devices.Sms.SmsDevice2]::GetDefault()
        $Message = [Windows.Devices.Sms.SmsTextMessage2]::new()
        $Message.To = $To
        $Message.Body = $Body
    }
    
    process {
        $Result = Await ($Device.SendMessageAndGetResultAsync($Message)) ([Windows.Devices.Sms.SmsSendMessageResult])
        
        if(!$Result.IsSuccessful){
            Write-Warning "SMS not sent"
        }
    }
    
    end {
    }
}


function Get-SMSDevicePhoneNumber{
    $Device = [Windows.Devices.Sms.SmsDevice2]::GetDefault()
    $Device.SmscAddress

}

#Send-SMS -To 0766770874 -Body "Hej"
#Get-SMSDevicePhoneNumber