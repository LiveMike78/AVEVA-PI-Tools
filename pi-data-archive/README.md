# PI Data Archive Scripts

PowerShell scripts for administering and analysing the AVEVA PI Data Archive.

---

## Get-PIPointAnalysis.ps1

Connects to the default PI Data Archive server and analyses every PI Point (or a filtered subset), then outputs a CSV report categorising each tag based on its data health.

### Categories

| Category | Description |
|----------|-------------|
| `Good`   | Tag has good data within the configured staleness window |
| `Stale`  | Tag has good data, but none within the staleness window |
| `New`    | Tag has no good data, but was created recently (within the staleness window) |
| `Empty`  | Tag has never had good data and is not new |

> **Note:** A `Flat` category (tag value never changes) is planned but not yet implemented.

### Requirements

- **Windows PowerShell 5.1** — the script will exit if run under any other version
- **OSIsoft/AVEVA AF SDK** installed on the machine running the script
- Read access to the target PI Data Archive server

### Configuration

Edit the variables at the top of the script before running:

| Variable | Default | Description |
|----------|---------|-------------|
| `$SEARCH_CRITERIA` | `"*"` | PI Point query filter. See [PI Point query syntax](https://docs.aveva.com/bundle/af-sdk/page/html/pipoint-query-syntax-overview.htm) |
| `$STALE_DAYS` | `90` | Days without good data before a tag is considered Stale; also the threshold for classifying a tag as New |
| `$INCLUDE_GOOD` | `$true` | Set to `$false` to exclude Good tags from the output |
| `$OUTPUT_FILE` | `"PIPointAnalysis.csv"` | Output file path |

**Example search criteria:**

```powershell
$SEARCH_CRITERIA = "*"                  # All tags
$SEARCH_CRITERIA = "PointSource:L"      # Lab (L) tags only
$SEARCH_CRITERIA = "PointSource:<>L"    # Exclude lab tags
$SEARCH_CRITERIA = "PointType:Float32"  # Float32 tags only
$SEARCH_CRITERIA = "sin*"               # Tags starting with "sin"
```

### Usage

```powershell
# Run in Windows PowerShell 5.1
.\Get-PIPointAnalysis.ps1
```

The script will display a progress bar and write results to the configured `$OUTPUT_FILE`.

### Output

A semicolon-delimited CSV with the following columns:

| Column | Description |
|--------|-------------|
| `Name` | PI Point name |
| `ObjectType` | Always `PIPoint` |
| `pointtype` | PI Point data type (e.g. `Float32`, `Int32`, `String`) |
| `archiving` | Whether archiving is enabled (`1`/`0`) |
| `future` | Whether the future flag is set (`1`/`0`) |
| `pointsource` | Point source identifier |
| `scan` | Scan flag |
| `creationdate` | Tag creation date (UTC ISO 8601) |
| `changedate` | Last attribute change date (UTC ISO 8601) |
| `lastgoodvalue` | Most recent good value |
| `lastgoodtimestamp` | Timestamp of the most recent good value (UTC ISO 8601) |
| `agedays` | Age of the last good value in days |
| `category` | `Good`, `Stale`, `New`, or `Empty` |
