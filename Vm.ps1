Import-Module VMware.VimAutomation.Core
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

function ConvertTo-AESKey128 {
    param (
        [Parameter(Mandatory=$true)]
        [string]$String
    )

    # Convert the string to bytes using UTF8 encoding
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($String)

    # Compute the SHA-256 hash of the bytes
    $SHA256 = [System.Security.Cryptography.SHA256]::Create()
    $Hash = $SHA256.ComputeHash($Bytes)

    # Take the first 16 bytes (128 bits) of the hash as the key
    $Key = $Hash[0..15]

    return $Key
}
function Encrypt-Strings {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$StringsToEncrypt,
        [Parameter(Mandatory=$true)]
        [byte[]]$Aes128Key
    )


    $encryptedStrings = @()

    foreach ($string in $StringsToEncrypt) {
        $plaintextBytes = [System.Text.Encoding]::UTF8.GetBytes($string)


        $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $aes.KeySize = 128
        $aes.BlockSize = 128
        $aes.Key = $Aes128Key
        $aes.IV = (New-Object Byte[] 16)
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7


        $encryptor = $aes.CreateEncryptor()

        $encryptedBytes = $encryptor.TransformFinalBlock($plaintextBytes, 0, $plaintextBytes.Length)
        $encryptedString = [System.Convert]::ToBase64String($encryptedBytes)
        $encryptedStrings += $encryptedString
    }

    return $encryptedStrings
}

function Encrypt-StringsToJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$StringsToEncrypt,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [string]$OutputFilePath
    )

    $encryptedStrings = Encrypt-Strings -StringsToEncrypt $StringsToEncrypt -Aes128Key $AesKey

    $jsonContent = @{
        EncryptedStrings = $encryptedStrings
    } | ConvertTo-Json

    Set-Content -Path $OutputFilePath -Value $jsonContent
}

function Decrypt-StringsFromJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$JsonFilePath,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey
    )

    # Print the key
 
    $json = Get-Content $JsonFilePath | ConvertFrom-Json

    $encryptedStrings = $json.EncryptedStrings

    

    $decryptedStrings = @()

    foreach ($encryptedString in $EncryptedStrings) {
        $encryptedBytes = [System.Convert]::FromBase64String($encryptedString)

        $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $aes.KeySize = 128
        $aes.BlockSize = 128
        $aes.Key = $AesKey
        $aes.IV = (New-Object Byte[] 16)
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7


        $decryptor = $aes.CreateDecryptor()

        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        $decryptedString = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
        $decryptedStrings += $decryptedString
    }

    return $decryptedStrings
}

function get_credentials {
    [CmdletBinding()]
    Param()

    Write-Host "`nSelect Login mode"
    Write-Host "    1. Login with manual credentials"
    Write-Host "    2. Login stored credentials"

    $mode = Read-Host "Option"

    switch ($mode) {
        "1" { 
            $Credentials = "", "",""
            $Credentials[0] = Read-Host "Enter the server IP "
            $Credentials[1] = Read-Host "Enter the User "
            $tmp = Read-Host "Enter the Password: " -AsSecureString
            $Credentials[2] = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($tmp))
            
            Write-Host "Do you wanna save the credentials? (y/n)"
            $save = Read-Host "Option"
            if ($save -eq "y") {
                Write-Host "Enter the name of the credential"
                $name = Read-Host "Name"
                Write-Host "Enter the Password for encrypting"
                $pass = Read-Host "Hash"

                $hash = ConvertTo-AESKey128 -String $pass
                
                Encrypt-StringsToJsonFile -StringsToEncrypt $Credentials -AesKey $hash -OutputFilePath "$name.json"

            }
            
            return $Credentials


         }
        "2" { 
            #list all the json files in the current directory
            $jsonFiles = Get-ChildItem -Path . -Filter *.json -Recurse -File

            foreach ($file in $jsonFiles) {
                Write-Host "`t -" $file.Name.Substring(0, $file.Name.Length - 5) -ForegroundColor Green
            }

            Write-Host "Enter the credential name"
            $name = Read-Host "Name"
            Write-Host "Enter the Password for decrypting the data"
            $pass = Read-Host "Hash" -AsSecureString

            $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))

            $hash = ConvertTo-AESKey128 -String $pass


            #decrypt the strings
            $decryptedStrings = Decrypt-StringsFromJson  -JsonFilePath "$name.json" -AesKey $hash

       
            return $decryptedStrings
          
         }
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            exit}
    }
  
}

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