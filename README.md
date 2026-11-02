# CQYH (Legend Eternal) UE3 Client — Open Questions for External Review

This repository exists for **one purpose**: to let an external AI read the relevant
Unreal Engine 3 source and answer five specific questions that are blocking us.

**Read `QUESTIONS.md` first.** It contains the full context and the five questions.

---

## What is in here

```
QUESTIONS.md                 <- START HERE. Five questions, with code references
evidence/
  build_error_32bit.txt      <- actual compiler errors, Win32 Release -editor
  build_error_64bit_inprogress.txt
  ubt_actual_cmdline.txt     <- the real cl.exe command line (shows /D macros)
  generated_header_sample.txt<- proof that a `make` run did succeed once
src/
  Engine/SystemSettings.cpp
  Core/FConfigCacheIni.cpp   <- FConfigCacheIni::GetBool / LoadFile
  Core/UnMisc.cpp            <- appCheckIniForOutdatedness
  Core/UnObj.cpp             <- ULinkerLoad, class registration
  Core/UnClass.cpp           <- UStruct::Link, UProperty::Link
  Core/Inc/UnObjBas.h        <- IMPLEMENT_CLASS macros
  Core/Inc/UnArc.h           <- FArchiveEncode
  UnrealEd/UMakeCommandlet.cpp   <- the `make` commandlet itself
  UnrealEd/UnScrCom.cpp          <- FNativeClassHeaderGenerator
  Launch/Launch.cpp              <- GuardedMainWrapper vs ManagedGuardedMain
  Launch/LaunchEngineLoop.cpp    <- commandlet dispatch
  UnrealEdCLR/WPFFrameCLR.h      <- the C3766 failure point
  UnrealEdCLR/ManagedCodeSupportCLR.h
  MMOGame/AbilityProcessor.h     <- where the missing native class is used
  MMOGame/AbilityBackgroundMusicComponent.uc  <- template for a native component
```

All source files were converted from GBK to **UTF-8** so they read correctly.
Do not assume the text encoding matters — it was a display-only conversion.

---

## The one-sentence situation

We have a working 2020-era UE3 client (`MMOGame-Win64-Shipping.exe`, built by us).
We want to modify UnrealScript (`.uc`) and have it take effect.
That requires running `make` (the script compiler) to produce a new `MMOGame.u`.
**We cannot get a working `make` to run.**

Everything else (C++ changes, Flash/Scaleform UI, config tables) works fine.

---

## Priority

| # | Question | Why it matters |
|---|---|---|
| **1** | Is `MMOGame.u` bitness-dependent? | Decides whether a 32-bit Editor is good enough (we are 174/176 modules into it) or we must build 64-bit from scratch (20-40 min) |
| **2** | Under what conditions does `make` write headers but not `.u`? | We have proof a `make` run produced complete generated headers on 2026-11-01, yet `MMOGame.u` is still the 2020 original |
| 3 | What happens to a native class with `IMPLEMENT_CLASS` but no `.uc`? | Currently blocking compilation |
| 4 | Why does `GConfig->GetBool` miss a key that is visibly in the file? | A prebuilt Editor we have asserts on this |
| 5 | Can an Editor built with `WITH_MANAGED_CODE=0` still run commandlets? | This is our current build strategy |

---

## How to answer

- **Do not give a list of things to try.** Give a conclusion grounded in a specific line:
  "Because line X does Y, the result is Z."
- **If you need more source to answer, say exactly which file and which function.**
  Do not guess.
- Question 1 has the highest priority.

---

## Hard constraints (measured, not assumed)

| Item | Value |
|---|---|
| Engine | Unreal Engine 3, Shanda CQYH fork, source dated 2020-05 |
| Script sources | `Development/Src/MMOGame/Classes/*.uc` — 679 files |
| Existing script package | `MMOGame.u` = 15,198,711 bytes, dated 2020-05-15 |
| Generated headers | `MMOGameClasses.h` 2.2 MB / `MMOGameUIClasses.h` 1.8 MB / `MMOGameNames.h` 42 KB |
| Compiler | MSVC 14.51 (VS 18), Windows SDK 10.0.26100 |
| Working client | `MMOGame-Win64-Shipping.exe` (64-bit), 34 MB, built by us |
| Build system | UnrealBuildTool, `MMOGame <platform> Release -editor` |
