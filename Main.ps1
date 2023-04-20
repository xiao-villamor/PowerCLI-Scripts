. .\misc\Auth.ps1
. .\misc\Vm.ps1
. .\misc\ShutdDownHosts.ps1
. .\misc\MainMenu.ps1

$data = get_credentials

start_main_menu -Credentials $data

