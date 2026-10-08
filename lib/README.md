# Bundled dependencies

This folder contains the runtime files required by `MedBind.ahk`'s existing include:

```ahk
#Include lib\WebView2\WebView2.ahk
```

## AutoHotkey WebView2 library

- **Source:** [`thqby/ahk2_lib`](https://github.com/thqby/ahk2_lib)
- **Pinned revision:** `06aed7a1c42f754dfcb67962d055311a480d0848` (2026-05-20)
- **Included:** `WebView2/WebView2.ahk`, `Promise.ahk`, `ComVar.ahk`, the upstream WebView2 README, and the 32-/64-bit `WebView2Loader.dll` files.
- **License:** MIT; see [`AHK2-LIB-LICENSE.txt`](AHK2-LIB-LICENSE.txt).

The WebView2 runtime itself is a Windows system prerequisite and is not bundled here. Install Microsoft's Evergreen WebView2 Runtime if it is missing.

## Updating

Keep the relative folder layout intact: `WebView2.ahk` includes `..\ComVar.ahk` and `..\Promise.ahk`, and locates the loader DLL in the architecture-specific subfolder. When updating the library, update all three AHK files and both DLLs from the same upstream revision together.