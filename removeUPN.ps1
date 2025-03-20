<# 
.SYNOPSIS
    Intune Device UPN Removal Script

.DESCRIPTION
    This script removes User Principal Names (UPNs) from managed devices in Microsoft Intune.
    It connects to Microsoft Graph using credentials stored in a CSV file and logs the process.
    A backup CSV file is generated to allow future restoration of removed UPNs.

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
    - Connection parameters stored in 'connection_params.csv'

.NOTES
    - The script logs operations in 'removeUPN_log.txt'.
    - Removed UPNs are saved in 'removeUPN_backup.csv' for restoration.

#>


# Percorso del file CSV contenente i parametri di connessione
$csvParamsPath = "$PSScriptRoot\connection_params.csv"

# Importa i parametri dal file CSV
try {
    $params = Import-Csv -Path $csvParamsPath -Delimiter ','
    if ($params.Count -eq 0) {
        Write-Host "Errore: Nessun parametro trovato nel file CSV." -ForegroundColor Red
        exit
    }
    
    $clientId = $params.ClientId
    $tenantId = $params.TenantId
    $certificateThumbprint = $params.CertificateThumbprint
} catch {
    Write-Host "Errore nell'importazione dei parametri dal CSV: $_" -ForegroundColor Red
    exit
}

# Percorsi dei file di log e backup CSV
$logPath = "$PSScriptRoot\removeUPN_log.txt"
$csvPath = "$PSScriptRoot\removeUPN_backup.csv"

# Funzione per scrivere nel file di log
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $logPath
}

# Connessione a Microsoft Graph
try {
    Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certificateThumbprint
    Write-Host "Connesso al tenant: $tenantId" -ForegroundColor Green
    Write-Log "Connesso con successo al tenant: $tenantId"
} catch {
    Write-Host "Errore di connessione: $_" -ForegroundColor Red
    Write-Log "Errore di connessione: $_"
    exit
}

# Ottenere i dispositivi gestiti e salvare l'elenco rimosso in CSV
$removedUsers = @()
try {
    $devices = Get-MgBetaDeviceManagementManagedDevice | Where-Object { $_.UserPrincipalName -ne $null }

    if ($devices.Count -gt 0) {
        foreach ($device in $devices) {
            try {
                $deviceId = $device.Id
                $deviceName = $device.DeviceName
                $userUPN = $device.UserPrincipalName
                $url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/users/`$ref"

                # Esegui la richiesta DELETE per rimuovere l'utente associato
                Invoke-MgGraphRequest -Method DELETE -Uri $url

                Write-Host "Utente $userUPN rimosso dal dispositivo ID: $deviceId ($deviceName)" -ForegroundColor Green
                Write-Log "Successo: Utente $userUPN rimosso dal dispositivo ID: $deviceId ($deviceName)"

                # Aggiungi i dati per l'esportazione in CSV
                $removedUsers += [PSCustomObject]@{
                    DeviceID = $deviceId
                    DeviceName = $deviceName
                    UserPrincipalName = $userUPN
                }

            } catch {
                Write-Host ("Errore nella rimozione dell'utente per il dispositivo {0}: {1}" -f $deviceId, $_) -ForegroundColor Red
                Write-Log "Errore: Impossibile rimuovere l'utente $userUPN dal dispositivo ID: $deviceId ($deviceName) - $_"
            }
        }

        # Esporta i dati raccolti in CSV per il ripristino
        if ($removedUsers.Count -gt 0) {
            $removedUsers | Export-Csv -Path $csvPath -NoTypeInformation -Delimiter ','
            Write-Host "Backup CSV salvato in: $csvPath" -ForegroundColor Cyan
            Write-Log "Backup CSV salvato in: $csvPath"
        }

    } else {
        Write-Host "Nessun dispositivo trovato con UPN impostato" -ForegroundColor Yellow
        Write-Log "Nessun dispositivo trovato con UPN impostato."
    }
} catch {
    Write-Host "Errore durante il recupero dei dispositivi: $_" -ForegroundColor Red
    Write-Log "Errore durante il recupero dei dispositivi: $_"
}

# Disconnessione
disconnect-MgGraph
Write-Host "Disconnessione completata" -ForegroundColor Cyan
Write-Log "Disconnessione completata."