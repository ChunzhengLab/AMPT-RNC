# SLURM作业系统使用指南

## 目录结构
```
slurm_jobs/
├── ampt.sbatch          # SLURM批处理脚本
├── run_ampt.sh          # 执行脚本（使用本地存储优化I/O）
├── config/
│   └── job_params.txt   # 作业参数文件
├── templates/
│   └── input.ampt.template # AMPT输入模板
├── scripts/
│   ├── prepare_binaries.sh # 准备二进制文件
│   ├── generate_jobs.py    # 生成作业参数
│   ├── check_events.sh     # 检查作业进度
│   └── organize_results.sh # 整理结果文件
└── outputs/
    ├── logs/            # 作业日志
    ├── results/         # 计算结果
    └── organized/       # 按参数整理的结果
```

## 快速开始

### 1. 准备环境
```bash
cd slurm_jobs
bash scripts/prepare_binaries.sh
```

### 2. 生成作业参数
```bash
# 生成默认参数（6个组合，每个1次）
python3 scripts/generate_jobs.py

# 生成大规模参数（6个组合，每个500次 = 3000个作业）
python3 scripts/generate_jobs.py 500
```

### 3. 提交作业
```bash
sbatch ampt.sbatch
```

### 4. 监控作业
```bash
# 查看作业状态
squeue -u $USER

# 实时监控所有作业进度
bash scripts/check_events.sh -w -a

# 查看特定作业
bash scripts/check_events.sh 0 1 2
```

### 5. 整理结果
```bash
bash scripts/organize_results.sh
```

## 本地存储优化

此版本默认使用本地存储优化I/O性能：

### 优势
- **I/O性能提升**: 使用计算节点本地SSD，避免网络延迟
- **减少网络负载**: 只在开始和结束时传输数据
- **更好的并发性**: 多个作业不会争抢网络带宽

### 工作流程
1. 复制必要文件到本地存储 `/local/storage/$SLURM_JOB_ID`
2. 在本地执行所有计算
3. 计算完成后将结果复制回网络存储
4. 自动清理本地临时文件

## 参数说明

### ISHLF（ZPC前打乱）
- 0: 不打乱
- 1: d夸克
- 2: u夸克  
- 3: s夸克
- 4: u+d夸克
- 5: u+d+s夸克
- 6: 全部夸克

### ICOAL_METHOD（聚合方式）
- 1: 经典聚合
- 2: BM竞争聚合
- 3: 随机聚合

## 故障排除

### 作业失败
```bash
# 查看错误日志
tail outputs/logs/job_0.err

# 检查SLURM作业信息
sacct -j <job_id> --format=JobID,JobName,State,ExitCode
```

### 本地存储问题
- 确认集群支持本地存储
- 检查 `/local/storage` 路径是否存在
- 尝试其他路径如 `/scratch` 或 `/tmp`

### 内存不足
编辑批处理脚本，增加内存请求：
```bash
#SBATCH --mem=4G  # 增加到4GB
```

## 最佳实践

1. **测试运行**: 先提交少量作业测试
   ```bash
   sbatch --array=0-2 ampt.sbatch
   ```

2. **合理设置并发**: 避免过载集群
   ```bash
   #SBATCH --array=0-999%50  # 最多50个并发
   ```

3. **监控资源使用**: 
   ```bash
   seff <job_id>  # 查看作业效率
   ```

4. **定期清理**: 及时整理和备份结果
   ```bash
   bash scripts/organize_results.sh
   rsync -av outputs/organized/ /backup/path/
   ```