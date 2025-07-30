#!/bin/bash

# ==============================================================================
# AMPT二进制文件准备脚本
# 在提交SLURM作业前运行此脚本，确保所有程序已编译
# ==============================================================================

# 激活conda环境
source /home/chunzheng/miniconda3/etc/profile.d/conda.sh
conda activate cpp_dev
echo "Conda环境已激活: cpp_dev"

PROJECT_DIR="${PROJECT_DIR:-/home/chunzheng/AMPT-RNC}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMPT二进制文件准备 ===${NC}"

cd "$PROJECT_DIR"

# 检查必要的源文件
required_files=("main.f" "Makefile" "root_interface.cpp" "analysis_core.cpp" "root_interface.h" "analysis_core.h")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 缺少必要文件: $file${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}1. 编译AMPT主程序（带ROOT接口）...${NC}"

# 编译AMPT（需要ROOT环境）
if [ -f "ampt" ]; then
    echo "  AMPT可执行文件已存在，重新编译..."
    make clean
fi

# 加载ROOT环境并编译
echo "  加载ROOT环境..."
if command -v o2env >/dev/null 2>&1; then
    echo "  使用o2env加载ROOT环境"
    source <(o2env) && make || {
        echo -e "${RED}错误: AMPT编译失败${NC}"
        echo "请检查ROOT环境、Fortran编译器和依赖库"
        exit 1
    }
else
    echo -e "${YELLOW}  警告: 未找到o2env，尝试直接编译${NC}"
    make || {
        echo -e "${RED}错误: AMPT编译失败${NC}"
        echo "请检查Fortran编译器和依赖库"
        exit 1
    }
fi

if [ ! -f "ampt" ] || [ ! -x "ampt" ]; then
    echo -e "${RED}错误: AMPT可执行文件生成失败${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ AMPT主程序（含实时分析）编译成功${NC}"

echo -e "${YELLOW}2. 验证实时分析功能...${NC}"

# 检查是否包含实时分析功能
if grep -q "init_analysis_" ampt; then
    echo -e "${GREEN}  ✓ 检测到实时分析功能${NC}"
else
    echo -e "${YELLOW}  警告: 未检测到实时分析功能，请确认ROOT接口已正确编译${NC}"
fi

# 检查分析核心文件
if [ -f "analysis_core.cpp" ] && [ -f "analysis_core.h" ]; then
    echo -e "${GREEN}  ✓ 分析核心文件存在${NC}"
else
    echo -e "${RED}错误: 分析核心文件缺失${NC}"
    exit 1    
fi

# 显示文件信息
echo -e "${YELLOW}3. 验证二进制文件...${NC}"

echo "  AMPT主程序（含实时分析）:"
ls -lh ampt
file ampt

echo "  相关源文件:"
ls -lh *.cpp *.h 2>/dev/null || echo "  没有找到C++源文件"

# 检查模板文件
if [ ! -f "slurm_jobs/templates/input.ampt.template" ]; then
    echo -e "${RED}警告: 模板文件不存在: slurm_jobs/templates/input.ampt.template${NC}"
fi

echo -e "${GREEN}=== 准备完成！===${NC}"
echo "现在可以提交SLURM作业:"
echo "  cd slurm_jobs"
echo "  python3 scripts/generate_jobs.py"
echo "  sbatch ampt.sbatch"

# 退出conda环境
conda deactivate