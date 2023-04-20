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
function Encrypt_Strings {
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

function Encrypt_StringsToJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$StringsToEncrypt,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [string]$name
    )



    $encryptedStrings = Encrypt_Strings -StringsToEncrypt $StringsToEncrypt -Aes128Key $AesKey

    #check if the xml exists, if not create it and add the root element "Credentials"
    if (!(Test-Path "credentials.xml")) {
        $xml = New-Object System.Xml.XmlDocument
        $xml.LoadXml("<Credentials></Credentials>")
        $xml.Save("credentials.xml")
    }

    $xml = New-Object System.Xml.XmlDocument
    $xml.Load("credentials.xml")

    $root = $xml.DocumentElement

    
    
    # Create the new node to be added
    $newNode = $xml.CreateElement("Credential")
    $newNode.SetAttribute("name", $name)
    $newNode2 = $xml.CreateElement("data")

    $ipenc = $xml.CreateElement("ip")
    $ipenc.InnerText = $encryptedStrings[0]
    $userenc = $xml.CreateElement("user")
    $userenc.InnerText = $encryptedStrings[1]
    $passenc = $xml.CreateElement("pass")
    $passenc.InnerText = $encryptedStrings[2]

    $newNode2.AppendChild($ipenc)
    $newNode2.AppendChild($userenc)
    $newNode2.AppendChild($passenc)


    $newNode.AppendChild($newNode2)


    # Append the new node to the root element
    $root.AppendChild($newNode)

    # Save the updated XML file
    $xml.Save("credentials.xml")


}

function Decrypt_StringsFromJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$JsonFilePath,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey
    )

    # get the object credentials in wich param name is equal to $JsonFilePath from the xml file
    $xml = New-Object System.Xml.XmlDocument
    $xml.Load("credentials.xml")

    $root = $xml.DocumentElement

    $credentials = $root.GetElementsByTagName("Credential") | Where-Object {$_.Attributes.GetNamedItem("name").Value -eq $JsonFilePath}



    
    $encryptedStrings = $credentials.GetElementsByTagName("data").GetElementsByTagName("ip").InnerText, $credentials.GetElementsByTagName("data").GetElementsByTagName("user").InnerText, $credentials.GetElementsByTagName("data").GetElementsByTagName("pass").InnerText

    

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

    $Credentials = "0", "1","2"

    switch ($mode) {
        "1" { 
           
            $Credentials[0] = Read-Host "Enter the server IP "
            $Credentials[1] = Read-Host "Enter the User "
            $tmp = Read-Host "Enter the Password: " -AsSecureString
            $Credentials[2] = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($tmp))
       

        
            $save = Read-Host "Do you wanna save the credentials? (y/n)"

            if ($save -eq "y") {
                Write-Host "Enter the name of the credential"
                $name = Read-Host "Name"
                Write-Host "Enter the Password for encrypting"
                $pass = Read-Host "Hash" -AsSecureString

                $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))

                $hash = ConvertTo-AESKey128 -String $pass
                
                #encrypt the credentials and save them in the xml file but in other thread   

                Encrypt_StringsToJsonFile -StringsToEncrypt $Credentials -Aeskey $hash -name $name
                
                Return $Credentials
                
            }else{
                return $Credentials
            }

            

         }
        "2" { 
            Clear-Host
            Write-Host "Saved credentials : "
            #list the atribute name from all the credentials in the xml file
            $xml = New-Object System.Xml.XmlDocument
            $xml.Load("credentials.xml")

            $root = $xml.DocumentElement

            $credentials2 = $root.GetElementsByTagName("Credential")

            foreach ($credential in $credentials2) {
                Write-Host $credential.Attributes.GetNamedItem("name").Value
            }
            
            
            $name = Read-Host "`nEnter the credential name"
            Write-Host "Enter the Password for decrypting the data"
            $pass = Read-Host "Hash" -AsSecureString

            $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))

            $hash = ConvertTo-AESKey128 -String $pass


            #decrypt the strings
            $Credentials = Decrypt_StringsFromJson  -JsonFilePath $name -AesKey $hash

            Return $Credentials
       
          
        }
         
        Default {
            Write-Host "`nInvalid option" -ForegroundColor Red
            exit
        }
    }

  
}