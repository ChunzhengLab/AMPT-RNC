# AMPT Flexible Analysis Tool Usage Guide

## 概述

`analysisAll_flexible.cxx` 是一个灵活的AMPT数据分析工具，支持不同的ROOT文件格式。它将数据读取逻辑与分析逻辑分离，可以通过配置自动适配不同的ROOT文件结构。

## 支持的格式

### 1. AMPT强子输出格式

| 文件类型 | TTree名称 | 分支结构 | 描述 |
|----------|-----------|----------|------|
| `ampt.root` | `ampt` | `nParticles`, `impactParameter`, `pid[]`, `px[]`, `py[]`, `pz[]`, `x[]`, `y[]`, `z[]` | 最终强子freeze-out数据 |
| `hadron-before-art.root` | `hadron_before_art` | 同上 + `eventID`, `miss` | ART级联前强子数据 |
| `hadron-before-melting.root` | `hadron_before_melting` | 同上 + `eventID`, `miss` | 弦融化前强子数据 |

### 2. 传统格式（兼容）

| 格式名 | TTree名称 | 分支结构 | 描述 |
|--------|-----------|----------|------|
| `legacy_format` | `AMPT` | `Event.multi`, `Event.impactpar`, `ID[]`, `Px[]`, `Py[]`, `Pz[]`, `X[]`, `Y[]`, `Z[]` | 旧版analysisAll.cxx期望格式 |

## 编译

```bash
# 方法1: 使用Makefile
make -f Makefile.analysis analysisAll_flexible

# 方法2: 直接编译
g++ -o analysisAll_flexible analysisAll_flexible.cxx \
    $(root-config --cflags --libs) -std=c++11 -O2

# 方法3: 使用脚本
./condor_jobs/scripts/run_analysis.sh compile
```

## 使用方法

### 基本语法
```bash
./analysisAll_flexible <input.root|.list> <output.root> [format]
```

### 参数说明
- `input.root|.list`: 输入ROOT文件或文件列表
- `output.root`: 输出分析结果文件
- `format`: 格式选择（可选）
  - `auto` (默认): 自动检测格式
  - `ampt`: 强制使用ampt格式
  - `hadron_before_art`: 强制使用hadron_before_art格式
  - `hadron_before_melting`: 强制使用hadron_before_melting格式
  - `legacy_format`: 使用传统格式

## 使用示例

### 1. 自动检测格式（推荐）

```bash
# 分析单个文件
./analysisAll_flexible results/ampt_job0.root analysis_ampt_job0.root

# 分析文件列表
./analysisAll_flexible file_list.txt analysis_merged.root
```

### 2. 手动指定格式

```bash
# 分析ART前强子数据
./analysisAll_flexible results/hadron-before-art_job0.root analysis_before_art.root hadron_before_art

# 分析弦融化前强子数据  
./analysisAll_flexible results/hadron-before-melting_job0.root analysis_before_melting.root hadron_before_melting

# 分析传统格式数据
./analysisAll_flexible legacy_data.root analysis_legacy.root legacy_format
```

### 3. 批量分析不同类型

```bash
# 使用run_analysis.sh脚本（自动格式检测）
./condor_jobs/scripts/run_analysis.sh analyze ampt
./condor_jobs/scripts/run_analysis.sh analyze hadron-before-art
./condor_jobs/scripts/run_analysis.sh analyze hadron-before-melting

# 分析所有强子类型
./condor_jobs/scripts/run_analysis.sh analyze-all
```

## 程序输出

### 启动信息
```
Auto-detected format: ampt
ROOT Format Configuration:
  Tree name: ampt
  nParticles: nParticles
  impactParameter: impactParameter
  PID: pid
  Momentum: px, py, pz
  Position: x, y, z
  Max particles: 20000
  Double precision: Yes
Loaded 500 events from ampt
Processing 500 events...
```

### 分析结果
程序会生成包含以下内容的ROOT文件：
- **基本分布**: `mult`, `centrality`
- **单粒子谱**: `h_pt_*`, `h_eta_*`, `h_phi_*` 
- **空间分布**: `h_r_spatial_*`, `h_eta_spatial_*`, `h_phi_spatial_*`
- **流系数**: `p_v2_*`, `p_v2_spatial_*`
- **关联函数**: `h1_angCorr_sameEvt_*_cent*`

## 文件列表格式

创建包含多个ROOT文件的`.list`文件：

```bash
# 示例: ampt_files.list
/path/to/ampt_job0.root
/path/to/ampt_job1.root
/path/to/ampt_job2.root
...
```

然后使用：
```bash
./analysisAll_flexible ampt_files.list merged_analysis.root
```

## 高级用法

### 1. 合并同一参数组合的文件

```bash
# 创建特定参数组合的文件列表
ls results/ampt_job*.root | head -10 > ampt_subset.list

# 分析子集
./analysisAll_flexible ampt_subset.list analysis_subset.root ampt
```

### 2. 比较不同阶段的强子数据

```bash
# 分析最终强子
./analysisAll_flexible results/ampt_job0.root final_hadrons.root

# 分析ART前强子
./analysisAll_flexible results/hadron-before-art_job0.root before_art.root

# 分析弦融化前强子
./analysisAll_flexible results/hadron-before-melting_job0.root before_melting.root

# 然后用ROOT比较3个输出文件
```

### 3. 错误处理

如果自动检测失败，程序会显示：
```
Warning: No matching format found, using default
```

此时可以手动指定格式：
```bash
./analysisAll_flexible input.root output.root ampt
```

## 集成到Condor工作流

修改后的`run_analysis.sh`脚本已经集成了flexible分析工具：

```bash
# 编译
./condor_jobs/scripts/run_analysis.sh compile

# 自动分析所有类型（使用自动格式检测）
./condor_jobs/scripts/run_analysis.sh analyze-all

# 合并特定参数组合
./condor_jobs/scripts/run_analysis.sh merge ampt 0 1
```

## 扩展性

如需支持新的ROOT格式，只需在`predefined_formats`中添加新的配置：

```cpp
predefined_formats["new_format"] = {
    "tree_name",           // TTree名称
    "nParticles_branch",   // 粒子数分支
    "impactParameter_branch", // 撞击参数分支
    "pid_branch",          // PID分支
    "px_branch", "py_branch", "pz_branch", // 动量分支
    "x_branch", "y_branch", "z_branch",   // 位置分支
    true, 20000,           // 双精度，最大粒子数
    "eventID_branch", ""   // 可选分支
};
```

这种设计使得分析工具可以轻松适配不同的数据格式，而无需修改核心分析逻辑。