# Ensure Windows PowerShell 5.1 is used
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    Write-Error "This script requires Windows PowerShell 5.1. Please run it in Windows PowerShell, not PowerShell Core."
    exit 1
}


# generated categories:
# (recently = in the last $STALE_DAYS days)
#   New: PI Point has no good data, but was created recently
#   Empty: PI Point has no good data ever
#   Stale: PI Point has no good data recently
#   TO BE IMPLIMENTED -- Flat: PI Point has good data, but it does not change 
#   Good: PI Point has good data recently

# Load AFSDK  
$AFSDK = [Reflection.Assembly]::LoadWithPartialName("OSIsoft.AFSDK")

# to analyse subsets of tags, enter search criteria in $SEARCH_CRITERIA.
# see https://docs.aveva.com/bundle/af-sdk/page/html/pipoint-query-syntax-overview.htm
# some examples search criteria

$SEARCH_CRITERIA = "*" # << all PI tags
# $SEARCH_CRITERIA = "PointSource:L" # << lab (L) PI tags
# $SEARCH_CRITERIA = "PointSource:<>L" # << point source is not lab (L)
# $SEARCH_CRITERIA = "PointType:Float32" # << float32 PI tags
# $SEARCH_CRITERIA = "sin*" # << PI tags that start with "sin"
# $SEARCH_CRITERIA = "PointSource:<>[*]"

$STALE_DAYS = 90        # number of days a tag does not have good data for before it is considered stale,
# or if the tag was created within this number of days it is considered new

$INCLUDE_GOOD = $true   # include good tags in the output, is useful for full tag analysis

$OUTPUT_FILE = "PIPointAnalysis.csv"


function Get-IsGood {
    param (
        $pivalue
    )

    # Get-IsGood returns False when the value is Shutdown or Scan Off
    # pass a PIValue object
    # will return a boolean; true = good, false = bad

    if (($pivalue.value -eq "Shutdown") -or ($pivalue.value -eq "Scan Off") -or ($null -eq $pivalue.value)) {
        return $false
    }
    else {
        return $pivalue.IsGood
    }
}

function Get-LastGoodValue {
    param (
        $pitag,
        $future = $false
    )

    # return the latest good pi value

    # pass in a PIPoint object
    # return a PIValue object, or null of there is no good data

    $snapshot = $pitag.CurrentValue()

    if (Get-IsGood($snapshot) -eq $true) {
        # snapshot is good, return that and do no more    
        return $snapshot
    }
    else {
        # otherwise we need to search back in time to find the last good value
        $tag = $pitag.Name

        # start now, look for one value, work backwards from now
        $startTime = (Get-Date)
        $count = 1
        $boundaryType = [OSIsoft.AF.Data.AFBoundaryType]::Inside

        # filter data that is bad or shutdown/scan off
        $filterExpression = "NOT ((BadVal('" + $tag + "'))" +
        " OR ('" + $tag + "' = ""Shutdown"")" +
        " OR ('" + $tag + "' = ""Scan Off""))"
        
        $includeFilteredValues = $false
        
        # perform the search
        $pivalues = $pitag.RecordedValuesByCount($startTime, $count, $future, $boundaryType, $filterExpression, $includeFilteredValues)

        if ($null -ne $piValues) {
            # found a good value
            if ($pivalues.count -gt 0) {
                return $pivalues[0]
            }
            else {
                # found no good value
                return $null
            }    
        }
    }
}

# PI Data Archive, connect to default PI Server
$piServers = New-Object OSIsoft.AF.PI.PIServers
$piServer = $piServers.DefaultPIServer

# get PI Points
$piPoints = @([OSIsoft.AF.PI.PIPoint]::FindPIPoints($piServer, $SEARCH_CRITERIA, $null, $null))

# CSV header
$results = @()
$results += "Name;ObjectType;pointtype;archiving;future;pointsource;scan;creationdate;changedate;lastgoodvalue;lastgoodtimestamp;agedays;category"


$count = 0
$total = $piPoints.Count

# check each PI Point
foreach ($piPoint in $piPoints) {
    $count++
    Write-Progress -Activity "Analyzing PI Points" -Status "$count of $total processed" -PercentComplete ([math]::Round(($count / $total) * 100))

    # get attributes
    $piPoint.LoadAttributes()
    $pointType = $piPoint.GetAttribute("pointtype")
    $archiving = $piPoint.GetAttribute("archiving")
    $future = $piPoint.GetAttribute("future")
    $pointSource = $piPoint.GetAttribute("pointsource")
    $scan = $piPoint.GetAttribute("scan")
    $creationDate =  ([datetime]$piPoint.GetAttribute("creationdate"))
    $changeDate = ([datetime]$piPoint.GetAttribute("changedate"))

    if ($archiving -eq 1) {
        # find the last good value in the PI Point
        if ($future -eq 0) {
            $lastGoodValue = Get-LastGoodValue -pitag $piPoint
        }
        else {
            $lastGoodValue = Get-LastGoodValue -pitag $piPoint -future $true
        }
    }
    else {
        # no archiving, only the snapshot is of interest
        $snapshot = $piPoint.CurrentValue()

        if (Get-IsGood($snapshot) -eq $true) {
            # snapshot is good, return that and do no more    
            $lastGoodValue = $snapshot
        }
        else {
            $lastGoodValue = $null
        }
    }

    if ($null -eq $lastGoodValue) {
        # there is no good value
        $timestamp = ""
        $category = "Empty"
        $ageDays = 0
    }
    else {   
        # timestamp for the last good value
        $timestamp = $lastGoodValue.Timestamp

        $age = (New-TimeSpan -Start $timestamp -End (Get-Date))
        $ageDays = $age.TotalDays

        # the last good value is old
        if ($ageDays -gt $STALE_DAYS) {
            $category = "Stale"
        }
        else {
            $category = "Good"
        }
    }

    # summary for output
    if (($category -ne "Good") -or ($INCLUDE_GOOD -eq $true)) {
        
        if ($category -eq "Empty") {
            # no data, check if tag is created "recently"
            $age = (New-TimeSpan -Start $creationDate -End (Get-Date))
            $ageDays = $age.TotalDays

            if ($ageDays -lt $STALE_DAYS) {
                $category = "New"
            }
        }

        $value = $lastGoodValue.Value

        # output
        if ($null -eq $value) {
            $value = ""
        }
        else {
            # watch out for new lines
            $value = '"' + ($lastGoodValue.Value.ToString() -replace "`r?`n", " " -replace '"', '""') + '"'
        }

        $creationDateUTC = $creationDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $changeDateUTC = $changeDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        $timestampUTC = $null

        if ($null -ne $timestamp -and $timestamp -ne "") {
            $timestampUTC = $timestamp.UtcTime.ToString("yyyy-MM-ddTHH:mm:ssZ")  
        }

        $line = "$($piPoint.Name);PIPoint;$pointType;$archiving;$future;$pointSource;$scan;$creationDateUTC;$changeDateUTC;$value;$timestampUTC;$ageDays;$category"
        $results += $line
    }
}

# Write results to CSV
$results | Out-File -FilePath $OUTPUT_FILE -Encoding UTF8

Write-Host "PI Point analysis complete. Output written to $outputFile"
