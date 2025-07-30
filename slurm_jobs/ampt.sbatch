#!/bin/bash
# ==============================================================================
# SLURM批处理脚本 - AMPT重离子碰撞模拟
# ==============================================================================
#SBATCH --job-name=AMPT_sim
#SBATCH --output=outputs/logs/job_%a.out
#SBATCH --error=outputs/logs/job_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
# 数组范围将在运行时自动确定

# 环境变量
export PROJECT_DIR=/home/chunzheng/AMPT-RNC

# 从参数文件读取任务参数
# 格式: ISHLF ICOAL_METHOD
# 示例: 0 1 (不打乱，经典聚合)
#       6 2 (全部打乱，BM竞争聚合)  
#       3 3 (s夸克打乱，随机聚合)

# 读取参数文件
if [ ! -f config/job_params.txt ]; then
    echo "错误: 找不到参数文件 config/job_params.txt"
    exit 1
fi

# 根据 SLURM_ARRAY_TASK_ID 读取对应行的参数
line=$((SLURM_ARRAY_TASK_ID + 1))
params=$(sed -n "${line}p" config/job_params.txt)

if [ -z "$params" ]; then
    echo "错误: 无法从参数文件中读取第 $line 行"
    exit 1
fi

# 解析参数
ISHLF=$(echo $params | awk '{print $1}')
ICOAL_METHOD=$(echo $params | awk '{print $2}')

# 执行任务
./run_ampt.sh $SLURM_ARRAY_TASK_ID $ISHLF $ICOAL_METHOD