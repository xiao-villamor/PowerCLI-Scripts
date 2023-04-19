Import-Module VMware.VimAutomation.Core
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

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




