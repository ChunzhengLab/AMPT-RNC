#!/bin/bash

# ==============================================================================
# 智能SLURM作业提交脚本 - 自动检测参数数量
# ==============================================================================

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMPT SLURM 智能提交 ===${NC}"

# 检查参数文件
PARAM_FILE="config/job_params.txt"
if [ ! -f "$PARAM_FILE" ]; then
    echo "错误: 找不到参数文件 $PARAM_FILE"
    echo "请先运行: python3 scripts/generate_jobs.py"
    exit 1
fi

# 自动检测参数数量（忽略空行和注释）
PARAM_COUNT=$(grep -v '^#' "$PARAM_FILE" | grep -v '^[[:space:]]*$' | wc -l)
MAX_INDEX=$((PARAM_COUNT - 1))

echo -e "${YELLOW}参数文件分析:${NC}"
echo "  文件: $PARAM_FILE"
echo "  有效参数行数: $PARAM_COUNT"
echo "  数组范围: 0-$MAX_INDEX"
echo

# 显示参数预览
echo -e "${YELLOW}参数预览:${NC}"
grep -v '^#' "$PARAM_FILE" | grep -v '^[[:space:]]*$' | nl -v0 | while read num params; do
    ishlf=$(echo $params | awk '{print $1}')
    icoal=$(echo $params | awk '{print $2}')
    echo "  任务$num: ISHLF=$ishlf, ICOAL_METHOD=$icoal"
done
echo

# 计算总事件数（假设每个任务100个事件）
TOTAL_EVENTS=$((PARAM_COUNT * 100))
echo -e "${YELLOW}预期结果:${NC}"
echo "  总任务数: $PARAM_COUNT"
echo "  每任务事件数: 100"
echo "  总事件数: $TOTAL_EVENTS"
echo

# 询问并发限制
echo -n "请输入并发限制 (默认: min($PARAM_COUNT, 100)): "
read CONCURRENT
if [ -z "$CONCURRENT" ]; then
    CONCURRENT=$(( PARAM_COUNT < 100 ? PARAM_COUNT : 100 ))
fi

# 构建提交命令
ARRAY_SPEC="0-${MAX_INDEX}%${CONCURRENT}"
SUBMIT_CMD="sbatch --array=$ARRAY_SPEC ampt.sbatch"

echo -e "${YELLOW}提交命令:${NC}"
echo "  $SUBMIT_CMD"
echo

# 确认提交
echo -n "确认提交? (y/N): "
read CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}正在提交作业...${NC}"
    $SUBMIT_CMD
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 作业提交成功！${NC}"
        echo
        echo "监控命令:"
        echo "  squeue -u \$USER"
        echo "  watch -n 30 'squeue -u \$USER'"
        echo
        echo "结果整理:"
        echo "  bash scripts/organize_results.sh"
    else
        echo "✗ 作业提交失败"
        exit 1
    fi
else
    echo "取消提交"
fi