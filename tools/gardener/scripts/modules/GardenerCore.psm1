function Get-Field-Value {
    param($yaml, $name)
    if (-not $yaml) { return "" }
    
    $triplePattern = "(?smi)^" + [regex]::Escape($name) + ":\s*'''(.*?)'''"
    if ($yaml -match $triplePattern) { return $Matches[1].Trim() }

    $pattern = "(?mi)^" + [regex]::Escape($name) + ':\s*(?:["'']?)([^#\r\n]*?)(?:["'']?)\s*(?:#.*)?$'
    if ($yaml -match $pattern) {
        $ms = [regex]::Matches($yaml, $pattern)
        if ($ms.Count -gt 0) {
            $v = $ms[$ms.Count - 1].Groups[1].Value.Trim().Trim('"').Trim("'")
            if ($v -eq "-") { return "" }
            return $v
        }
    }
    return ""
}

function Update-Yaml-String {
    param($yaml, $name, $value)
    $vStr = if ($value -match "[\r\n]" -or $value -match '["'']') {
        "'''`n${value}`n'''" 
    } else {
        "`"${value}`""
    }
    $lines = $yaml -split "`r?`n"
    $found = $false
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^(?i)" + [regex]::Escape($name) + ":")) {
            $origName = $lines[$i] -replace "^([^:]+):.*$", '$1'
            $lines[$i] = "${origName}: ${vStr}"
            $found = $true
        }
    }
    if ($found) { return $lines -join "`r`n" }
    return ($yaml.TrimEnd() + "`r`n${name}: ${vStr}")
}

Export-ModuleMember -Function Get-Field-Value, Update-Yaml-String
