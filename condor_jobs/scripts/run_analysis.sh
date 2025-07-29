#!/bin/bash

# ==============================================================================
# AMPT结果分析脚本 - 支持3种强子输出文件 + 2种夸克/部分子输出文件
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/Users/wangchunzheng/works/Models/Ampt-v1.26t9b-v2.26t9b}"
JOBS_DIR="$PROJECT_DIR/condor_jobs"
RESULTS_DIR="$JOBS_DIR/outputs/results"
ANALYSIS_DIR="$JOBS_DIR/outputs/analysis"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 帮助信息
show_help() {
    cat << EOF
AMPT结果分析脚本

用法: $0 [命令] [选项]

命令:
  compile                     编译analysisAll.cxx
  analyze TYPE [PATTERN]      分析指定类型的文件
  analyze-all                 分析所有3种强子输出类型
  analyze-all-quarks          分析所有2种夸克/部分子输出类型
  analyze-all-complete        分析所有5种输出类型(强子+夸克)
  merge TYPE ISHLF ICOAL     合并同一参数组合的文件
  compare ISHLF1 ICOAL1 ISHLF2 ICOAL2  比较两个参数组合

TYPE选项:
  ampt                       最终强子freeze-out数据
  hadron-before-art          ART级联前强子数据
  hadron-before-melting      弦融化前强子数据
  zpc                        ZPC部分子级联数据 (夸克分析)
  parton-initial             初始部分子数据 (夸克分析)

PATTERN选项 (可选):
  job0-9                     只分析作业0-9
  ISHLF_0                    只分析ISHLF=0的作业
  ICOAL_1                    只分析ICOAL=1的作业

示例:
  $0 compile                                    # 编译分析程序
  $0 analyze ampt                               # 分析所有ampt文件
  $0 analyze zpc job0-9                         # 分析zpc的前10个作业
  $0 analyze-all                                # 分析所有3种强子类型
  $0 analyze-all-quarks                         # 分析所有2种夸克类型
  $0 analyze-all-complete                       # 分析所有5种类型
  $0 merge ampt 0 1                            # 合并ISHLF=0,ICOAL=1的ampt文件
  $0 compare 0 1 5 1                           # 比较(0,1)和(5,1)参数组合
EOF
}

# 编译analysisAll.cxx
compile_analysis() {
    echo -e "${BLUE}=== 编译分析程序 ===${NC}"
    
    cd "$PROJECT_DIR"
    
    # 检查ROOT环境
    if ! command -v root-config &> /dev/null; then
        echo -e "${RED}错误: ROOT环境未配置${NC}"
        exit 1
    fi
    
    echo "编译analysisAll.cxx..."
    
    # 编译命令 - 使用flexible版本
    g++ -o analysisAll_flexible analysisAll_flexible.cxx \
        $(root-config --cflags --libs) \
        -std=c++11 -O2
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}编译成功！${NC}"
        echo "可执行文件: $PROJECT_DIR/analysisAll_flexible"
    else
        echo -e "${RED}编译失败${NC}"
        exit 1
    fi
}

# 获取指定类型和模式的文件列表
get_file_list() {
    local type=$1
    local pattern=$2
    
    cd "$RESULTS_DIR"
    
    if [ -z "$pattern" ]; then
        # 所有文件
        ls ${type}_job*.root 2>/dev/null
    elif [[ $pattern =~ ^job[0-9]+-[0-9]+$ ]]; then
        # 范围模式，如 job0-9
        local start=$(echo $pattern | sed 's/job\([0-9]\+\)-[0-9]\+/\1/')
        local end=$(echo $pattern | sed 's/job[0-9]\+-\([0-9]\+\)/\1/')
        
        for i in $(seq $start $end); do
            if [ -f "${type}_job${i}.root" ]; then
                echo "${type}_job${i}.root"
            fi
        done
    elif [[ $pattern == ISHLF_* ]]; then
        # ISHLF模式
        local ishlf_val=$(echo $pattern | sed 's/ISHLF_//')
        grep -l "ZPC前打乱: $ishlf_val" job_*_summary.txt | while read summary; do
            local job_id=$(echo $summary | sed 's/job_\([0-9]\+\)_summary.txt/\1/')
            if [ -f "${type}_job${job_id}.root" ]; then
                echo "${type}_job${job_id}.root"
            fi
        done
        
    elif [[ $pattern == ICOAL_* ]]; then
        # ICOAL模式
        local icoal_val=$(echo $pattern | sed 's/ICOAL_//')
        grep -l "聚合方式: $icoal_val" job_*_summary.txt | while read summary; do
            local job_id=$(echo $summary | sed 's/job_\([0-9]\+\)_summary.txt/\1/')
            if [ -f "${type}_job${job_id}.root" ]; then
                echo "${type}_job${job_id}.root"
            fi
        done
    else
        echo -e "${RED}未知模式: $pattern${NC}"
        return 1
    fi
}

