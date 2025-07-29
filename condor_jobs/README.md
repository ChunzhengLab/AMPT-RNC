# AMPT Condor提交系统

专为AMPT重离子碰撞模拟设计的HTCondor批处理作业提交系统。

## 项目概述

本系统用于批量运行AMPT模拟，研究不同参数组合对重离子碰撞结果的影响：

- **固定参数**: √s_NN = 5.02 TeV铅-铅碰撞 (ALICE LHC设置)，500个事件，撞击参数0-20 fm
- **可变参数**: ZPC前部分子动量重排 (ISHLF) 和聚合方式 (ICOAL_METHOD)

## 目录结构

```
condor_jobs/
├── ampt.sub                 # HTCondor提交配置文件
├── run_ampt.sh             # 作业包装脚本
├── config/                 # 配置文件目录  
│   └── job_params.txt      # 作业参数列表
├── scripts/                # 辅助脚本
│   ├── generate_jobs.py    # 参数生成脚本
│   ├── monitor_jobs.sh     # 作业监控脚本
│   └── test_setup.sh       # 系统测试脚本
├── outputs/                # 输出目录
│   ├── logs/              # 作业日志
│   └── results/           # 结果文件
└── README.md              # 本文档
```

## 快速开始

### 1. 编译程序

首先编译AMPT主程序和分析程序：

```bash
# 方法1: 使用准备脚本 (推荐)
./condor_jobs/scripts/prepare_binaries.sh

# 方法2: 手动编译
make clean && make                                    # 编译AMPT主程序
make -f Makefile.analysis analysisAll_flexible       # 编译分析程序
```

### 2. 系统测试

运行系统测试确保环境配置正确：

```bash
cd condor_jobs
./scripts/test_setup.sh
```

### 3. 生成作业参数

生成不同的参数组合：

```bash
# 快速测试 (6个关键组合)
python3 scripts/generate_jobs.py quick

# 完整测试 (21个所有组合)  
python3 scripts/generate_jobs.py all

# 只测试打乱效应 (7个)
python3 scripts/generate_jobs.py reshuffle

# 只测试聚合方式 (3个)
python3 scripts/generate_jobs.py coalescence
```

### 3. 提交作业

```bash
condor_submit ampt.sub
```

### 4. 监控作业

```bash
# 查看作业状态
./scripts/monitor_jobs.sh status

# 实时监控
./scripts/monitor_jobs.sh watch

# 查看特定作业日志
./scripts/monitor_jobs.sh logs 5

# 查看结果统计
./scripts/monitor_jobs.sh results
```

## 参数说明

### ISHLF (ZPC前部分子动量重排)
- `0`: 不打乱 (基准)
- `1`: 只打乱d夸克
- `2`: 只打乱u夸克  
- `3`: 只打乱s夸克
- `4`: 打乱u+d夸克
- `5`: 打乱u+d+s夸克
- `6`: 打乱所有部分子

### ICOAL_METHOD (聚合方式)
- `1`: 经典聚合 (基准)
- `2`: BM竞争聚合
- `3`: 随机聚合

## 输出文件

每个作业生成以下结果文件：

### ROOT格式文件
- `ampt_jobN.root`: 最终强子freeze-out数据
- `zpc_jobN.root`: 部分子级联后数据
- `parton-initial_jobN.root`: 初始部分子数据
- `hadron-before-art_jobN.root`: ART级联前强子数据
- `hadron-before-melting_jobN.root`: 弦融化前强子数据

### 其他文件
- `job_N_summary.txt`: 作业摘要信息
- `ampt_jobN.dat`, `zpc_jobN.dat`: ASCII格式数据

## 高级用法

### 自定义参数组合

```bash
# 指定特定的ISHLF和ICOAL_METHOD组合
python3 scripts/generate_jobs.py custom 0,3,6 1,2,3
```

### 作业管理

```bash
# 杀死所有作业
./scripts/monitor_jobs.sh kill

# 清理日志和临时文件
./scripts/monitor_jobs.sh clean

# 生成完整报告
./scripts/monitor_jobs.sh summary
```

### 批量提交不同模式

```bash
# 直接提交特定模式
./scripts/monitor_jobs.sh submit quick
./scripts/monitor_jobs.sh submit all
```

## 完整工作流程（模拟+分析）

### 模拟阶段

1. **预编译程序**：
   ```bash
   ./condor_jobs/scripts/prepare_binaries.sh
   ```

2. **生成作业参数**：
   ```bash
   cd condor_jobs
   python3 scripts/generate_jobs.py quick  # 6个测试作业
   # 或
   python3 scripts/generate_jobs.py all 10  # 60个完整作业
   ```

3. **提交HTCondor作业**：
   ```bash
   condor_submit ampt.sub
   ```

4. **监控作业进度**：
   ```bash
   ./scripts/monitor_jobs.sh status   # 查看状态
   ./scripts/monitor_jobs.sh watch    # 实时监控
   ```

### 分析阶段

5. **编译分析程序**（如果还没有）：
   ```bash
   ./scripts/run_analysis.sh compile
   ```

6. **分析模拟结果**：
   ```bash
   # 分析所有强子数据类型
   ./scripts/run_analysis.sh analyze-all
   
   # 分析所有夸克/部分子数据类型
   ./scripts/run_analysis.sh analyze-all-quarks
   
   # 分析所有类型（强子+夸克）
   ./scripts/run_analysis.sh analyze-all-complete
   ```

7. **合并同参数组合的数据**：
   ```bash
   # 合并ISHLF=0, ICOAL=1的所有作业
   ./scripts/run_analysis.sh merge ampt 0 1
   ./scripts/run_analysis.sh merge zpc 0 1
   ```

8. **比较不同参数组合**：
   ```bash
   # 比较(ISHLF=0,ICOAL=1)和(ISHLF=5,ICOAL=1)的效果
   ./scripts/run_analysis.sh compare 0 1 5 1
   ```

### 结果查看

9. **检查输出文件**：
   ```bash
   # 原始ROOT文件
   ls outputs/results/*.root
   
   # 分析结果
   ls outputs/analysis/*/
   ```

## 物理背景

本系统专门用于研究：

1. **初态涨落效应**: 通过ISHLF参数控制ZPC级联前的部分子动量重排，模拟初态的量子涨落
2. **强子化机制**: 通过ICOAL_METHOD参数比较不同的部分子聚合模型
3. **集体流现象**: 在ALICE LHC能量下研究重离子碰撞的集体效应

## 故障排除

### 常见问题

1. **编译失败**: 确保安装了gfortran和ROOT开发库
2. **作业卡住**: 检查HTCondor队列状态和节点资源
3. **输出异常**: 查看作业日志文件定位问题

### 调试模式

单作业测试：
```bash
./scripts/test_setup.sh  # 选择运行单作业测试
```

手动运行：
```bash
./run_ampt.sh 999 0 1  # 作业ID=999, ISHLF=0, ICOAL_METHOD=1
```

## 性能考虑

- 每个作业约需1-2小时 (500个事件)
- 每个作业约需2GB内存和5GB磁盘空间
- ROOT文件相比ASCII格式节省30-50%存储空间

## 版本信息

- AMPT版本: v1.26t9b/v2.26t9b
- 支持ROOT接口和现代化输出格式
- 针对ALICE LHC Pb-Pb 5.02 TeV碰撞优化