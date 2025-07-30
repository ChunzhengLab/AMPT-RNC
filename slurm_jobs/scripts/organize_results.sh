#!/bin/bash

# ==============================================================================
# 结果文件整理脚本 - 按参数组合分组
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/home/chunzheng/AMPT-RNC}"
RESULTS_DIR="$PROJECT_DIR/slurm_jobs/outputs/results"
ORGANIZED_DIR="$PROJECT_DIR/slurm_jobs/outputs/organized"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 整理AMPT结果文件 ===${NC}"

if [ ! -d "$RESULTS_DIR" ]; then
    echo "错误: 结果目录 $RESULTS_DIR 不存在"
    exit 1
fi

# 创建整理后的目录结构
mkdir -p "$ORGANIZED_DIR"

echo "分析作业参数..."

# 遍历所有摘要文件，按参数分组
for summary_file in "$RESULTS_DIR"/job_*_summary.txt; do
    if [ ! -f "$summary_file" ]; then
        continue
    fi
    
    # 提取作业ID
    job_id=$(basename "$summary_file" _summary.txt | sed 's/job_//')
    
    # 从摘要文件中提取参数
    ishlf=$(grep "ZPC前打乱:" "$summary_file" | awk '{print $2}')
    icoal=$(grep "聚合方式:" "$summary_file" | awk '{print $2}')
    
    if [ -z "$ishlf" ] || [ -z "$icoal" ]; then
        echo "警告: 无法从 $summary_file 提取参数"
        continue
    fi
    
    # 创建参数目录
    param_dir="$ORGANIZED_DIR/ISHLF_${ishlf}_ICOAL_${icoal}"
    mkdir -p "$param_dir"
    
    # 移动相关文件
    echo "整理作业 $job_id (ISHLF=$ishlf, ICOAL=$icoal)..."
    
    # 移动所有相关文件
    for file in "$RESULTS_DIR"/*job${job_id}.*; do
        if [ -f "$file" ]; then
            cp "$file" "$param_dir/"
        fi
    done
    
    # 移动摘要文件
    cp "$summary_file" "$param_dir/"
done

echo
echo -e "${GREEN}文件整理完成！${NC}"
echo

# 显示整理结果
echo "按参数组合整理的结果:"
for param_dir in "$ORGANIZED_DIR"/ISHLF_*; do
    if [ -d "$param_dir" ]; then
        param_name=$(basename "$param_dir")
        file_count=$(ls "$param_dir"/*.root 2>/dev/null | wc -l)
        job_count=$(ls "$param_dir"/job_*_summary.txt 2>/dev/null | wc -l)
        
        # 解析参数名称
        ishlf=$(echo "$param_name" | sed 's/ISHLF_\([0-9]\)_ICOAL_[0-9]/\1/')
        icoal=$(echo "$param_name" | sed 's/ISHLF_[0-9]_ICOAL_\([0-9]\)/\1/')
        
        # 参数描述
        case $ishlf in
            0) ishlf_desc="不打乱" ;;
            5) ishlf_desc="u+d+s打乱" ;;
            *) ishlf_desc="未知" ;;
        esac
        
        case $icoal in
            1) icoal_desc="经典聚合" ;;
            2) icoal_desc="BM竞争聚合" ;;
            3) icoal_desc="随机聚合" ;;
            *) icoal_desc="未知" ;;
        esac
        
        echo "  $param_name: $job_count个作业, $file_count个ROOT文件"
        echo "    └─ $ishlf_desc + $icoal_desc (总计 $((job_count * 200)) 个事件)"
    fi
done

echo
echo "数据分析示例:"
echo "# 分析特定参数组合的所有文件"
echo "cd $ORGANIZED_DIR/ISHLF_0_ICOAL_1"
echo "ls *.root"
echo ""
echo "# ROOT中合并同一参数组合的数据"
echo "root -l"
echo "TChain *chain = new TChain(\"ampt\");"
echo "chain->Add(\"$ORGANIZED_DIR/ISHLF_0_ICOAL_1/ampt_job*.root\");"
echo "chain->GetEntries()  // 查看总事件数"