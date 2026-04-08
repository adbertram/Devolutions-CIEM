function InvokeCIEMBatchInsert {
    <#
    .SYNOPSIS
        Performs a multi-row INSERT OR REPLACE batch insert against a SQLite table.

    .DESCRIPTION
        Shared helper used by Save-CIEMAzure* functions to consolidate the batch
        insert pattern in one place. Computes a safe per-statement chunk size from
        the column count to stay under SQLite's 999 SQL parameter cap. Each chunk
        is sent as one parameterized multi-row INSERT.

        Routes to Invoke-PSUSQLiteQuery when an explicit -Connection is supplied
        (for transactional contexts) or to Invoke-CIEMQuery otherwise.

    .PARAMETER Table
        Target table name.

    .PARAMETER Columns
        Ordered list of column names. The order MUST match the order of properties
        on each item — items[i].(propertyForColumn[j]) is read by case-insensitive
        property name lookup, where the property name is derived from the column
        name converted from snake_case to PascalCase.

    .PARAMETER Items
        Hashtable or PSCustomObject items to insert.

    .PARAMETER Connection
        Optional SqliteConnection. When supplied, the call is routed through
        Invoke-PSUSQLiteQuery so it joins an outer transaction.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Table,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Columns,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return
    }

    # SQLite SQLITE_MAX_VARIABLE_NUMBER is 999 in older builds. Stay under this hard
    # cap by computing the maximum rows per statement from the column count.
    $columnCount = $Columns.Count
    if ($columnCount -le 0) {
        throw 'InvokeCIEMBatchInsert requires at least one column.'
    }

    $maxParamCap = 999
    $maxRowsByParamCap = [Math]::Max(1, [Math]::Floor($maxParamCap / $columnCount))
    $configuredBatchSize = if ($script:CIEMSqlBatchSize -and $script:CIEMSqlBatchSize -gt 0) {
        $script:CIEMSqlBatchSize
    }
    else {
        $maxRowsByParamCap
    }
    $rowsPerChunk = [Math]::Min($maxRowsByParamCap, $configuredBatchSize)

    # Build the property name list once. Convert snake_case column to PascalCase.
    $propertyNames = foreach ($column in $Columns) {
        ($column -split '_' | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) } else { '' }
        }) -join ''
    }

    $columnList = $Columns -join ', '

    # Unified property lookup for both hashtables and objects with a real property bag.
    # BCL primitives (int, string, etc.) do have a PSObject wrapper but no matching
    # Id/Name properties, so the lookup returns nothing — that's a fail-fast case, not
    # a silent NULL insert.
    $getItemValue = {
        param($Item, $PropertyName, $ColumnName)

        if ($null -eq $Item) {
            throw "InvokeCIEMBatchInsert: items must not be null."
        }

        if ($Item -is [System.Collections.IDictionary]) {
            if ($Item.Contains($PropertyName)) { return $Item[$PropertyName] }
            if ($Item.Contains($ColumnName)) { return $Item[$ColumnName] }
            return $null
        }

        $properties = $Item.PSObject.Properties
        $match = $properties[$PropertyName]
        if ($match) { return $match.Value }
        $match = $properties[$ColumnName]
        if ($match) { return $match.Value }

        # Reject BCL primitives and other objects that don't expose any of our columns.
        # A real data object would always have at least one matching property.
        $hasAnyExpectedProperty = $false
        foreach ($p in $propertyNames) {
            if ($properties[$p]) { $hasAnyExpectedProperty = $true; break }
        }
        if (-not $hasAnyExpectedProperty) {
            foreach ($c in $Columns) {
                if ($properties[$c]) { $hasAnyExpectedProperty = $true; break }
            }
        }
        if (-not $hasAnyExpectedProperty) {
            throw "InvokeCIEMBatchInsert: unsupported item type '$($Item.GetType().FullName)' — expected [hashtable] or an object with one of these properties: $($propertyNames -join ', ')."
        }

        $null
    }

    for ($offset = 0; $offset -lt $Items.Count; $offset += $rowsPerChunk) {
        $remaining = $Items.Count - $offset
        $chunkSize = [Math]::Min($rowsPerChunk, $remaining)

        $rows = [System.Collections.Generic.List[string]]::new($chunkSize)
        $parameters = [ordered]@{}

        for ($rowIndex = 0; $rowIndex -lt $chunkSize; $rowIndex++) {
            $item = $Items[$offset + $rowIndex]
            $suffix = $rowIndex + 1

            $placeholders = [System.Collections.Generic.List[string]]::new($columnCount)
            for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
                $columnName = $Columns[$columnIndex]
                $propertyName = $propertyNames[$columnIndex]
                $paramName = "${columnName}_${suffix}"

                $value = & $getItemValue $item $propertyName $columnName

                $parameters[$paramName] = $value
                $placeholders.Add("@${paramName}")
            }

            $rows.Add('(' + ($placeholders -join ', ') + ')')
        }

        $sql = "INSERT OR REPLACE INTO $Table ($columnList) VALUES " + ($rows -join ', ')

        if ($Connection) {
            Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
        else {
            Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
    }
}
