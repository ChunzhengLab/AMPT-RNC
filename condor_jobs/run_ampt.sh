#!/bin/bash

# ==============================================================================
# HTCondor AMPT作业包装脚本
# ==============================================================================

# ----------------------------
# 1. 环境初始化
# ----------------------------
echo "=== AMPT JOB STARTED [$(date)] ==="

# 设置项目根目录
PROJECT_DIR="${PROJECT_DIR:-/storage/fdunphome/wangchunzheng/AMPT-RNC}"
cd "$PROJECT_DIR" || exit 1

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
NEVNT=200
BMIN=7.65
BMAX=8.83
ISOFT=4

echo "配置参数:"
echo "  作业ID    : $JOB_ID"  
echo "  ZPC前打乱 : $ISHLF (0=不打乱, 1=d夸克, 2=u夸克, 3=s夸克, 4=u+d, 5=u+d+s, 6=全部)"
echo "  聚合方式  : $ICOAL_METHOD (1=经典, 2=BM竞争, 3=随机)"
echo "  固定参数  : 能量=${ENERGY}GeV(ALICE LHC), 事件数=${NEVNT}, 撞击参数=${BMIN}-${BMAX}fm(30-40%中心度), 铅-铅碰撞"

# ----------------------------
# 3. 工作目录准备
# ----------------------------
WORK_DIR="condor_jobs/outputs/job_${JOB_ID}"
mkdir -p "$WORK_DIR"

# 生成唯一的随机种子 (与test_local.sh一致的机制)
# 使用JOB_ID作为随机数种子基础，确保每个作业不同但可重现
RANDOM=$((JOB_ID + $(date +%s) % 1000))
HIJING_SEED=$((13150909 + $RANDOM % 10000))
ZPC_SEED=$((1 + $RANDOM % 100))

echo "随机种子: HIJING=$HIJING_SEED, ZPC=$ZPC_SEED"

# ----------------------------
# 4. 创建输入配置文件 (使用模板替换)
# ----------------------------
TEMPLATE_FILE="condor_jobs/templates/input.ampt.template"
CONFIG_FILE="$WORK_DIR/input.ampt"

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
# 5. 检查AMPT可执行文件并复制到工作目录
# ----------------------------
if [ ! -f "$PROJECT_DIR/ampt" ]; then
    echo "错误: AMPT可执行文件不存在: $PROJECT_DIR/ampt"
    echo "请先在主目录运行: make"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/analysisAll_flexible" ]; then
    echo "错误: 分析程序不存在: $PROJECT_DIR/analysisAll_flexible"
    echo "请先在主目录运行: make -f Makefile.analysis analysisAll_flexible"
    exit 1
fi

echo "复制程序文件到工作目录..."
cd "$WORK_DIR"
cp "$PROJECT_DIR/ampt" .
cp "$PROJECT_DIR/analysisAll_flexible" .
cp "$CONFIG_FILE" input.ampt

# 验证复制成功
if [ ! -f "./ampt" ] || [ ! -x "./ampt" ]; then
    echo "错误: AMPT程序复制失败或无执行权限"
    exit 1
fi

# ----------------------------
# 6. 运行AMPT模拟
# ----------------------------
echo "开始运行AMPT模拟..."

# 创建输出目录
mkdir -p ana

# 运行AMPT程序 (提供随机种子以防配置文件中ihjsed=11)
echo "$HIJING_SEED" | ./ampt || {
    echo "错误: AMPT运行失败"
    exit 1
}

echo "AMPT模拟完成，开始运行分析程序..."

# 运行分析程序 - 分析所有生成的ROOT文件
if [ -d "ana" ]; then
    for rootfile in ana/*.root; do
        if [ -f "$rootfile" ]; then
            filename=$(basename "$rootfile" .root)
            output_analysis="ana/${filename}_analysis.root"
            
            # 根据文件名确定格式
            case "$filename" in
                "ampt")
                    format="ampt"
                    ;;
                "zpc")
                    format="zpc"
                    ;;
                "parton-initial")
                    format="parton_initial"
                    ;;
                "hadron-before-art")
                    format="hadron_before_art"
                    ;;
                "hadron-before-melting")
                    format="hadron_before_melting"
                    ;;
                *)
                    format="auto"
                    ;;
            esac
            
            echo "分析文件: $rootfile -> $output_analysis (格式: $format)"
            ./analysisAll_flexible "$rootfile" "$output_analysis" "$format" || {
                echo "警告: 分析文件 $rootfile 失败"
            }
        fi
    done
else
    echo "警告: 未找到ana目录，跳过分析步骤"
fi

# ----------------------------
# 7. 输出文件管理
# ----------------------------
RESULTS_DIR="$PROJECT_DIR/condor_jobs/outputs/results"
mkdir -p "$RESULTS_DIR"

# 移动并重命名输出文件
if [ -d "ana" ]; then
    echo "处理输出文件..."
    
    # 移动ROOT文件
    for file in ana/*.root; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .root)
            mv "$file" "$RESULTS_DIR/${filename}_job${JOB_ID}.root"
            echo "输出: $RESULTS_DIR/${filename}_job${JOB_ID}.root"
        fi
    done
    
    # 移动input配置文件
    if [ -f "input.ampt" ]; then
        cp "input.ampt" "$RESULTS_DIR/input_job${JOB_ID}.ampt"
        echo "输出: $RESULTS_DIR/input_job${JOB_ID}.ampt"
    fi
    
    # 清理ana目录中的其他文件（保留ROOT文件和input文件）
    echo "清理临时文件..."
    rm -f ana/*.dat ana/*.res ana/npart-xy.dat ana/version ana/*processes.dat ana/*before*.dat ana/*.tmp
    
    # 创建作业摘要
    cat > "$RESULTS_DIR/job_${JOB_ID}_summary.txt" << EOF
AMPT作业摘要
====================
作业ID: $JOB_ID
完成时间: $(date)
参数配置:
  ZPC前打乱: $ISHLF
  聚合方式: $ICOAL_METHOD
  能量: $ENERGY GeV
  事件数: $NEVNT
  撞击参数: $BMIN - $BMAX fm (30-40%中心度)
  模式: $ISOFT
  随机种子: HIJING=$HIJING_SEED, ZPC=$ZPC_SEED

保留文件类型:
  - ROOT数据文件 (原始 + 分析)
  - input配置文件
  - 作业摘要文件

输出文件:
$(ls -la $RESULTS_DIR/*job${JOB_ID}* 2>/dev/null || echo "无输出文件")
EOF

else
    echo "警告: 未找到ana目录，可能程序运行失败"
fi

# ----------------------------
# 8. 清理和结束
# ----------------------------
cd "$PROJECT_DIR"
rm -rf "$WORK_DIR"

echo "=== AMPT JOB COMPLETED [$(date)] ==="
echo "作业$JOB_ID 完成，结果保存在 condor_jobs/outputs/results/"