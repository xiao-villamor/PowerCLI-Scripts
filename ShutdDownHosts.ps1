Import-Module VMware.VimAutomation.Core
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
. .\Auth.ps1

function shutdown_from_cluster {    
    [CmdletBinding()]
    Param()

    $clustername =Read-Host "Enter the Cluster Name "

    try{
        $ErrorActionPreference = "Stop";
        $cluster = Get-Cluster -Name $clustername

    }catch{
        Write-Host "`nInvalid Cluster Name" -ForegroundColor Red
        Disconnect-VIServer -Confirm:$false
        # Code to ensure the script is closed
        Exit

    }


    # Get all hosts in cluster
    $hosts1 = Get-VMHost -Location $cluster

    # Print host names
    foreach ($hostx in $hosts1) {
        Stop-VMHost $hostx -Confirm -force 

    }

    Write-Host "`nAll hosts have been shutdown`n" -ForegroundColor Green

   
}

function shutdown_from_CSV {
    [CmdletBinding()]
    Param()

    $csvFile =Read-Host "Enter the CSV Path "


    try {
        $ErrorActionPreference = "Stop";

        $data = Import-Csv -Path $csvFile
        # Print host names
        foreach ($hostx in $data) {
            Stop-VMHost $hostx.Name -Confirm -force 
        }

    }catch{

        Write-Host "`nInvalid CSV" -ForegroundColor Red
        Disconnect-VIServer -Confirm:$false
        # Code to ensure the script is closed
        Exit
        
    }

    Write-Host "`nAll hosts have been shutdown`n" -ForegroundColor Green
   
}

function Select_from_menu {
    [CmdletBinding()]
    Param()

    Write-Host "`nWhat do you want to do?"
    Write-Host "    1. Shutdown all hosts from cluster"
    Write-Host "    2. Shutdown all hosts from a csv file"
    Write-Host "    3. Exit"

    $mode = Read-Host "Option"

    return $mode

}

function Process_option {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$mode
    )

    switch ($mode) {
        "1" {
            shutdown_from_cluster
        }
        "2" {
            Shutdown_from_CSV
        }
        "3" {
            Write-Host "`nExiting"
            Clear-Host -Confirm:$false
            exit
        }
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            Clear-Host -Confirm:$false
            exit
        }
    }

}


$data = get_credentials


try {
    $ErrorActionPreference = "Stop";
    Connect-VIServer -Server $data[0] -User $data[1] -Password $data[2]

}catch{
    Write-Host "`nAn exception occurred`n" -ForegroundColor Red
    Disconnect-VIServer -Confirm:$false
    Exit
} 

Clear-Host -Confirm:$false


$mode = Select_from_menu
Process_option -mode $mode
Clear-Host -Confirm:$false




