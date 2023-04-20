
function start_main_menu {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string[]]$Credentials
    )
    Clear-Host -Confirm:$false


    Write-Host "`nWhat Script do you want to run?"
    Write-Host "    1. Shutdown Hosts"
    Write-Host "    2. Manage VMs"
    Write-Host "    3. Exit"

    $mode = Read-Host "Option"

    switch ($mode) {
        "1" {
            start_host_script -Credentials $data
        }
        "2" {
            start_vm_script -Credentials $data
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