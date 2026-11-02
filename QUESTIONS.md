# CQYH（传奇永恒）UE3 客户端 —— 五个待解疑问

> 本文档面向外部 AI 评审。所有结论都需要你**阅读随附源码后回答**，不要凭 UE3 的通用知识想当然。
> 每个疑问都给出：现象 → 已排除的可能 → 需要你判断的具体问题 → 相关源码位置。

---

## 0. 环境事实（不要质疑这些，它们是实测的）

| 项 | 值 |
|---|---|
| 引擎 | Unreal Engine 3（盛大 CQYH 定制版，源码日期 2020-05） |
| 客户端 exe | `Binaries/Win64/MMOGame-Win64-Shipping.exe`，34 MB，自编成功 |
| 脚本源码 | `Development/Src/MMOGame/Classes/*.uc`，共 **679** 个 |
| 脚本包 | `MMOGame.u` 15,198,711 字节（2020 原版），在 `MMOGame/Script/` 和 `MMOGame/CookedPC/` 各一份 |
| 生成头 | `Inc/MMOGameClasses.h`(2.2MB) / `Inc/MMOGameUIClasses.h`(1.8MB) / `Inc/MMOGameNames.h`(42KB) |
| 编译器 | MSVC 14.51 (VS18)，WinSDK 10.0.26100 |
| 目标 | **让修改过的 `.uc` 生效**，即产出新的 `MMOGame.u` |

**核心链路**：`.uc 源码` →[make]→ `Inc/*.h` + `MMOGame.u` →[打进 pak]→ 客户端加载

**当前卡点**：make 需要一个 Editor 可执行文件来驱动，而我们编不出 / 拿不到合适的 Editor。

---

## 疑问 1（最重要）：`MMOGame.u` 与编译它的可执行文件位宽是否绑定？

### 现象
我们手上有两条路：
- **32 位 Editor**：已经编到 174/176 个模块，只差 3 类编译错误，很快能出 exe
- **64 位 Editor**：从零开始，`Intermediate/MMOGame/Win64/` 下只有 `Shipping/` 的 132 个 obj，没有 `Release/`，全量编译要 20~40 分钟

而客户端跑的是 **64 位** Shipping exe。

### 已排除的可能
- 已确认 `.u` 是 UE3 的 package 格式（NameTable / ImportTable / ExportTable / 字节码），不含 C++ 指针。
- 已确认 `Inc/*.h` 里的属性偏移用的是编译期宏 `STRUCT_OFFSET`，不是 make 写入的硬编码数字。

### 需要你判断
1. **`MMOGame.u` 里的数据是否有任何一部分依赖编译它的 Editor 的指针宽度？** 具体检查 `UStruct::PropertiesSize`、`UProperty::ElementSize`、`UProperty::ArrayDim`、`FPropertyParamsBase`、defaultproperties 序列化（`ImportDefaults` / CDO 数据）这几处，看是否有 `sizeof(void*)` 参与。
2. **32 位 Editor 跑出来的 `MMOGame.u`，交给 64 位客户端加载，`ULinkerLoad::Preload` / `StaticAllocateObject` 阶段会不会因为 `PropertiesSize` 不符而错位？**
3. 如果会有问题，**具体是哪一步出的问题**，能定位到函数最好。

### 相关源码
- `Engine/Src/UnClass.cpp`：`UStruct::Link`、`UProperty::Link`
- `Core/Src/UnObj.cpp`：`ULinkerLoad` 相关
- `UnrealEd/Src/UnScrCom.cpp`：`FNativeClassHeaderGenerator`（生成头的部分）、`ImportDefaults`

---

## 疑问 2：`UMakeCommandlet` 在什么条件下会「写出 Inc/*.h 但写不出 MMOGame.u」？

### 现象
**2026-11-01 01:01，有一次 make 确实跑成功过**，产出了完整的一套生成头：

```
D:\_mpqout\hold\inc_with_vb\
    MMOGameClasses.h      2,228,528
    MMOGameNames.h           42,631
    MMOGameUIClasses.h    1,824,119
    UMMOUIVehicleBook.h         940
    （全部时间戳 2026-11-01 01:01）
```

但这套头文件的生成格式是**标准的 make 输出**（含 `struct XXX_eventYYY_Parms`、`DECLARE_FUNCTION(exec*)`、`ProcessEvent(FindFunctionChecked(MMOGAME_YYY))`、`DECLARE_CLASS` 等），不可能是手写的。

**然而 `MMOGame.u` 至今仍是 2020 原版**（`D:\CQYHClient\MMOGame\Script\MMOGame.u`，15,198,711 字节 / 2020-05-15），`Script/` 目录下的 12 个引擎 `.u`（Core/Engine/GFXUI/…）也是从别处拷贝的，不是那次 make 产的。

### 已排除的可能
- 不是"没有日志"：当时有 `Logs/Launch.log`，但已被后续运行覆盖
- 不是"没跑完就崩了"：头文件是完整的（含新增的 `MMOUIVehicleBook` 类）

