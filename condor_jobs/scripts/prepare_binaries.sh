#!/bin/bash

# ==============================================================================
# AMPT二进制文件准备脚本
# 在提交HTCondor作业前运行此脚本，确保所有程序已编译
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/storage/fdunphome/wangchunzheng/AMPT-RNC}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMPT二进制文件准备 ===${NC}"

cd "$PROJECT_DIR"

# 检查必要的源文件
required_files=("main.f" "Makefile" "analysisAll_flexible.cxx" "Makefile.analysis")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 缺少必要文件: $file${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}1. 编译AMPT主程序...${NC}"

# 编译AMPT
if [ -f "ampt" ]; then
    echo "  AMPT可执行文件已存在，重新编译..."
    make clean
fi

make || {
    echo -e "${RED}错误: AMPT编译失败${NC}"
    echo "请检查Fortran编译器和依赖库"
    exit 1
}

if [ ! -f "ampt" ] || [ ! -x "ampt" ]; then
    echo -e "${RED}错误: AMPT可执行文件生成失败${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ AMPT主程序编译成功${NC}"

echo -e "${YELLOW}2. 编译分析程序...${NC}"

# 编译分析程序
if [ -f "analysisAll_flexible" ]; then
    echo "  分析程序已存在，重新编译..."
fi

make -f Makefile.analysis analysisAll_flexible || {
    echo -e "${RED}错误: 分析程序编译失败${NC}"
    echo "请检查ROOT环境和g++编译器"
    exit 1
}

if [ ! -f "analysisAll_flexible" ] || [ ! -x "analysisAll_flexible" ]; then
    echo -e "${RED}错误: 分析程序生成失败${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ 分析程序编译成功${NC}"

# 显示文件信息
echo -e "${YELLOW}3. 验证二进制文件...${NC}"

echo "  AMPT主程序:"
ls -lh ampt
file ampt

echo "  分析程序:"
ls -lh analysisAll_flexible
file analysisAll_flexible

# 检查模板文件
if [ ! -f "condor_jobs/templates/input.ampt.template" ]; then
    echo -e "${RED}警告: 模板文件不存在: condor_jobs/templates/input.ampt.template${NC}"
fi

echo -e "${GREEN}=== 准备完成！===${NC}"
echo "现在可以提交HTCondor作业:"
echo "  cd condor_jobs"
echo "  python3 scripts/generate_jobs.py quick"
echo "  condor_submit ampt.sub"