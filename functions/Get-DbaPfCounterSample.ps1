﻿function Get-DbaPfCounterSample {
    <#
        .SYNOPSIS
            Gets Peformance Monitor Counter Sample

        .DESCRIPTION
            Gets Peformance Monitor Counter Sample

        .PARAMETER ComputerName
            The target computer. Defaults to localhost.

        .PARAMETER Credential
            Allows you to login to $ComputerName using alternative credentials.

        .PARAMETER CollectorSet
            The Collector Set name
  
        .PARAMETER Collector
            The Collector name
    
        .PARAMETER Counter
            The Counter name - in the form of '\Processor(_Total)\% Processor Time'

        .PARAMETER Continuous
        Gets samples continuously until you press CTRL+C. By default, this command gets only one counter sample. You can use the SampleInterval parameter to set the interval for continuous sampling.
        
        .PARAMETER ListSet
        Gets the specified performance counter sets on the computers. Enter the names of the counter sets. Wildcards are permitted. 
    
        .PARAMETER MaxSamples
        Specifies the number of samples to get from each counter. The default is 1 sample. To get samples continuously (no maximum sample size), use the Continuous parameter.

        To collect a very large data set, consider running a Get-DbaPfCounterSample command as a Windows PowerShell background job. 
    
        .PARAMETER SampleInterval
        Specifies the time between samples in seconds. The minimum value and the default value are 1 second.
    
        .PARAMETER InputObject
            Enables piped results from Get-DbaPfDataCollectorSet

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
    
        .NOTES
            Tags: PerfMon

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
    
        .LINK
            https://dbatools.io/Get-DbaPfCounterSample

        .EXAMPLE
            Get-DbaPfCounterSample
    
            Gets all counters for all collector sets on localhost

        .EXAMPLE
            Get-DbaPfCounterSample -ComputerName sql2017
    
             Gets all counters for all collector sets on  on sql2017
    
        .EXAMPLE
            Get-DbaPfCounterSample -ComputerName sql2017, sql2016 -Credential (Get-Credential) -CollectorSet 'System Correlation'
    
            Gets all counters for 'System Correlation' Collector on sql2017 and sql2016 using alternative credentials
    
        .EXAMPLE
            Get-DbaPfDataCollectorSet -CollectorSet 'System Correlation' | Get-DbaPfDataCollector | Get-DbaPfCounterSample
    
            Gets all counters for 'System Correlation' Collector
    #>
    [CmdletBinding()]
    param (
        [DbaInstance[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [string[]]$CollectorSet,
        [string[]]$Collector,
        [string[]]$Counter,
        [switch]$Continuous,
        [switch[]]$ListSet,
        [int]$MaxSamples,
        [int]$SampleInterval,
        [parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [switch]$EnableException
    )
    begin {
        $columns = 'ComputerName', 'Name', 'DataCollectorSet', 'Counters', 'DataCollectorType', 'DataSourceName', 'FileName', 'FileNameFormat', 'FileNameFormatPattern', 'LatestOutputLocation', 'LogAppend', 'LogCircular', 'LogFileFormat', 'LogOverwrite', 'SampleInterval', 'SegmentMaxRecords'
    }
    process {
        if ($InputObject.Credential -and (Test-Bound -ParameterName Credential -Not)) {
            $Credential = $InputObject.Credential
        }
        
        if ($InputObject.Counter -and (Test-Bound -ParameterName Counter -Not)) {
            $Counter = $InputObject.Counter
        }
        
        if (-not $InputObject -or ($InputObject -and (Test-Bound -ParameterName ComputerName))) {
            foreach ($computer in $ComputerName) {
                $InputObject += Get-DbaPfCounter -ComputerName $computer -Credential $Credential -CollectorSet $CollectorSet -Collector $Collector
            }
        }
        
        if ($InputObject) {
            if (-not $InputObject.DataCollectorSetObject) {
                Stop-Function -Message "InputObject is not of the right type. Please use Get-DbaPfCounter"
                return
            }
        }
        
        foreach ($counterobject in $InputObject) {
            if ($Counter -and $Counter -notcontains $counterobject.Name) { continue }
            
            $params = @{
                ComputerName           = $counterobject.ComputerName
                Counter                = $counterobject.Name
            }
            
            if ($Credential) {
                $params.Add("Credential", $Credential)
            }
            
            if ($Continuous) {
                $params.Add("Continuous", $Continuous)
            }
            
            if ($ListSet) {
                $params.Add("ListSet", $ListSet)
            }
            
            if ($MaxSamples) {
                $params.Add("MaxSamples", $MaxSamples)
            }
            
            if ($SampleInterval) {
                $params.Add("SampleInterval", $SampleInterval)
            }
            
            if ($Continuous) {
                Get-Counter @params
            }
            else {
                $pscounters = Get-Counter @params
                
                foreach ($pscounter in $pscounters) {
                    foreach ($sample in $pscounter.CounterSamples) {
                        [pscustomobject]@{
                            ComputerName                          = $counterobject.ComputerName
                            DataCollectorSet                      = $counterobject.DataCollectorSet
                            DataCollector                         = $counterobject.DataCollector
                            Name                                  = $counterobject.Name
                            Timestamp                             = $pscounter.Timestamp
                            Path                                  = $sample.Path
                            InstanceName                          = $sample.InstanceName
                            CookedValue                           = $sample.CookedValue
                            RawValue                              = $sample.RawValue
                            SecondValue                           = $sample.SecondValue
                            MultipleCount                         = $sample.MultipleCount
                            CounterType                           = $sample.CounterType
                            SampleTimestamp                       = $sample.Timestamp
                            SampleTimestamp100NSec                = $sample.Timestamp100NSec
                            Status                                = $sample.Status
                            DefaultScale                          = $sample.DefaultScale
                            TimeBase                              = $sample.TimeBase
                            Sample                                = $pscounter.CounterSamples
                            DataCollectorSetObject                = $counterobject.DataCollectorSetObject
                        } | Select-DefaultView -ExcludeProperty Sample, DataCollectorSetObject
                    }
                }
            }
        }
    }
}