# 分析指定类型的文件
analyze_type() {
    local type=$1
    local pattern=$2
    
    echo -e "${BLUE}=== 分析 $type 类型文件 ===${NC}"
    
    # 检查analysisAll_flexible程序
    if [ ! -f "$PROJECT_DIR/analysisAll_flexible" ]; then
        echo -e "${YELLOW}分析程序不存在，先编译...${NC}"
        compile_analysis
    fi
    
    # 创建分析输出目录
    mkdir -p "$ANALYSIS_DIR/$type"
    
    # 获取文件列表
    file_list=$(get_file_list "$type" "$pattern")
    
    if [ -z "$file_list" ]; then
        echo -e "${RED}未找到匹配的文件${NC}"
        return 1
    fi
    
    # 创建文件列表
    list_file="$ANALYSIS_DIR/${type}_${pattern:-all}.list"
    echo "$file_list" | while read file; do
        echo "$RESULTS_DIR/$file"
    done > "$list_file"
    
    file_count=$(wc -l < "$list_file")
    echo "找到 $file_count 个$type文件"
    
    # 运行分析
    output_file="$ANALYSIS_DIR/${type}_${pattern:-all}_analysis.root"
    echo "运行分析: $output_file"
    
    cd "$PROJECT_DIR"
    # 使用flexible版本，自动检测格式
    ./analysisAll_flexible "$list_file" "$output_file" auto
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}分析完成: $output_file${NC}"
        
        # 生成分析摘要
        cat > "$ANALYSIS_DIR/${type}_${pattern:-all}_summary.txt" << EOF
分析摘要
========
类型: $type
模式: ${pattern:-all}
输入文件数: $file_count
输出文件: $output_file
分析时间: $(date)

输入文件列表:
$(cat "$list_file")
EOF
        
    else
        echo -e "${RED}分析失败${NC}"
        return 1
    fi
}

# 分析所有3种强子类型
analyze_all() {
    echo -e "${BLUE}=== 分析所有强子输出类型 ===${NC}"
    
    local types=("ampt" "hadron-before-art" "hadron-before-melting")
    
    for type in "${types[@]}"; do
        echo
        analyze_type "$type"
        echo
    done
    
    echo -e "${GREEN}所有强子类型分析完成！${NC}"
    echo "结果保存在: $ANALYSIS_DIR/"
}

# 分析所有2种夸克/部分子类型
analyze_all_quarks() {
    echo -e "${BLUE}=== 分析所有夸克/部分子输出类型 ===${NC}"
    
    local types=("zpc" "parton-initial")
    
    for type in "${types[@]}"; do
        echo
        analyze_type "$type"
        echo
    done
    
    echo -e "${GREEN}所有夸克类型分析完成！${NC}"
    echo "结果保存在: $ANALYSIS_DIR/"
}

# 分析所有5种输出类型
analyze_all_complete() {
    echo -e "${BLUE}=== 分析所有输出类型（强子+夸克）===${NC}"
    
    echo -e "${YELLOW}步骤1: 分析强子数据${NC}"
    analyze_all
    
    echo
    echo -e "${YELLOW}步骤2: 分析夸克/部分子数据${NC}"
    analyze_all_quarks
    
    echo
    echo -e "${GREEN}完整分析完成！${NC}"
    echo "强子分析结果: $ANALYSIS_DIR/ampt/, $ANALYSIS_DIR/hadron-before-art/, $ANALYSIS_DIR/hadron-before-melting/"
    echo "夸克分析结果: $ANALYSIS_DIR/zpc/, $ANALYSIS_DIR/parton-initial/"
}

