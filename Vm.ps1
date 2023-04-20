Import-Module VMware.VimAutomation.Core
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
. .\Auth.ps1


function Select_from_menu {
    [CmdletBinding()]
    Param()

    Write-Host "`nWhat do you want to do?"
    Write-Host "    1. Shutdown VM/VMs"
    Write-Host "    2. Restart VM/VMs"
    Write-Host "    3. Start VM/VMs"
    Write-Host "    4. Exit"

    $mode = Read-Host "Option"

    return $mode

}

function shutdown_all_vms {
    [CmdletBinding()]
    Param()

    $vms = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}

    foreach ($vm in $vms) {
        Write-Host "Shutting down $vm" -ForegroundColor Green
        Stop-VM -VM $vm -Confirm:$true
    }
}

function shutdown_specific_vm {
    [CmdletBinding()]
    Param()

    $vm = Read-Host "Enter the VM name"
    Write-Host "Shutting down $vm" -ForegroundColor Green
    Stop-VM -VM $vm -Confirm:$true

}

function shutdown_group_vms {
    [CmdletBinding()]
    Param()

    $csvFile =Read-Host "Enter the CSV Path "

    try {
        $ErrorActionPreference = "Stop";

        $data = Import-Csv -Path $csvFile
        # Print host names
        foreach ($hostx in $data) {
            Stop-VM -VM $hostx.Name -Confirm:$true
        }

    }catch{

        Write-Host "`nInvalid CSV" -ForegroundColor Red
        Disconnect-VIServer -Confirm:$false
        # Code to ensure the script is closed
        Exit
        
    }
}

function shutdown_vm {
    [CmdletBinding()]
    Param()

    Write-Host "`nSelect Option"
    Write-Host "    1. Shutdown all VMs"
    Write-Host "    2. Shutdown a specific VM"
    Write-Host "    3. Shutdown a group of VMs"
    Write-Host "    4. Exit"

    $mode = Read-Host "Option"

    switch ($mode) {
        "1" {
            shutdown_all_vms
        }
        "2" {
            shutdown_specific_vm
        }
        "3"{
            shutdown_group_vms
        }
        "4" {
            Write-Host "`nExiting"
            exit
        }
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            exit
        }
    }
    
}

function restart_all_vms {
    [CmdletBinding()]
    Param()

    $vms = Get-VM |  Where-Object {$_.PowerState -eq "PoweredOn"}

    foreach ($vm in $vms) {
        Write-Host "Restarting $vm" -ForegroundColor Green
        Restart-VM -VM $vm -Confirm:$true
    }
}

function restart_specific_vm {
    [CmdletBinding()]
    Param()

    $vm = Read-Host "Enter the VM name"
    Write-Host "Restarting $vm" -ForegroundColor Green
    Restart-VM -VM $vm -Confirm:$true

}

function restart_group_vms {
    [CmdletBinding()]
    Param()

    $csvFile =Read-Host "Enter the CSV Path "

    try {
        $ErrorActionPreference = "Stop";

        $data = Import-Csv -Path $csvFile
        # Print host names
        foreach ($hostx in $data) {
            Restart-VM -VM $hostx.Name -Confirm:$true
        }

    }catch{

        Write-Host "`nInvalid CSV" -ForegroundColor Red
        Disconnect-VIServer -Confirm:$false
        # Code to ensure the script is closed
        Exit
        
    }
}

function restart_vm {
    [CmdletBinding()]
    Param()

    Write-Host "`nSelect Option"
    Write-Host "    1. Restart all VMs"
    Write-Host "    2. Restart a specific VM"
    Write-Host "    3. Restart a group of VMs"
    Write-Host "    4. Exit"

    $mode = Read-Host "Option"

    switch ($mode) {
        "1" {
            restart_all_vms
        }
        "2" {
            restart_specific_vm
        }
        "3"{
            restart_group_vms
        }
        "4" {
            Write-Host "`nExiting"
            exit
        }
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            exit
        }
    }

}

function start_all_vms {
    [CmdletBinding()]
    Param()

    $vms = Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"}

    foreach ($vm in $vms) {
        Write-Host "Starting $vm" -ForegroundColor Green
        Start-VM -VM $vm -Confirm:$true
    }
}

function start_specific_vm {
    [CmdletBinding()]
    Param()

    $vm = Read-Host "Enter the VM name"
    Write-Host "Starting $vm" -ForegroundColor Green
    Start-VM -VM $vm -Confirm:$true

}

function start_group_vms {
    [CmdletBinding()]
    Param()

    $csvFile =Read-Host "Enter the CSV Path "

    try {
        $ErrorActionPreference = "Stop";

        $data = Import-Csv -Path $csvFile
        # Print host names
        foreach ($hostx in $data) {
            Start-VM -VM $hostx.Name -Confirm:$true
        }

    }catch{

        Write-Host "`nInvalid CSV" -ForegroundColor Red
        Disconnect-VIServer -Confirm:$false
        # Code to ensure the script is closed
        Exit
        
    }
}

function start_vm {
    [CmdletBinding()]
    Param()

    Write-Host "`nSelect Option"
    Write-Host "    1. Start all VMs"
    Write-Host "    2. Start a specific VM"
    Write-Host "    3. Start a group of VMs"
    Write-Host "    4. Exit"

    $mode = Read-Host "Option"



    switch ($mode) {
        "1" {
            
            start_all_vms
        }
        "2" {
            start_specific_vm
        }
        "3"{
            start_group_vms
        }
        "4" {
            Write-Host "`nExiting"
            exit
        }
        
    }
}

function Process_option {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$mode
    )

    Clear-Host -Confirm:$false


    switch ($mode) {
        "1" {
            shutdown_vm
        }
        "2" {
            restart_vm
        }
        "3" {
            start_vm
        }
        "4" {
            Write-Host "`nExiting"
            exit
        }
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            exit
        }
    }

}


Clear-Host
#start a job to get the credentials using get_credentials
$data = get_credentials


try {
    $ErrorActionPreference = "Stop";
    Connect-VIServer -Server $data[0] -User $data[1] -Password $data[2]

}catch{
    Write-Host "`nAn exception occurred`n" -ForegroundColor Red
    Exit
} 
Clear-Host -Confirm:$false
$mode = Select_from_menu
Process_option -mode $mode
Clear-Host -Confirm:$false