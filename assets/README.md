# Assets

This folder holds the images of the workshop notes in the
[README](../README.md) and the sources they are generated from. Edit the
sources, then regenerate the images with the commands below.

## Contents

| File                           | Source of                                                               |
|--------------------------------|-------------------------------------------------------------------------|
| `banner.html`                  | `banner.png`, the header image of the README                            |
| `diagrams/*.mmd`               | The diagrams `diagrams/*.svg`, written in Mermaid                       |
| `diagrams/mermaid-config.json` | Theme, colors, and layout settings shared by all diagrams               |
| `screenshots/ci-run-graph.png` | Screenshot of a GitHub Actions run of FileManagementSample, 17 Nov 2026 |

The README uses `workshop-journey.svg`. The topic pages in `docs` use the
other diagrams; a diagram that belongs to a single topic starts with the
number of its page, such as `13-function-to-module.mmd` for topic 13.

## Regenerate the diagrams

The diagrams need [Node.js](https://nodejs.org/) and the
[Mermaid CLI](https://github.com/mermaid-js/mermaid-cli). Run from this
folder:

```powershell
npm install --global @mermaid-js/mermaid-cli
Get-ChildItem -Path diagrams -Filter *.mmd | ForEach-Object {
    $svgPath = [System.IO.Path]::ChangeExtension($_.FullName, '.svg')
    mmdc -i $_.FullName -o $svgPath -c diagrams/mermaid-config.json -b white
}
```

`mermaid-config.json` sets `useMaxWidth` to `false`, so every SVG keeps its
natural size instead of stretching to the page width.

## Regenerate the banner

Microsoft Edge renders `banner.html` at 1280 × 320 pixels with a scale factor
of 1.5 and a transparent background:

```powershell
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$source = 'file:///' + ((Resolve-Path -Path banner.html).Path -replace '\\', '/')
$profilePath = Join-Path -Path $env:TEMP -ChildPath 'edge-banner-profile'
$arguments = @(
    '--headless=new'
    '--hide-scrollbars'
    "--user-data-dir=$profilePath"
    '--force-device-scale-factor=1.5'
    '--window-size=1280,320'
    '--default-background-color=00000000'
    "--screenshot=$PWD\banner.png"
    $source
)
Start-Process -FilePath $edge -ArgumentList $arguments -Wait
```

The separate user data folder keeps the headless instance apart from a running
Edge. The banner uses the fonts Segoe UI Variable and Cascadia Mono. Render it
on a machine that has both fonts; otherwise, Edge substitutes other fonts and
the layout shifts.
