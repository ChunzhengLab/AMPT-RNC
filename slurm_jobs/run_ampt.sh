#!/bin/bash

# ==============================================================================
# SLURM AMPT作业包装脚本 - 使用本地存储优化I/O性能
# ==============================================================================

# ----------------------------
# 1. 环境初始化
# ----------------------------
echo "=== AMPT JOB STARTED [$(date)] ==="
echo "主机名: $(hostname)"
echo "作业ID: $SLURM_ARRAY_TASK_ID"

# 保存原始工作目录
ORIG_DIR=$PWD
PROJECT_DIR="${PROJECT_DIR:-/home/chunzheng/AMPT-RNC}"

# 设置本地工作目录 - 优先使用SLURM提供的临时目录
if [ -n "$SLURM_TMPDIR" ]; then
    LOCAL_DIR="$SLURM_TMPDIR"
    echo "使用SLURM临时目录: $SLURM_TMPDIR"
elif [ -w "/tmp" ]; then
    LOCAL_DIR="/tmp/slurm_$SLURM_JOB_ID"
    echo "使用/tmp目录: $LOCAL_DIR"
else
    # 退回到网络存储
    LOCAL_DIR="$PROJECT_DIR/slurm_jobs/outputs"
    echo "警告: 使用网络存储，性能可能较慢"
fi
WORK_DIR="${LOCAL_DIR}/ampt_job_${SLURM_ARRAY_TASK_ID}"

echo "项目目录: $PROJECT_DIR"
echo "本地工作目录: $WORK_DIR"

# 激活conda环境
source /home/chunzheng/miniconda3/etc/profile.d/conda.sh
conda activate cpp_dev
echo "Conda环境已激活: cpp_dev"

# 检查ROOT环境 (通常系统自带或通过module加载)
if command -v root-config &> /dev/null; then
    export ROOT_INCLUDE_PATH=$(root-config --incdir)
    export ROOT_LIBRARY_PATH=$(root-config --libdir)
    echo "ROOT环境已配置: $(root-config --version)"
else
    echo "警告: 未找到ROOT环境"
fi

# 设置编译器环境
export CC=gcc
export CXX=g++
export FC=gfortran

# ----------------------------
# 2. 参数解析
# ----------------------------
JOB_ID=$1
ISHLF=$2
ICOAL_METHOD=$3

# 固定参数 - ALICE LHC设置
ENERGY=5020
NEVNT=100
BMIN=7.65
BMAX=8.83
ISOFT=4

echo "配置参数:"
echo "  作业ID    : $JOB_ID"  
echo "  ZPC前打乱 : $ISHLF (0=不打乱, 1=d夸克, 2=u夸克, 3=s夸克, 4=u+d, 5=u+d+s, 6=全部)"
echo "  聚合方式  : $ICOAL_METHOD (1=经典, 2=BM竞争, 3=随机)"
echo "  固定参数  : 能量=${ENERGY}GeV(ALICE LHC), 事件数=${NEVNT}, 撞击参数=${BMIN}-${BMAX}fm(30-40%中心度), 铅-铅碰撞"

# ----------------------------
# 3. 创建本地工作目录
# ----------------------------
echo "创建本地工作目录..."
mkdir -p "$WORK_DIR/ana"
cd "$WORK_DIR"