### 需要你判断
1. **`UMakeCommandlet::Main` 的执行顺序是什么？** 生成头文件 (`FNativeClassHeaderGenerator::Finish`) 和写出 `.u` (`GEditor->Exec` / `UPackage::Save`) 分别在哪个阶段？中间有哪些可能静默失败的 `return` / `break`？
2. **有没有一种情形，让 make 只走到「生成头」就正常 return 0，而不写 `.u`？** 例如某个 flag（`NAMES_ONLY`、`bIsRunningCommandlet`）导致跳过包保存。
3. **如果 `.u` 保存失败，会有日志吗？** 还是会被 `check()` / `guard` 吞掉？

### 相关源码
- `UnrealEd/Src/UMakeCommandlet.cpp`（约 5000 行，重点在 `Main` 函数和 `MakeScript`）
- `UnrealEd/Src/UnScrCom.cpp`：`FNativeClassHeaderGenerator` 的构造函数与 `Finish`

---

## 疑问 3：`.uc` 里不存在、但 C++ 里有 `IMPLEMENT_CLASS` 的 native 类，会发生什么？

### 现象
源码里有这样一段（注释是中文，是后来手工加的）：

```cpp
// Src/Ability.cpp:36
IMPLEMENT_CLASS(UAbilityRoleMountComponent)

// Src/Ability.cpp:2103
BaseComponent* UAbilityRoleMountComponent::CreateCplusplusNode()
{
	return new RoleMountComponent;
}

#if PLATFORM_64BITS
typedef char RoleMountComp_SizeGate[(sizeof(UAbilityRoleMountComponent)==0x98)?1:-1];
typedef char RoleMountComp_MountIdGate[(STRUCT_OFFSET(UAbilityRoleMountComponent,MountId)==0x94)?1:-1];
#endif
```

但 `Classes/` 下**没有** `AbilityRoleMountComponent.uc`（只有 `AbilityBackgroundMusicComponent.uc`），`Inc/MMOGameClasses.h` 里也没有 `UAbilityRoleMountComponent` 的 `DECLARE_CLASS`。

编译报 `C2513`（`MountData` 在 `=` 前没有声明符）、`C2238`、`C2065`。

### 已排除的可能
- 不是笔误：`sizeof==0x98`、`MountId@0x94` 的断言说明这个类在参考 exe 里是真实存在的
- 不是唯一一处：`AbilityProcessor.cpp:7488` 还有一个诊断探针在打印它的 `sizeof` 和 `STRUCT_OFFSET`

### 需要你判断
1. **UE3 的 `IMPLEMENT_CLASS(TClass)` 单参数版本（`Core/Inc/UnObjBas.h:860`）在没有前置 `DECLARE_CLASS` 时会怎样？** 是编译错误，还是会在运行时 `StaticClass()` 时崩？
2. **要手工补一个 native UClass 的完整声明，最小需要哪些宏？** 请给出一个可编译的最小模板（含 `DECLARE_CLASS`、`DEFINE_DEFAULT_OBJECT_INITIALIZER`、成员布局约束）。
3. **更可行的做法**：是不是应该在 `Classes/` 下补一个 `.uc` 文件，让 make 去生成？如果是，`.uc` 里要怎么声明才能让生成的 `sizeof` 刚好是 `0x98`、`MountId` 在 `0x94`？（基类 `UAbilityComponent` 的 `sizeof` 是 `0x94`，属性从 `0x94` 开始）

### 相关源码
- `Core/Inc/UnObjBas.h:820~880`（`IMPLEMENT_CLASS` / `IMPLEMENT_CLASS_LIGHTWEIGHT` 宏）
- `Core/Src/UnObj.cpp`：`UClass::StaticClass`、`InternalRegisterNativeClass`
- `MMOGame/Classes/AbilityBackgroundMusicComponent.uc`（可作模板）

---

## 疑问 4：`GConfig->GetBool` 读到了文件里的键，却返回 false

### 现象
一个 81 MB 的 Editor exe（`D:\_editor_patch\MMOGame.exe`，2025-11-05 编，带完整 `.lib/.exp/.pdb`）跑 `make` 时报：

```
Assertion failed: SystemSettings[SettingIndex].bFound || ... 
[File: E:\08.Prog_CQ_S1\Client\UE3\Development\Src\Engine\Src\SystemSettings.cpp] [Line: 839]
Couldn't find system setting DrawSilhouettes in Ini section SystemSettings 
in Ini file ..\..\MMOGame\Config\MMOSystemSettingsHD.ini!
```

但对照检查：
- 该 ini 文件（51,605 字节）解码后第 232 行**确实有** `DrawSilhouettes=true`，且位于 `[SystemSettings]` 段内（段头在第 1 行，`[SystemSettingsBucket1]` 在第 245 行）
- 换成 `D:\CQYHClient\MMOGame\Config\MMOSystemSettingsHD.ini`（48,290 字节，**游戏客户端正在用、肯定没问题**）也一样报错
- 该 ini **不在任何 pak 里**（`Config/00000.pak` 和 6 个 `CookedPC/*.pak` 都查过，无同名条目）
- 用户目录 `Documents/My Games/CQYH3D/MMOGame/Config/` 是空的，没有被用户配置覆盖