# 合并同一参数组合的文件
merge_files() {
    local type=$1
    local ishlf=$2
    local icoal=$3
    
    echo -e "${BLUE}=== 合并参数组合 ISHLF=$ishlf, ICOAL=$icoal 的$type文件 ===${NC}"
    
    # 创建合并目录
    mkdir -p "$ANALYSIS_DIR/merged"
    
    # 找到匹配参数的作业
    cd "$RESULTS_DIR"
    job_ids=()
    
    for summary in job_*_summary.txt; do
        if grep -q "ZPC前打乱: $ishlf" "$summary" && grep -q "聚合方式: $icoal" "$summary"; then
            job_id=$(echo $summary | sed 's/job_\([0-9]\+\)_summary.txt/\1/')
            if [ -f "${type}_job${job_id}.root" ]; then
                job_ids+=($job_id)
            fi
        fi
    done
    
    if [ ${#job_ids[@]} -eq 0 ]; then
        echo -e "${RED}未找到匹配的文件${NC}"
        return 1
    fi
    
    echo "找到 ${#job_ids[@]} 个匹配的作业: ${job_ids[*]}"
    
    # 创建合并文件列表
    list_file="$ANALYSIS_DIR/merged/${type}_ISHLF${ishlf}_ICOAL${icoal}.list"
    > "$list_file"
    
    for job_id in "${job_ids[@]}"; do
        echo "$RESULTS_DIR/${type}_job${job_id}.root" >> "$list_file"
    done
    
    # 运行合并分析
    output_file="$ANALYSIS_DIR/merged/${type}_ISHLF${ishlf}_ICOAL${icoal}_merged.root"
    
    cd "$PROJECT_DIR"
    # 使用flexible版本，自动检测格式
    ./analysisAll_flexible "$list_file" "$output_file" auto
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}合并分析完成: $output_file${NC}"
        
        # 计算总事件数
        total_events=$((${#job_ids[@]} * 500))
        
        cat > "$ANALYSIS_DIR/merged/${type}_ISHLF${ishlf}_ICOAL${icoal}_info.txt" << EOF
合并分析信息
============
参数组合: ISHLF=$ishlf, ICOAL=$icoal
文件类型: $type
作业数量: ${#job_ids[@]}
总事件数: $total_events
输出文件: $output_file
合并时间: $(date)

包含的作业ID:
${job_ids[*]}
EOF
        
    else
        echo -e "${RED}合并分析失败${NC}"
        return 1
    fi
}

# 比较两个参数组合
compare_parameters() {
    local ishlf1=$1 icoal1=$2 ishlf2=$3 icoal2=$4
    
    echo -e "${BLUE}=== 比较参数组合 ===${NC}"
    echo "组合1: ISHLF=$ishlf1, ICOAL=$icoal1"
    echo "组合2: ISHLF=$ishlf2, ICOAL=$icoal2"
    
    # 检查合并文件是否存在
    local file1="$ANALYSIS_DIR/merged/ampt_ISHLF${ishlf1}_ICOAL${icoal1}_merged.root"
    local file2="$ANALYSIS_DIR/merged/ampt_ISHLF${ishlf2}_ICOAL${icoal2}_merged.root"
    
    if [ ! -f "$file1" ]; then
        echo "生成组合1的合并文件..."
        merge_files "ampt" "$ishlf1" "$icoal1"
    fi
    
    if [ ! -f "$file2" ]; then
        echo "生成组合2的合并文件..."
        merge_files "ampt" "$ishlf2" "$icoal2"
    fi
    
    # 这里可以添加比较逻辑，比如提取关键物理量进行对比
    echo -e "${GREEN}对比文件已准备好：${NC}"
    echo "文件1: $file1"
    echo "文件2: $file2"
    
    echo "可以使用ROOT进行进一步比较分析"
}

# 主函数
main() {
    case "${1:-help}" in
        "compile")
            compile_analysis
            ;;
        "analyze")
            if [ -z "$2" ]; then
                echo -e "${RED}错误: 请指定分析类型${NC}"
                show_help
                exit 1
            fi
            analyze_type "$2" "$3"
            ;;
        "analyze-all")
            analyze_all
            ;;
        "analyze-all-quarks")
            analyze_all_quarks
            ;;
        "analyze-all-complete")
            analyze_all_complete
            ;;
        "merge")
            if [ -z "$4" ]; then
                echo -e "${RED}错误: 请提供完整参数 TYPE ISHLF ICOAL${NC}"
                show_help
                exit 1
            fi
            merge_files "$2" "$3" "$4"
            ;;
        "compare")
            if [ -z "$5" ]; then
                echo -e "${RED}错误: 请提供完整参数 ISHLF1 ICOAL1 ISHLF2 ICOAL2${NC}"
                show_help
                exit 1
            fi
            compare_parameters "$2" "$3" "$4" "$5"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"