---
description: Markdown display for Universal Apps.
---

# Markdown

`New-UDMarkdown` accepts a markdown string and renders it as HTML elements within a dashboard.

```powershell
New-UDMarkdown -Markdown "
   # Header
   - List Item 1
   - List Item 2
   
   ## Sub Header
"
```

## Markdown in Paper

When using `New-UDPaper`, you will need to override the default display type of the paper to avoid formatting issues.&#x20;

```powershell
$m=@'
# Hello

## world
- a
- b
-c
'@

New-UDPaper -Elevation 7 -Children {
   New-UDMarkdown -markdown $m
} -Style @{
   display = 'block'
}
```

## API

* New-UDMarkdown
