<# 
.SYNOPSIS
    Intune Device UPN Restoration Script

.DESCRIPTION
    This script restores previously removed User Principal Names (UPNs) back to their respective devices in Microsoft Intune.
    It reads user-device associations from a CSV backup file and reassigns users using Microsoft Graph API.

.AUTHOR
    Alessio Orpellini

.CONTACT
    Email: alessio.orpellini@gmail.com
    Website: https://github.com/DatacorpCloud

.VERSION
    1.0

.LICENSE
   GNU GPL v3

.REQUIREMENTS
    - Microsoft Graph PowerShell SDK
    - Permissions: DeviceManagementManagedDevices.ReadWrite.All
    - Backup CSV file ('removeUPN_backup.csv') generated from the removal script.

.NOTES
    - The script logs operations in 'restoreUPN_log.txt'.
    - Ensure 'removeUPN_backup.csv' is available before running the script.

#>

# Percorso del file CSV (deve essere nella stessa cartella dello script)
$csvPath = "$PSScriptRoot\removeUPN_backup.csv"

# Connessione a Microsoft Graph
try {
    Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certificateThumbprint
    Write-Host "Connesso al tenant: $tenantId" -ForegroundColor Green
} catch {
    Write-Host "Errore di connessione: $_" -ForegroundColor Red
    exit
}

# Importa i dati dal file CSV
$usersToRestore = Import-Csv -Path $csvPath -Delimiter ','

foreach ($entry in $usersToRestore) {
    $deviceId = $entry.DeviceID
    $userUPN = $entry.UserPrincipalName

    # Verifica se l'utente è valido (non vuoto)
    if (-not [string]::IsNullOrEmpty($userUPN)) {
        try {
            # Ottenere l'ID GUID dell'utente da Microsoft Graph utilizzando l'UPN
            $user = Get-MgUser -Filter "userPrincipalName eq '$userUPN'"

            if ($user -and $user.Id) {
                $userId = $user.Id
                Write-Host ("Trovato GUID per {0}: {1}" -f $userUPN, $userId)

                # Endpoint API Graph per associare l'utente al dispositivo
                $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/users/`$ref"

                # Corpo della richiesta con l'ID GUID dell'utente
                $body = @{
                    "@odata.id" = "https://graph.microsoft.com/beta/users/$userId"
                }

                # Invio della richiesta API per riassociare l'utente
                Invoke-MgGraphRequest -Method POST -Uri $url -Body ($body | ConvertTo-Json -Depth 2 -Compress) -ContentType "application/json"

                Write-Host "Utente $userUPN riaggiunto al dispositivo ID: $deviceId" -ForegroundColor Green
            } else {
                Write-Host "Utente ${userUPN} non trovato in Azure AD." -ForegroundColor Yellow
            }
        } catch {
            Write-Host ("Errore nel riaggiungere l'utente {0} al dispositivo {1}: {2}" -f $userUPN, $deviceId, $_) -ForegroundColor Red
        }
    } else {
        Write-Host "Nessun utente associato per il dispositivo ID: ${deviceId}" -ForegroundColor Yellow
    }
}


# Disconnessione da Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnessione completata" -ForegroundColor Cyan
