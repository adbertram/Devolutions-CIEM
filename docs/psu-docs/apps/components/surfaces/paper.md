---
description: Paper component for Universal Apps
---

# Paper

**In Material Design, the physical properties of paper are translated to the screen.**

The background of an application resembles the flat, opaque texture of a sheet of paper, and an application’s behavior mimics paper’s ability to be re-sized, shuffled, and bound together in multiple sheets.

## Paper

![](<../../../.gitbook/assets/image (327).png>)

```powershell
New-UDPaper -Elevation 0 -Content {} 
New-UDPaper -Elevation 1 -Content {} 
New-UDPaper -Elevation 3 -Content {}
```

## Paper Content Formatting&#x20;

By default, the paper component uses the flex display type for content within the paper. This can cause issues with other types of content that may be stored within the paper. You can override the display type by using the `-Style` parameter.&#x20;

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

## Square Paper

By default, paper will have rounded edges. You can reduce the rounding by using a square paper.

```powershell
New-UDPaper -Square -Content {}
```

## Colored Paper

The `-Style` parameter can be used to color paper. Any valid CSS can be included in the hashtable for a style.

The following example creates paper with a red background.

```powershell
New-UDPaper  -Content { } -Style @{ 
     backgroundColor = 'red'
}
```

## API

* [New-UDPaper](../../../cmdlets/New-UDPaper.txt)
