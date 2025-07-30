#!/bin/bash

# ==============================================================================
# AMPT本地测试脚本 - 单事件快速测试
# 
# 使用方法:
#   ./test_local.sh              # 运行AMPT模拟并分析
#   ./test_local.sh -a           # 仅运行分析（跳过AMPT模拟）
#   ./test_local.sh --analysis-only  # 同上
# ==============================================================================

# 激活conda环境
source /storage/fdunphome/wangchunzheng/miniconda3/etc/profile.d/conda.sh
conda activate cpp_dev
echo "Conda环境已激活: cpp_dev"

PROJECT_DIR="${PROJECT_DIR:-/storage/fdunphome/wangchunzheng/AMPT-RNC}"
cd "$PROJECT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMPT本地测试 ===${NC}"
echo

# 检查命令行参数
ANALYSIS_ONLY=false
if [ "$1" = "--analysis-only" ] || [ "$1" = "-a" ]; then
    ANALYSIS_ONLY=true
    echo -e "${YELLOW}运行模式: 仅分析${NC}"
    echo
fi

# 测试参数
JOB_ID="test"
ENERGY=5020          # ALICE LHC能量
NEVNT=2              # 只运行1个事件
BMIN=7.65
BMAX=8.83
ISOFT=4
ISHLF=0              # 不随机聚合
ICOAL_METHOD=1       # 聚合方法2 (BM竞争聚合)

echo "测试参数:"
echo "  碰撞系统  : Pb-Pb (208+82)"
echo "  事件数    : $NEVNT"
echo "  ZPC前打乱 : $ISHLF (0=不打乱)"
echo "  聚合方式  : $ICOAL_METHOD (2=BM竞争聚合)"
echo "  能量      : $ENERGY GeV (ALICE LHC)"
echo

# 检查程序文件
if [ ! -f "ampt" ]; then
    echo -e "${RED}错误: AMPT可执行文件不存在${NC}"
    echo "请先运行: make"
    exit 1
fi

if [ ! -f "analysisAll_flexible" ]; then
    echo -e "${YELLOW}警告: 分析程序不存在，跳过分析步骤${NC}"
fi

# 创建或使用测试目录
TEST_DIR="../outputs/local_test"
if [ "$ANALYSIS_ONLY" = true ]; then
    # 仅分析模式：检查目录是否存在
    if [ ! -d "$TEST_DIR" ]; then
        echo -e "${RED}错误: 测试目录不存在: $TEST_DIR${NC}"
        echo "请先运行完整测试生成数据"
        exit 1
    fi
    echo "使用现有测试目录: $TEST_DIR"
else
    # 正常模式：清理并重建目录
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/ana"
    echo "创建测试目录: $TEST_DIR"
fi

# 生成随机种子 (macOS兼容)
HIJING_SEED=$((13150909 + $RANDOM % 10000))
ZPC_SEED=$((1 + $RANDOM % 100))

echo "随机种子: HIJING=$HIJING_SEED, ZPC=$ZPC_SEED"

# 生成测试配置文件
TEMPLATE_FILE="../templates/input.ampt.template"
CONFIG_FILE="$TEST_DIR/input.ampt"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}错误: 模板文件不存在: $TEMPLATE_FILE${NC}"
    exit 1
fi

echo "生成配置文件..."

# 使用sed替换模板变量 - Pb-Pb碰撞参数 (ALICE LHC)
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

if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
    echo -e "${RED}错误: 配置文件生成失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} 配置文件生成成功"

# 切换到测试目录
cd "$TEST_DIR"

# 复制程序文件
echo "复制程序文件..."
if [ "$ANALYSIS_ONLY" = false ]; then
    cp "$PROJECT_DIR/ampt" .
    # CONFIG_FILE 已经在当前目录中，不需要复制
    if [ ! -f "input.ampt" ]; then
        echo -e "${RED}错误: 配置文件 input.ampt 不存在${NC}"
        exit 1
    fi
    
    # 验证复制成功
    if [ ! -f "./ampt" ] || [ ! -x "./ampt" ]; then
        echo -e "${RED}错误: AMPT程序复制失败或无执行权限${NC}"
        exit 1
    fi
fi

