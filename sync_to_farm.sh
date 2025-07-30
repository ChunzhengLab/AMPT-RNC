#!/bin/bash

# ==============================================================================
# 同步AMPT-RNC项目到farm服务器
# 排除: *.dat, *.root文件和.git目录
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
LOCAL_DIR="$(dirname "$0")"  # 当前脚本所在目录
REMOTE_HOST="hirg"
REMOTE_DIR="/storage/fdunphome/wangchunzheng/AMPT-RNC"

echo -e "${BLUE}=== 同步到farm服务器 ===${NC}"
echo "本地目录: $LOCAL_DIR"
echo "远程目录: $REMOTE_HOST:$REMOTE_DIR"
echo

# 检查ssh连接
echo -e "${YELLOW}检查SSH连接...${NC}"
if ssh -o ConnectTimeout=5 $REMOTE_HOST "echo '连接成功'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} SSH连接正常"
else
    echo -e "${RED}✗${NC} 无法连接到$REMOTE_HOST"
    exit 1
fi

# 创建远程目录（如果不存在）
echo -e "${YELLOW}检查远程目录...${NC}"
ssh $REMOTE_HOST "mkdir -p $REMOTE_DIR"

# 执行同步
echo -e "${YELLOW}开始同步文件...${NC}"
echo "排除文件类型: *.dat, *.root, .git/"
echo

rsync -avz --progress \
    --exclude='*.dat' \
    --exclude='*.root' \
    --exclude='.git/' \
    --exclude='.git*' \
    --exclude='*.o' \
    --exclude='*.pyc' \
    --exclude='__pycache__/' \
    --exclude='*.log' \
    --exclude='*.out' \
    --exclude='*.err' \
    --exclude='condor_jobs/outputs/' \
    --exclude='condor_jobs/results/' \
    --exclude='ana/' \
    --exclude='ampt' \
    --exclude='analysisAll' \
    --exclude='analysisAll_flexible' \
    --exclude='exec' \
    --exclude='*.tmp' \
    --exclude='.DS_Store' \
    "$LOCAL_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"

# 检查同步结果
if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}✓ 同步完成！${NC}"
    
    # 显示远程目录大小
    echo
    echo "远程目录信息:"
    ssh $REMOTE_HOST "cd $REMOTE_DIR && du -sh . && echo '文件数量:' && find . -type f | wc -l"
else
    echo
    echo -e "${RED}✗ 同步失败！${NC}"
    exit 1
fi

echo
echo -e "${BLUE}=== 同步完成 ===${NC}"
echo "提示: 同步后需要在服务器上重新编译程序"
echo "  ssh $REMOTE_HOST"
echo "  cd $REMOTE_DIR"
echo "  ./condor_jobs/scripts/prepare_binaries.sh"