### 已排除的可能
- 不是编码问题：试过 ASCII、UTF-16LE（`\xff\xfe` BOM）、截断到只保留前 879 行，三种都报同一个错
- 不是 pak 优先：pak 里没有这个文件
- 不是 ini 内容：换成正在运行的客户端那份也不行

### 需要你判断
1. **`SystemSettings.cpp:802` 的循环里，`GConfig->GetBool(*IniSection, Setting->SettingName, ..., IniFilename)` 的 `IniFilename` 是什么？** 是从哪传进来的？会不会是 `GSystemSettingsIni` 而不是字面那个路径？
2. **`FConfigCacheIni::GetBool` 在文件未加载时会自动加载吗？** 加载失败会不会静默返回 false？在哪个环节可能静默失败？
3. **`SettingName` 会不会不是 `DrawSilhouettes`（比如带前后空格、带引号、大小写不同）？** 那个 exe 来自另一份源码（`E:\08.Prog_CQ_S1\`，该目录已不存在），它的 `SystemSettings` 数组可能是另一个版本。
4. **`IniSection` 会不会不是 `SystemSettings`**，而是 `BasedOn` 递归后的某个段？看 `LoadFromIni` 第 796~800 行的 `BasedOnSection` 逻辑，如果 `[Configuration]` 段的 `BasedOn` 指向一个不存在的段，会怎样？

### 相关源码
- `Engine/Src/SystemSettings.cpp` 第 760~870 行（`LoadFromIni` 全函数）
- `Core/Src/FConfigCacheIni.cpp`（`GetBool` / `LoadFile` / `Combine`）
- `Core/Src/UnMisc.cpp`：`appCheckIniForOutdatedness`（第 5141 行起）

---

## 疑问 5：`WITH_MANAGED_CODE=0` 编出的 Editor 能不能正常跑 commandlet？

### 现象
Editor 构建卡在两个 C++/CLI 模块：
- `UnrealEdCLR`（31 个文件：`ContentBrowserCLR.cpp`、`DataBrowserCLR.cpp`、`WPFFrameCLR.cpp` 等）
- `SwarmInterfaceMake`

失败点：
```
WPFFrameCLR.h(128): error C3766: "MWPFPanel" 必须提供接口方法
    "INotifyPropertyChanged::PropertyChanged::add"
WPFFrameCLR.h(123): fatal error C1903: 无法从以前的错误中恢复；正在停止编译
```

**关键**：这不是我们独有的问题。原厂自己的构建机（2023-11-05 21:27，日志路径 `E:\CQYH\cqyh\_AutoBuild\`）也死在同一处：

```
EXEC : UBT error : Failed to produce item: ...\Binaries\Win32\MMOGame.exe
[21:27] UBT execution time: 52.98 seconds, 0.00 seconds linking
```

我们找到开关 `UE3BuildConfiguration.cs:13`（环境变量 `ue3.bAllowManagedCode`，默认 true），设为 false 后 `UE3BuildWin32.cs:756` 整块跳过这两个模块，`Launch.cpp:790` 走 `GuardedMainWrapper`（而非 `ManagedGuardedMain`）。

实测：模块确实被跳过了（`UnrealEdCLR/` 目录文件时间未变），obj 从 172 → 174。

### 需要你判断
1. **`GuardedMainWrapper` 这条 native 路径，能否正常执行 commandlet（`make`）？** 还是说 commandlet 分发依赖 CLR 的 `ManagedGuardedMain`？
2. **`WITH_MANAGED_CODE=0` 时，`UnrealEd` 模块里那些 `#if WITH_MANAGED_CODE` 的 `else` 分支（或缺失的 else）会导致链接期缺符号吗？** 全仓有 258 处 `#if WITH_MANAGED_CODE`，大多数没有 `#else`。重点看：`ContentBrowserHost.cpp`(6处)、`DataBrowserHost.cpp`(10处)、`EditorFrame.cpp`(20处)、`MeshPaintEdMode.cpp`(16处)。
3. 有没有更省事的办法：**保留 CLR 模块但让 `WPFFrameCLR.h` 那个 C3766 通过编译**？（比如给 `MWPFPanel` 补显式事件访问器）

### 相关源码
- `Launch/Src/Launch.cpp:790~810`（`GuardedMainWrapper` vs `ManagedGuardedMain`）
- `Launch/Src/LaunchEngineLoop.cpp`（commandlet 分发入口）
- `UnrealEdCLR/Inc/WPFFrameCLR.h:83~130`、`UnrealEdCLR/Inc/ManagedCodeSupportCLR.h:137`

---

## 附：回答时请遵守的三点

1. **不要给"建议尝试"**，给"因为第 X 行的逻辑是 Y，所以结论是 Z"。我们要的是判断，不是待办清单。
2. **如果某个疑问需要更多源码才能回答，直接说"需要 XXX 文件的 YYY 函数"**，不要跳过。
3. **疑问 1 的答案优先级最高** —— 它决定我们现在是继续编 32 位（快）还是必须等 64 位（慢 40 分钟）。