if [ -f "$PROJECT_DIR/analysisAll_flexible" ]; then
    cp "$PROJECT_DIR/analysisAll_flexible" .
fi

echo -e "${GREEN}✓${NC} 程序文件复制成功"

# 运行AMPT模拟（除非只运行分析）
if [ "$ANALYSIS_ONLY" = false ]; then
    echo
    echo -e "${YELLOW}开始运行AMPT模拟...${NC}"
    echo "位置: $(pwd)"

    # 创建输出目录已在上面完成

    # 运行AMPT (如果ihjsed=11会等待输入，需要提供随机种子)
    start_time=$(date +%s)
    if echo "$HIJING_SEED" | ./ampt; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo -e "${GREEN}✓${NC} AMPT运行成功 (用时: ${duration}秒)"
else
    echo -e "${RED}✗${NC} AMPT运行失败"
    echo "检查当前目录内容:"
    ls -la
    exit 1
fi
fi  # 结束 ANALYSIS_ONLY 检查

# 运行分析程序 - 分析所有生成的ROOT文件
if [ -f "./analysisAll_flexible" ]; then
    echo
    echo "开始运行分析程序..."
    if [ -d "ana" ]; then
        analysis_success=0
        analysis_total=0
        
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
                
                echo "  分析文件: $rootfile -> $output_analysis (格式: $format)"
                
                analysis_total=$((analysis_total + 1))
                if ./analysisAll_flexible "$rootfile" "$output_analysis" "$format"; then
                    analysis_success=$((analysis_success + 1))
                    echo -e "    ${GREEN}✓${NC} 分析成功"
                else
                    echo -e "    ${YELLOW}!${NC} 分析失败"
                fi
            fi
        done
        
        if [ $analysis_total -gt 0 ]; then
            echo -e "${GREEN}✓${NC} 分析完成: $analysis_success/$analysis_total 个文件成功"
        else
            echo -e "${YELLOW}!${NC} 未找到ROOT文件进行分析"
        fi
    else
        echo -e "${YELLOW}!${NC} 未找到ana目录，跳过分析步骤"
    fi
else
    echo -e "${YELLOW}!${NC} 分析程序不存在，跳过分析步骤"
fi

# 检查输出文件
echo
echo "检查输出文件:"
if [ -d "ana" ]; then
    echo -e "${GREEN}✓${NC} ana目录存在"
    
    # 列出所有输出文件
    echo "生成的文件:"
    for file in ana/*; do
        if [ -f "$file" ]; then
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "  $(basename "$file") (${size})"
        fi
    done
    
    # 检查关键文件
    key_files=("ana/ampt.dat" "ana/zpc.dat" "ana/version")
    for file in "${key_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "  ${GREEN}✓${NC} $(basename "$file")"
        else
            echo -e "  ${YELLOW}!${NC} $(basename "$file") 缺失"
        fi
    done
    
    # 检查ROOT文件
    root_count=$(ls ana/*.root 2>/dev/null | wc -l)
    if [ "$root_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} ROOT文件: $root_count 个"
        
        # 分别显示原始文件和分析文件
        echo "    原始文件:"
        ls ana/*.root | grep -v "_analysis.root" | sed 's|ana/||g' | sed 's/^/      /'
        
        analysis_count=$(ls ana/*_analysis.root 2>/dev/null | wc -l)
        if [ "$analysis_count" -gt 0 ]; then
            echo "    分析文件:"
            ls ana/*_analysis.root | sed 's|ana/||g' | sed 's/^/      /'
        fi
    else
        echo -e "  ${YELLOW}!${NC} 未找到ROOT文件"
    fi
    
else
    echo -e "${RED}✗${NC} ana目录不存在"
fi

# 显示部分结果
echo
echo "部分结果预览:"
if [ -f "ana/ampt.dat" ]; then
    echo "ampt.dat 前5行:"
    head -5 ana/ampt.dat | sed 's/^/  /'
fi

echo
echo -e "${BLUE}=== 测试完成 ===${NC}"
echo "测试目录: $TEST_DIR"
echo "要清理测试文件，请运行: rm -rf $TEST_DIR"
echo

# 返回项目根目录
cd "$PROJECT_DIR"

# 退出conda环境
conda deactivate