# AVEVA PI System Tools

A collection of code snippets, scripts, and configuration files for the AVEVA PI System.

> **Disclaimer:** None of these files are endorsed by AVEVA. Use at your own risk.

---

## Repository Structure

```
aveva-pi-tools/
├── asset-framework/
│   ├── enumerations/          # AF enumeration sets (importable XML)
│   └── shift-patterns/        # AF shift pattern templates (importable XML)
├── pi-data-archive/           # PowerShell scripts for PI Data Archive administration
└── pi-web-api/                # PI Web API snippets and utilities
```

## Contents

### Asset Framework (`asset-framework/`)

XML files that can be imported directly into AVEVA Asset Framework (AF) using PI System Explorer or the AF SDK.

| File | Description |
|------|-------------|
| `enumerations/ISO-3166_Country_Names.xml` | Enumeration set containing ISO 3166 country names |
| `shift-patterns/Shift_Pattern_None-Odd-Even.xml` | Shift pattern with None, Odd, and Even schedule options |
| `shift-patterns/Shift_Pattern_Daily_Schedule.xml` | Daily shift schedule pattern template |

#### How to import AF XML files
1. Open PI System Explorer
2. Navigate to **Library** > right-click the relevant section > **Import**
3. Select the XML file and follow the prompts

---

### PI Data Archive (`pi-data-archive/`)

PowerShell scripts for administering and analysing the PI Data Archive.

| File | Description |
|------|-------------|
| `Get-PIPointAnalysis.ps1` | Analyses PI Points and categorises them as New, Empty, Stale, or Good based on their data history |

#### Requirements
- Windows PowerShell 5.1 (not PowerShell Core)
- OSIsoft AF SDK installed

See the [pi-data-archive README](pi-data-archive/README.md) for full usage details.

---

### PI Web API (`pi-web-api/`)

Snippets and utilities for working with the PI Web API.

| File | Description |
|------|-------------|
| `GetWebId_NodeRed_flow.json` | Node-RED function node that generates a PI Web API WebID from an AF path |

See the [pi-web-api README](pi-web-api/README.md) for full usage details.

---

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
