#!/bin/bash

# ==============================================================================
# SLURM最小化测试脚本
# 测试环境加载和基本功能
# ==============================================================================

echo "=== 最小化测试开始 [$(date)] ==="
echo "主机名: $(hostname)"
echo "用户: $(whoami)"
echo "工作目录: $(pwd)"
echo "作业ID: $SLURM_ARRAY_TASK_ID"
echo

# 激活conda环境
echo "激活conda环境..."
source /home/chunzheng/miniconda3/etc/profile.d/conda.sh
conda activate cpp_dev
echo "当前conda环境: $CONDA_DEFAULT_ENV"
echo

# 检查基本命令
echo "检查基本命令:"
echo "  Python版本: $(python --version 2>&1)"
echo "  GCC版本: $(gcc --version 2>&1 | head -1)"
echo "  Fortran版本: $(gfortran --version 2>&1 | head -1)"

# 检查ROOT环境
echo
echo "检查ROOT环境:"
if command -v root-config &> /dev/null; then
    echo "  ROOT版本: $(root-config --version)"
    echo "  ROOT路径: $(root-config --prefix)"
else
    echo "  ROOT: 未找到"
fi

# 创建测试文件
echo
echo "创建测试输出文件..."
cat > test_output_job$SLURM_ARRAY_TASK_ID.txt << EOF
测试作业 $SLURM_ARRAY_TASK_ID 完成
时间: $(date)
主机: $(hostname)
用户: $(whoami)
Conda环境: $CONDA_DEFAULT_ENV
Python版本: $(python --version 2>&1)
EOF

echo "测试文件创建完成: test_output_job$SLURM_ARRAY_TASK_ID.txt"

# 测试简单计算
echo
echo "执行简单计算测试..."
python3 -c "
import sys
print('Python路径:', sys.executable)
print('计算测试: 2+2 =', 2+2)
import os
print('环境变量CONDA_DEFAULT_ENV:', os.environ.get('CONDA_DEFAULT_ENV', '未设置'))
"

# 退出conda环境
conda deactivate
echo
echo "=== 最小化测试完成 [$(date)] ==="