# 生成唯一的随机种子 - 确保每个作业都有不同的种子
# 使用作业ID和数组任务ID确保唯一性和可重现性
HIJING_SEED=$((13150909 + $SLURM_ARRAY_TASK_ID * 17 + ${SLURM_JOB_ID#*_} % 10000))
ZPC_SEED=$((1 + $SLURM_ARRAY_TASK_ID * 7 + ${SLURM_JOB_ID#*_} % 99))

echo "随机种子: HIJING=$HIJING_SEED, ZPC=$ZPC_SEED"

# ----------------------------
# 4. 复制必要文件到本地存储
# ----------------------------
echo "复制文件到本地存储..."

# 复制AMPT可执行文件
if [ ! -f "$PROJECT_DIR/ampt" ]; then
    echo "错误: AMPT可执行文件不存在: $PROJECT_DIR/ampt"
    exit 1
fi
cp "$PROJECT_DIR/ampt" .

# ----------------------------
# 5. 创建输入配置文件
# ----------------------------
TEMPLATE_FILE="$PROJECT_DIR/slurm_jobs/templates/input.ampt.template"
CONFIG_FILE="input.ampt"

# 检查模板文件是否存在
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "错误: 模板文件不存在: $TEMPLATE_FILE"
    exit 1
fi

echo "使用模板文件生成配置: $TEMPLATE_FILE"

# 使用sed进行模板变量替换
sed -e "s/{ENERGY}/$ENERGY/g" \
    -e "s/{IAP}/208/g" \
    -e "s/{IZP}/82/g" \
    -e "s/{IAT}/208/g" \
    -e "s/{IZT}/82/g" \
    -e "s/{NEVNT}/$NEVNT/g" \
    -e "s/{BMIN}/$BMIN/g" \
    -e "s/{BMAX}/$BMAX/g" \
    -e "s/{ISOFT}/$ISOFT/g" \
    -e "s/{ICOAL_METHOD}/$ICOAL_METHOD/g" \
    -e "s/{HIJING_SEED}/$HIJING_SEED/g" \
    -e "s/{ZPC_SEED}/$ZPC_SEED/g" \
    -e "s/{ISHLF}/$ISHLF/g" \
    "$TEMPLATE_FILE" > "$CONFIG_FILE"

# 验证配置文件生成成功
if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
    echo "错误: 配置文件生成失败"
    exit 1
fi

echo "配置文件生成成功: $CONFIG_FILE"


# ----------------------------
# 6. 运行AMPT模拟（在本地存储）
# ----------------------------
echo "开始运行AMPT模拟（本地存储）..."

# 运行AMPT程序 (提供随机种子以防配置文件中ihjsed=11)
echo "$HIJING_SEED" | ./ampt || {
    echo "错误: AMPT运行失败"
    # 清理本地存储
    cd "$ORIG_DIR"
    rm -rf "$WORK_DIR"
    exit 1
}

echo "AMPT模拟完成"

# ----------------------------
# 7. 将结果复制回网络存储
# ----------------------------
echo "将结果复制回网络存储..."

RESULTS_DIR="$PROJECT_DIR/slurm_jobs/outputs/results"
mkdir -p "$RESULTS_DIR"

# 复制ROOT文件
if [ -d "ana" ]; then
    for file in ana/*.root; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .root)
            cp "$file" "$RESULTS_DIR/${filename}_job${JOB_ID}.root"
            echo "输出: $RESULTS_DIR/${filename}_job${JOB_ID}.root"
        fi
    done
fi

# 复制input配置文件
if [ -f "input.ampt" ]; then
    cp "input.ampt" "$RESULTS_DIR/input_job${JOB_ID}.ampt"
fi

# 创建作业摘要
cat > "$RESULTS_DIR/job_${JOB_ID}_summary.txt" << EOF
AMPT作业摘要
====================
作业ID: $JOB_ID
完成时间: $(date)
节点: $(hostname)
参数配置:
  ZPC前打乱: $ISHLF
  聚合方式: $ICOAL_METHOD
  能量: $ENERGY GeV
  事件数: $NEVNT
  撞击参数: $BMIN - $BMAX fm
  模式: $ISOFT
  随机种子: HIJING=$HIJING_SEED, ZPC=$ZPC_SEED
  使用本地存储: 是

输出文件:
$(ls -la $RESULTS_DIR/*job${JOB_ID}* 2>/dev/null || echo "无输出文件")
EOF

# ----------------------------
# 8. 清理本地存储
# ----------------------------
echo "清理本地存储..."
cd "$ORIG_DIR"

# 安全清理：只删除本作业创建的目录
if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
fi

# 退出conda环境
conda deactivate

echo "=== AMPT JOB COMPLETED [$(date)] ==="
echo "作业$JOB_ID 完成，结果保存在 slurm_jobs/outputs/results/"