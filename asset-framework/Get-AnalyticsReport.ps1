# Provide the input file path (xml), and output file path (csv)
param(
    [string]$InputXmlPath = ".\home.xml",
    [string]$OutputCsvPath = ".\home.csv",
    [string]$AnalysisPerformanceCsvPath = ".\Performance_analyses.csv",
    [string]$GroupPerformanceCsvPath = ".\Performance_groups.csv"
)

# Define which functions are considered expensive: summary functions
$expensiveFunctions = @(
    "FilterData", "Mapdata", 
    "FindEq", "FindGE", "FindGT", "FindLE", "FindLT", "FindNE"
    "NumOfChanges",
    "InterpolatedValues", "RecordedValues", "RecordedValuesByCount"
    "TimeEq", "TimeGE", "TimeGT", "TImeLE", "TimeLT", "TimeNE"
    "TagMax", "TagMin", "TagAvg", "TagMean", "TagTot", "Median", "StDev", "LinRegr")

function Get-ElementPath {
    # return the AF path for an element

    param (
        $elementNode
    )

    $elePath = ""
    $thisNode = $elementNode

    While ($thisNode -and $thisNode.ParentNode.Name -ne "#document") {

        if ($elePath.Length -gt 0) {
            $elePath = "\" + $elePath
        }

        $elePath = $thisNode.Name + $elePath
        $thisNode = $thisNode.ParentNode
    }

    return $elePath

}

