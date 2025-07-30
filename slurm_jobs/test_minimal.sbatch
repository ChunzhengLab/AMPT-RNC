#!/bin/bash
# ==============================================================================
# SLURM最小化测试批处理脚本
# ==============================================================================
#SBATCH --job-name=test_minimal
#SBATCH --output=test_%a.out
#SBATCH --error=test_%a.err
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --array=0-2  # 运行3个测试作业

# 执行测试脚本
./test_minimal.sh