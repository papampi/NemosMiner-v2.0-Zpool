. .\Include.ps1

$retries=1
do {
try {
$Zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/status"
-UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
#$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json
}
catch {}
$retries++
} while ($Zpool_Request -eq $null -and $retries -le 5)
if ($retries -gt 5) {
WRITE-HOST 'ZPOOL API NOT RESPONDING...ABORTING'
EXIT
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Location = "US"

$Zpool_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Zpool_Host = "mine.zpool.ca"
    $Zpool_Port = $Zpool_Request.$_.port
    $Zpool_Algorithm = Get-Algorithm $Zpool_Request.$_.name
    $Zpool_Coin = ""

    $Divisor = 1000000
	
    switch ($Zpool_Algorithm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current / $Divisor)}
	
    if ($Wallet) {
        [PSCustomObject]@{
            Algorithm     = $Zpool_Algorithm
            Info          = $Zpool_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Zpool_Host
            Port          = $Zpool_Port
            User          = $Wallet
            Pass          = "$WorkerName,c=BTC,stats"
            Location      = $Location
            SSL           = $false
        }
    }
}