function Get-ElementFromPath {
    param (
        $elementNode,
        [string]$elementPath
    )

    $AF = $xml.FirstChild.NextSibling

    $PISystem = $AF.PISystem
    $Database = $AF.Database

    $localDB = "\\" + $PISystem + "\" + $Database

    $foundElement = $null

    $tmpPath = $elementPath

    if ($tmpPath.Contains("|")) {
        # remove attributes from path
        $tmpPath = $tmpPath.Split("|")[0]
    }
    
    if ($tmpPath.StartsWith($localDB)) {
        # absolute path in this database
        $tmpPath = $tmpPath.Replace($localDB, "")
    }

    if ($tmpPath.StartsWith("\\")) {
        # cannot resolve, outside of database
    }
    else {
        if ($tmpPath.StartsWith("\")) {
            # absolute path, start at root
            
            foreach ($element in $tmpPath.Split("\")) {
                if ($element) {
                    
                    if ($foundElement) {
                        $foundElement = $foundElement.SelectSingleNode("AFElement[Name='$($element)']")
                    }
                    else {
                        $foundElement = $xml.SelectSingleNode("//AFElement[Name='$($element)']")
                    }
                }
            }
        }
        else {
            # relative path, start in current element node

            foreach ($element in $tmpPath.Split("\")) {
                if ($element) {
                    if ($foundElement) {
                        if ($element -eq "..") {
                            $foundElement = $foundElement.ParentNode
                        }
                        elseif ($element -eq ".") {
                            # this element
                        }
                        else {
                            $foundElement = $foundElement.SelectSingleNode("AFElement[Name='$($element)']")
                        }
                    }
                    else {
                        if ($element -eq "..") {
                            $foundElement = $elementNode.ParentNode
                        }
                        elseif ($element -eq ".") {
                            # this element
                        }
                        else {
                            $foundElement = $elementNode.SelectSingleNode("AFElement[Name='$($element)']")
                        }
                    }
                }
            }
        }
    }

    return $foundElement
}

function Get-AttributeFromPath {
    param (
        $elementNode,
        [string]$attributePath
    )
   
    $foundAttribute = $null

    if ($attributePath.Contains("\")) {
        $elementNode = Get-ElementFromPath $elementNode $attributePath
        $attributePath = $attributePath.Replace($attributePath.Split("|")[0], "")
    }

    if ($attributePath.Contains("|")) {
        # is a subattribute

        foreach ($subAttribute in $attributePath.Split("|")) {
            if ($subAttribute) {
                if ($foundAttribute) {
                    if ($subAttribute -eq "..") {
                        $foundAttribute = $foundAttribute.ParentNode
                    }
                    elseif ($subAttribute -eq ".") {
                        # this attribute                           
                    }
                    else {
                        $foundAttribute = $foundAttribute.SelectSingleNode("AFAttribute[Name='$($subAttribute)']")
                    }
                }
                else {
                    if ($subAttribute -eq "..") {
                        $foundAttribute = $foundAttribute.ParentNode
                    }
                    elseif ($subAttribute -eq ".") {
                        # this attribute      
                    }
                    else {
                        $foundAttribute = $elementNode.SelectSingleNode("AFAttribute[Name='$($subAttribute)']")
                    }
                }
            }
        }
        
    }
    else {
        # is an attribute
        $foundAttribute = $elementNode.SelectSingleNode("AFAttribute[Name='$($attributePath)']")
    }

    return $foundAttribute
}

function Get-FunctionKpis {
    param (
        [string[]]$Expressions,                  # Array of strings containing code
        [string[]]$ExpensiveFunctions = @()      # List of expensive function names
    )

    # Regex to capture FunctionName(args)
    $regex = '\b(?<Name>[A-Za-z_]\w*)\s*\((?<Args>[^\)]*)\)'

    $matches = foreach ($expr in $Expressions) {
        [regex]::Matches($expr, $regex) | ForEach-Object {
            @{
                Name = $_.Groups['Name'].Value
                Args = $_.Groups['Args'].Value.Trim()
                Full = "$($_.Groups['Name'].Value)($($_.Groups['Args'].Value.Trim()))"
            }
        }
    }

    # All function calls
    $allCalls = $matches.Full

    # KPI calculations
    $TotalFunctionCalls = $allCalls.Count
    $DuplicateFunctionCalls = ($allCalls | Group-Object | Where-Object { $_.Count -gt 1 }).Count
    $expensiveCalls = $matches | Where-Object { $ExpensiveFunctions -contains $_.Name }
    $ExpensiveFunctionCalls = $expensiveCalls.Count
    $DuplicateExpensiveCalls = ($expensiveCalls.Full | Group-Object | Where-Object { $_.Count -gt 1 }).Count

    # Return a hashtable with all metrics
    return @{
        TotalFunctionCalls      = $TotalFunctionCalls
        DuplicateFunctionCalls  = $DuplicateFunctionCalls
        ExpensiveFunctionCalls  = $ExpensiveFunctionCalls
        DuplicateExpensiveCalls = $DuplicateExpensiveCalls
    }
}

function Get-AnalysisInfo {
    param(
        [Parameter(Mandatory = $true)]
        $analysis,
        $element,
        $expensiveFunctions
    )

    # Initialize
    $result = @{
        AnalysisType                = ""
        Schedule                    = ""
        Triggers                    = ""
        TriggerCount                = ""
        Frequency                   = ""
        Offset                      = ""
        InputCount                  = 0
        NoneDR                      = 0
        FormulaDR                   = 0
        PIPointDR                   = 0
        PIPointArrayDR              = 0
        StringBuilderDR             = 0
        TableLookupDR               = 0
        URIBuilderDR                = 0
        ExpensiveCount              = 0
        DuplicateCount              = 0
        TotalFunctions              = 0
        DuplicateFunctions          = 0
        ExpensiveFunctions          = 0
        DuplicateExpensiveFunctions = 0
    }

    # Does this analysis have its own definition
    if ($analysis.AFAnalysisRule) {

        $result.AnalysisType = $analysis.AFAnalysisRule.AFPlugIn

        Switch ($result.Analysistype) {

            "PerformanceEquation" {
                $variables = $analysis.AFAnalysisRule.ConfigString.Split(";")

                $functionKpis = (Get-FunctionKpis -Expressions $variables -ExpensiveFunctions $expensiveFunctions)

                $inputAttributes = [regex]::Matches($variables, "'([^']+)'")
                
                $attributes = @()


                foreach ($inputAttribute in $inputAttributes) {
                    $attributeName = $inputAttribute.Value.Replace("'", "") # strip single quotes
                    $attribute = Get-AttributeFromPath $element $attributeName

                    if ($attribute -and $attributes -notcontains $attribute) {
                        $attributes += $attribute

                        switch ($attribute.DataReference) {
                            '' { $result.NoneDR++ }
                            'Formula' { 
                                $result.FormulaDR++ 
                            
                                $formula = $attribute.ConfigString

                                foreach ($finput in $formula.split(';')) {
                                    if ($finput.Contains("=")) {
                                        $fattribute = Get-AttributeFromPath $element $finput.Split("=")[1]

                                        if ($fattribute -and $attributes -notcontains $fattribute) {
                                            $attributes += $fattribute

                                            switch ($fattribute.DataReference) {
                                                '' { $result.NoneDR++ }
                                                'Formula' { $result.FormulaDR++ }
                                                'PI Point' { $result.PIPointDR++ }
                                                'PI Point Array' { $result.PIPointArrayDR++ }
                                                'String Builder' { $result.StringBuilderDR++ }
                                                'Table Lookup' { $result.PIPointDR++ }
                                                'URI Builder' { $result.URIBuilderDR++ }
                                            }
                                        }
                                    }
                                }
                            
                            }
                            'PI Point' { $result.PIPointDR++ }
                            'PI Point Array' { $result.PIPointArrayDR++ }
                            'String Builder' { $result.StringBuilderDR++ }
                            'Table Lookup' { $result.TableLookupDR++ }
                            'URI Builder' { $result.URIBuilderDR++ }
                        }
                    }
                }

                $result.InputCount = $attributes.Count

                if ($functionKpis) {
                    $result.TotalFunctions = $functionKpis.TotalFunctionCalls
                    $result.DuplicateFunctions = $functionKpis.DuplicateFunctionCalls 
                    $result.ExpensiveFunctions = $functionKpis.ExpensiveFunctionCalls 
                    $result.DuplicateExpensiveFunctions = $functionKpis.DuplicateExpensiveCalls 
                }

            }
            "Rollup" {}
            "EventFrame" {}
            "SQC" {}
        }

        # Schedule details
        $result.Schedule = $analysis.AFTimeRule.AFPlugIn

        if ($result.Schedule -eq "Natural") {
            $result.Triggers = $analysis.AFTimeRule.ConfigString

            if ($result.Triggers) {
                $result.TriggerCount = $result.Triggers.Split(";").Count
            }
            else {
                $result.TriggerCount = $result.InputCount
            }
        }
        elseif ($result.Schedule -eq "Periodic") {
            $timeRule = $analysis.AFTimeRule.ConfigString

            if ($timeRule.Contains(";")) {
                $result.Offset = $timeRule.Split(";")[0]
                $result.Frequency = $timeRule.Split(";")[1]
            }
            else {
                $result.Frequency = $timeRule
            }

            if ($result.Frequency.Contains("=")) {
                $result.Frequency = $result.Frequency.split("=")[1]
            }

            if ($result.Offset.Contains("=")) {
                $result.Offset = $result.Offset.split("=")[1]
            }
            else {
                $result.Offset = 0
            }
        }        
    }
    return $result
}

[xml]$xml = Get-Content $InputXmlPath

if ($AnalysisPerformanceCsvPath) {
    $analysisPerformanceData = Import-CSV -Path $AnalysisPerformanceCsvPath
}
else {
    $analysisPerformanceData = $null
}

if ($GroupPerformanceCsvPath) {
    $groupPerformanceData = Import-Csv -Path $GroupPerformanceCsvPath
}
else {
    $groupPerformanceData = $null
}

$rows = @()

# Find all the AF Analysis nodes
$analyses = $xml.SelectNodes("//AFAnalysis")

$PISystem = $xml.SelectSingleNode("AF").PISystem
$Database = $xml.SelectSingleNode("AF").Database

Write-Output "Processing Server '$($PIsystem), Asset Framework database '$($Database)', containing $($analyses.Count) analyses"

foreach ($analysis in $analyses) {

    # Identify the element
    $element = $analysis.ParentNode
    $elementPath = Get-ElementPath($element)

    
    $elementinfo = $null
    $templateInfo = $null

    $elementInfo = Get-AnalysisInfo -analysis $analysis -element $element -expensiveFunctions $expensiveFunctions

    # Is the element templated?
    if ($element.Template) {
        $elementTemplate = $xml.SelectSingleNode("//AFElementTemplate[Name='$($element.Template)']")

        if ($elementTemplate) {
            $analysisTemplate = $elementTemplate.SelectSingleNode("//AFAnalysisTemplate[Name='$($analysis.Name)']")
            $templateInfo = Get-AnalysisInfo -analysis $analysisTemplate -element $element -expensiveFunctions $expensiveFunctions
        }    
        else {
            $analysisTemplate = $null
        }
    }
    else {
        $elementTemplate = $null
    }

    # reset data
    $row = $null

    if ($groupPerformanceData) {
        $pattern = [regex]::Escape("\$PISystem\$Database\ElementTemplates[$($element.Template)]|$($analysis.Name)")
        $groupRow = $groupPerformanceData | Where-Object { $_.TemplatePath -match $pattern } | Select-Object -First 1
    }
    else {
        $groupRow = $null
    }

    if ($analysisPerformanceData) {
        # escape values for regex
        $escapedElement = [regex]::Escape($elementPath)
        $escapedAnalysis = [regex]::Escape($analysis.Name)

        # build regex pattern: start with \\server\ then element path, then Analyses[analysisName]
        $pattern = '^\\\\[^\\]+\\' + $escapedElement + '\\Analyses\[' + $escapedAnalysis + '\]$'

        # find first matching row
        $analysisRow = $analysisPerformanceData | Where-Object { $_.Path -match $pattern } | Select-Object -First 1
    }
    else {
        $analysisRow = $null
    }

    # from database, analysis information
    $row = [pscustomobject]@{
        "Database"                        = $Database
        "Analysis"                        = $analysis.Name
        "Element"                         = $element.Name
        "ElementPath"                     = $elementPath
        "ElementTemplate"                 = $elementTemplate.Name
        "AnalysisType"                    = if ($element.Template) { $templateInfo.analysisType } else { $elementInfo.analysisType }
        "ScheduleOrgin"                   = if ($elementInfo.Schedule) { "Element" } else { "Template" }
        "ScheduleType"                    = if ($elementInfo.Schedule) { $elementInfo.Schedule } else { $templateInfo.Schedule }
        "Triggers"                        = if ($elementInfo.TriggerCount) { $elementInfo.TriggerCount } else { $templateInfo.TriggerCount }
        "Frequency"                       = if ($elementInfo.Frequency) { $elementInfo.Frequency } else { $templateInfo.Frequency }
        "Offset"                          = if ($elementInfo.Offset) { $elementInfo.Offset } else { $templateInfo.Offset }
        "InputAttributes"                 = if ($element.Template) { $templateInfo.InputCount } else { $elementInfo.InputCount }
        "NoneDataReferenceCount"          = if ($element.Template) { $templateInfo.NoneDR } else { $elementInfo.NoneDR }
        "FormulaDataReferenceCount"       = if ($element.Template) { $templateInfo.FormulaDR } else { $elementInfo.FormulaDR }
        "PIPointDataReferenceCount"       = if ($element.Template) { $templateInfo.PIPointDR } else { $elementInfo.PIPointDR }
        "PIPointArrayDataReferenceCount"  = if ($element.Template) { $templateInfo.PIPointArrayDR } else { $elementInfo.PIPointArrayDR }
        "StringBuilderDataReferenceCount" = if ($element.Template) { $templateInfo.StringBuilderDR } else { $elementInfo.StringBuilderDR }
        "TableLookupDataReferenceCount"   = if ($element.Template) { $templateInfo.TableLookupDR } else { $elementInfo.TableLookupDR }
        "URIBuilderDataReferenceCount"    = if ($element.Template) { $templateInfo.URIBuilderDR } else { $elementInfo.URIBuilderDR }
        "FunctionCallCount"               = if ($element.Template) { $templateInfo.TotalFunctions } else { $elementInfo.TotalFunctions }
        "ExpensiveFunctionCallCount"      = if ($element.Template) { $templateInfo.ExpensiveFunctions } else { $elementInfo.ExpensiveFunctions }
        "DuplicateFunctions"              = if ($element.Template) { $templateInfo.DuplicateFunctions } else { $elementInfo.DuplicateFunctions }
        "DuplicateAndExpensiveFunctions"  = if ($element.Template) { $templateInfo.DuplicateExpensiveFunctions } else { $elementInfo.DuplicateExpensiveFunctions }
        "GroupAverageElapsed"             = if ($groupRow) { $groupRow.AverageElapsed } else { "" }
        "GroupAverageTrigger"             = if ($groupRow) { $groupRow.AverageTrigger } else { "" }
        "GroupAverageAnalysisCount"       = if ($groupRow) { $groupRow.AverageAnalysisCount } else { "" }
        "GroupImpactScore"                = if ($groupRow) { $groupRow.ImpactScore } else { "" }
        "AnalysisAverageElapsed"          = if ($analysisRow) { $analysisRow.AverageElapsed } else { "" }
        "AnalysisAverageTrigger"          = if ($analysisRow) { $analysisRow.AverageTrigger } else { "" }
        "AnalysisTriggerRatio"            = if ($analysisRow) { $analysisRow.TriggerRatio } else { "" }
    }
 
    $rows += $row
}

$rows | Export-Csv -NoTypeInformation -Path $OutputCsvPath -Encoding UTF8