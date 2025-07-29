#!/bin/bash

# ==============================================================================
# AMPT Condor提交系统测试脚本
# ==============================================================================

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
check_file "condor_jobs/scripts/monitor_jobs.sh"
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
if python3 scripts/generate_jobs.py quick > /tmp/test_params.log 2>&1; then
    echo -e "  ${GREEN}✓${NC} 参数生成脚本工作正常"
    
    # 检查生成的文件
    if [ -f "config/job_params_quick.txt" ]; then
        param_count=$(grep -v "^#" config/job_params_quick.txt | grep -v "^$" | wc -l)
        echo -e "  ${GREEN}✓${NC} 生成了 $param_count 个快速测试参数"
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

if bash -n scripts/monitor_jobs.sh; then
    echo -e "  ${GREEN}✓${NC} monitor_jobs.sh语法正确"
else
    echo -e "  ${RED}✗${NC} monitor_jobs.sh语法错误"
fi

# 检查HTCondor提交文件语法
if condor_submit -dry-run ampt.sub > /tmp/condor_test.log 2>&1; then
    echo -e "  ${GREEN}✓${NC} ampt.sub语法正确"
else
    echo -e "  ${RED}✗${NC} ampt.sub语法错误:"
    cat /tmp/condor_test.log
fi

echo

# 6. 单作业测试 (如果环境允许)
echo -e "${YELLOW}6. 单作业测试...${NC}"

read -p "是否运行单作业测试? 这将创建一个测试目录并运行AMPT (y/N): " run_test

if [[ $run_test =~ ^[Yy]$ ]]; then
    echo "运行单作业测试..."
    
    # 创建测试目录
    TEST_DIR="/tmp/ampt_test_$$"
    mkdir -p "$TEST_DIR/ana"
    cd "$TEST_DIR"
    
    # 复制必要文件
    cp "$PROJECT_DIR/ampt" . 2>/dev/null || {
        echo -e "  ${RED}✗${NC} 无法复制AMPT程序"
        cleanup_test
        exit 1
    }
    
    # 创建测试输入文件 (1个事件快速测试)
    cat > input.ampt << EOF
5020            ! EFRM
CMS             ! FRAME  
A               ! PROJ
A               ! TARG
208             ! IAP
82              ! IZP
208             ! IAT
82              ! IZT
1               ! NEVNT (只运行1个事件用于测试)
0.              ! BMIN
20.             ! BMAX
4               ! ISOFT
150             ! NTMAX
0.2             ! DT
0.55            ! PARJ(41)
0.15            ! PARJ(42)
1               ! popcorn mechanism
1.0             ! PARJ(5)
1               ! shadowing flag
0               ! quenching flag
2.0             ! quenching parameter
2.0             ! p0 cutoff
2.265d0         ! parton screening mass
0               ! IZPC
0.33d0          ! alpha
1d6             ! dpcoal
1d6             ! drcoal
1               ! icoal_method
0.53            ! drbmRatio
0.5             ! mesonBaryonRatio
0               ! ihjsed
12345           ! HIJING seed
8               ! ZPC seed
0               ! K0s decays
1               ! phi decays
0               ! pi0 decays  
2               ! OSCAR output
0               ! perturbative deuteron
1               ! perturbative factor
1               ! deuteron cross section
-7.             ! Pt trigger
1000            ! maxmiss
3               ! radiation flag
1               ! Kt kick flag
0               ! quark embedding
7., 0.          ! embedded quark Px, Py
0., 0.          ! embedded quark x, y
1, 5., 0.       ! embedding parameters
0               ! shadowing modification
1.d0            ! shadowing factor
0               ! reaction plane randomization
0               ! reshuffle flag
EOF

    echo "    运行AMPT测试 (超时60秒)..."
    if timeout 60 ./ampt > test.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} AMPT单作业测试成功"
        
        # 检查输出文件
        if [ -d "ana" ] && [ "$(ls ana/ | wc -l)" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} 输出文件生成正常:"
            ls -la ana/
        else
            echo -e "  ${YELLOW}!${NC} 输出文件可能有问题"
        fi
    else
        echo -e "  ${RED}✗${NC} AMPT单作业测试失败，查看日志:"
        tail -20 test.log
    fi
    
    # 清理测试目录
    cleanup_test() {
        cd "$PROJECT_DIR"
        rm -rf "$TEST_DIR"
    }
    cleanup_test
else
    echo "跳过单作业测试"
fi

echo

# 7. 总结
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
echo "   ./scripts/monitor_jobs.sh status          # 查看状态"
echo "   ./scripts/monitor_jobs.sh logs JOB_ID     # 查看日志"
echo "   ./scripts/monitor_jobs.sh results         # 查看结果"
echo
echo "4. 管理作业:"
echo "   ./scripts/monitor_jobs.sh kill            # 杀死所有作业"
echo "   ./scripts/monitor_jobs.sh clean           # 清理文件"

cd "$PROJECT_DIR"