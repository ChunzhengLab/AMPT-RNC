#!/bin/bash

# ==============================================================================
# AMPT Condor提交系统测试脚本
# ==============================================================================

# 激活conda环境
source /storage/fdunphome/wangchunzheng/miniconda3/etc/profile.d/conda.sh
conda activate cpp_dev
echo "Conda环境已激活: cpp_dev"

PROJECT_DIR="${PROJECT_DIR:-/storage/fdunphome/wangchunzheng/AMPT-RNC}"
JOBS_DIR="$PROJECT_DIR/condor_jobs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMPT Condor提交系统测试 ===${NC}"
echo

# 1. 检查基本环境
echo -e "${YELLOW}1. 检查基本环境...${NC}"

# 检查HTCondor
if command -v condor_q &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} HTCondor已安装: $(condor_version | head -1)"
else
    echo -e "  ${RED}✗${NC} HTCondor未安装或不在PATH中"
fi

# 检查ROOT
if command -v root-config &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} ROOT已安装: $(root-config --version)"
else
    echo -e "  ${YELLOW}!${NC} ROOT未找到，AMPT仍可运行但无ROOT输出"
fi

# 检查编译器
for compiler in gcc g++ gfortran; do
    if command -v $compiler &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $compiler已安装: $($compiler --version | head -1)"
    else
        echo -e "  ${RED}✗${NC} $compiler未安装"
    fi
done

echo

# 2. 检查项目结构
echo -e "${YELLOW}2. 检查项目结构...${NC}"

check_file() {
    if [ -f "$1" ]; then
        echo -e "  ${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 (缺失)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "  ${GREEN}✓${NC} $1/"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1/ (缺失)"
        return 1
    fi
}

cd "$PROJECT_DIR"

# 检查核心文件
check_file "main.f"
check_file "Makefile"
check_file "input.ampt"

# 检查condor_jobs结构
check_dir "condor_jobs"
check_file "condor_jobs/ampt.sub"
check_file "condor_jobs/run_ampt.sh"
check_file "condor_jobs/config/job_params.txt"
check_file "condor_jobs/scripts/generate_jobs.py"
check_dir "condor_jobs/outputs"
check_dir "condor_jobs/outputs/logs"
check_dir "condor_jobs/outputs/results"

echo

# 3. 检查AMPT程序
echo -e "${YELLOW}3. 检查AMPT程序...${NC}"

if [ -f "ampt" ]; then
    echo -e "  ${GREEN}✓${NC} AMPT可执行文件存在"
    
    # 检查执行权限
    if [ -x "ampt" ]; then
        echo -e "  ${GREEN}✓${NC} AMPT可执行权限正确"
    else
        echo -e "  ${YELLOW}!${NC} AMPT缺少执行权限，自动修复..."
        chmod +x ampt
    fi
else
    echo -e "  ${YELLOW}!${NC} AMPT可执行文件不存在，尝试编译..."
    
    if [ -f "Makefile" ]; then
        echo "    编译中..."
        if make > /tmp/ampt_compile.log 2>&1; then
            echo -e "  ${GREEN}✓${NC} AMPT编译成功"
        else
            echo -e "  ${RED}✗${NC} AMPT编译失败，查看日志:"
            tail -10 /tmp/ampt_compile.log
        fi
    else
        echo -e "  ${RED}✗${NC} 无Makefile，无法编译"
    fi
fi

echo

# 4. 测试参数生成
echo -e "${YELLOW}4. 测试参数生成...${NC}"

cd "$JOBS_DIR"

# 测试Python脚本
if python3 scripts/generate_jobs.py > /tmp/test_params.log 2>&1; then
    echo -e "  ${GREEN}✓${NC} 参数生成脚本工作正常"
    
    # 检查生成的文件
    if [ -f "config/job_params.txt" ]; then
        param_count=$(grep -v "^#" config/job_params.txt | grep -v "^$" | wc -l)
        echo -e "  ${GREEN}✓${NC} 生成了 $param_count 个作业参数"
    fi
else
    echo -e "  ${RED}✗${NC} 参数生成脚本失败:"
    cat /tmp/test_params.log
fi

echo

# 5. 测试作业脚本语法
echo -e "${YELLOW}5. 测试作业脚本语法...${NC}"

# 检查bash语法
if bash -n run_ampt.sh; then
    echo -e "  ${GREEN}✓${NC} run_ampt.sh语法正确"
else
    echo -e "  ${RED}✗${NC} run_ampt.sh语法错误"
fi


# 检查HTCondor提交文件语法
if condor_submit -dry-run test_condor_dryrun.log ampt.sub > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} ampt.sub语法正确"
else
    echo -e "  ${RED}✗${NC} ampt.sub语法错误:"
    echo "详细信息请查看: test_condor_dryrun.log"
fi

echo


# 6. 总结
echo -e "${BLUE}=== 测试总结 ===${NC}"

echo "测试完成！"
echo
echo "使用指南:"
echo "1. 生成参数文件:"
echo "   cd condor_jobs"
echo "   python3 scripts/generate_jobs.py             # 6个参数组合，每个1个重复(1200个事件总计)"
echo "   python3 scripts/generate_jobs.py 500         # 6个参数组合，每个500个重复(100k事件/参数)"
echo
echo "2. 提交作业:"
echo "   condor_submit ampt.sub"
echo
echo "3. 监控作业:"
echo "   condor_q                                  # 查看作业状态"
echo "   ./scripts/check_events.sh -a             # 检查事件进度"
echo "   ./scripts/organize_results.sh            # 整理结果文件"

cd "$PROJECT_DIR"

# 退出conda环境
conda deactivate