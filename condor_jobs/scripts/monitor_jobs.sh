#!/bin/bash

# ==============================================================================
# AMPT Condor作业监控和管理脚本
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/storage/fdunphome/wangchunzheng/AMPT-RNC}"
JOBS_DIR="$PROJECT_DIR/condor_jobs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
AMPT Condor作业监控和管理工具

用法: $0 [命令] [选项]

命令:
  status              显示作业状态总览
  list                列出所有作业详细信息
  logs JOB_ID         查看指定作业的日志
  results             显示结果文件统计
  clean               清理日志和临时文件
  submit [MODE]       提交作业 (默认使用现有config/job_params.txt)
  kill                杀死所有用户的condor作业
  watch               实时监控作业状态
  summary             生成完整的作业摘要报告

参数选项 (用于submit):
  N                   每个参数组合的重复次数 (默认1)

示例:
  $0 status                    # 查看作业状态
  $0 submit 200                # 提交作业(每个参数组合200个重复)
  $0 logs 5                    # 查看作业5的日志
  $0 results                   # 查看结果统计
EOF
}

# 检查condor是否可用
check_condor() {
    if ! command -v condor_q &> /dev/null; then
        echo -e "${RED}错误: HTCondor未安装或不在PATH中${NC}"
        exit 1
    fi
}

# 显示作业状态
show_status() {
    echo -e "${BLUE}=== AMPT Condor作业状态 ===${NC}"
    echo
    
    # 总体状态
    echo "总体作业状态:"
    condor_q -nobatch -totals 2>/dev/null || echo "无作业运行"
    echo
    
    # 用户作业详情
    if condor_q -nobatch 2>/dev/null | grep -q "$(whoami)"; then
        echo "详细作业状态:"
        condor_q -nobatch
    else
        echo "当前无运行中的作业"
    fi
    echo
    
    # 本地文件状态
    if [ -d "$JOBS_DIR/outputs" ]; then
        echo "本地输出文件统计:"
        echo "  日志文件: $(find "$JOBS_DIR/outputs/logs" -name "*.out" 2>/dev/null | wc -l) 个"
        echo "  结果文件: $(find "$JOBS_DIR/outputs/results" -name "*.root" 2>/dev/null | wc -l) 个ROOT文件"
        echo "  摘要文件: $(find "$JOBS_DIR/outputs/results" -name "*_summary.txt" 2>/dev/null | wc -l) 个"
    fi
}

# 列出作业详情
list_jobs() {
    echo -e "${BLUE}=== 作业详细列表 ===${NC}"
    
    if condor_q -nobatch -format "%d " ClusterId -format "%d " ProcId -format "%s " JobStatus -format "%s\n" Args 2>/dev/null | grep -q .; then
        echo "运行中的作业:"
        printf "%-8s %-8s %-10s %s\n" "集群ID" "进程ID" "状态" "参数"
        echo "----------------------------------------"
        condor_q -nobatch -format "%-8d " ClusterId -format "%-8d " ProcId -format "%-10s " JobStatus -format "%s\n" Args 2>/dev/null
    else
        echo "无运行中的作业"
    fi
    echo
    
    # 显示最近完成的作业
    if [ -d "$JOBS_DIR/outputs/results" ]; then
        echo "最近完成的作业 (根据结果文件):"
        find "$JOBS_DIR/outputs/results" -name "*_summary.txt" -exec basename {} \; | sed 's/_summary.txt//' | sort -V | tail -10
    fi
}

# 查看作业日志
show_logs() {
    local job_id=$1
    if [ -z "$job_id" ]; then
        echo -e "${RED}错误: 请指定作业ID${NC}"
        exit 1
    fi
    
    local log_dir="$JOBS_DIR/outputs/logs"
    
    echo -e "${BLUE}=== 作业 $job_id 日志 ===${NC}"
    
    # 输出日志
    if [ -f "$log_dir/job_${job_id}.out" ]; then
        echo -e "${GREEN}标准输出:${NC}"
        cat "$log_dir/job_${job_id}.out"
        echo
    fi
    
    # 错误日志
    if [ -f "$log_dir/job_${job_id}.err" ]; then
        echo -e "${YELLOW}错误输出:${NC}"
        cat "$log_dir/job_${job_id}.err"
        echo
    fi
    
    # Condor日志
    if [ -f "$log_dir/job_${job_id}.log" ]; then
        echo -e "${BLUE}Condor日志:${NC}"
        tail -20 "$log_dir/job_${job_id}.log"
    fi
}

# 显示结果统计
show_results() {
    echo -e "${BLUE}=== 结果文件统计 ===${NC}"
    
    local results_dir="$JOBS_DIR/outputs/results"
    if [ ! -d "$results_dir" ]; then
        echo "结果目录不存在"
        return
    fi
    
    cd "$results_dir"
    
    echo "ROOT文件统计:"
    for type in ampt zpc parton-initial hadron-before-art hadron-before-melting; do
        count=$(ls ${type}_job*.root 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            total_size=$(ls -l ${type}_job*.root 2>/dev/null | awk '{sum += $5} END {print sum/1024/1024}')
            printf "  %-20s: %3d 个文件, %.1f MB\n" "$type" "$count" "$total_size"
        fi
    done
    echo
    
    echo "作业摘要文件:"
    summary_count=$(ls *_summary.txt 2>/dev/null | wc -l)
    echo "  摘要文件: $summary_count 个"
    
    if [ "$summary_count" -gt 0 ]; then
        echo "  最新完成的作业:"
        ls -t *_summary.txt | head -5 | while read file; do
            job_id=$(echo "$file" | sed 's/job_//' | sed 's/_summary.txt//')
            completion_time=$(grep "完成时间" "$file" | cut -d: -f2- | xargs)
            echo "    作业$job_id: $completion_time"
        done
    fi
}

# 清理文件
clean_files() {
    echo -e "${YELLOW}清理临时文件和日志...${NC}"
    
    read -p "确定要清理所有日志和临时文件吗? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -rf "$JOBS_DIR/outputs/logs"/*
        rm -rf "$JOBS_DIR/outputs/job_"*
        echo "清理完成"
    else
        echo "取消清理"
    fi
}

# 提交作业
submit_jobs() {
    local mode=${1:-"default"}
    
    echo -e "${BLUE}=== 提交AMPT作业 ===${NC}"
    
    cd "$JOBS_DIR"
    
    # 生成参数文件
    if [ "$mode" != "default" ]; then
        echo "生成参数文件（重复${mode}次）..."
        python3 scripts/generate_jobs.py "$mode"
    fi
    
    # 检查参数文件
    if [ ! -f "config/job_params.txt" ]; then
        echo -e "${RED}错误: 参数文件 config/job_params.txt 不存在${NC}"
        echo "请先运行: python3 scripts/generate_jobs.py"
        exit 1
    fi
    
    # 创建输出目录
    mkdir -p outputs/{logs,results}
    
    # 显示将要提交的作业数量
    job_count=$(grep -v "^#" config/job_params.txt | grep -v "^$" | wc -l)
    echo "将要提交 $job_count 个作业"
    
    # 显示前几个作业参数
    echo "作业参数预览:"
    head -10 config/job_params.txt | grep -v "^#"
    
    read -p "确定提交吗? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        condor_submit ampt.sub
        echo -e "${GREEN}作业提交完成${NC}"
    else
        echo "取消提交"
    fi
}

# 杀死所有作业
kill_jobs() {
    echo -e "${YELLOW}杀死所有Condor作业...${NC}"
    
    if condor_q -nobatch 2>/dev/null | grep -q "$(whoami)"; then
        read -p "确定要杀死所有作业吗? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            condor_rm "$(whoami)"
            echo "所有作业已杀死"
        else
            echo "取消操作"
        fi
    else
        echo "无作业需要杀死"
    fi
}

# 实时监控
watch_jobs() {
    echo -e "${BLUE}=== 实时监控作业状态 (按Ctrl+C退出) ===${NC}"
    
    while true; do
        clear
        show_status
        echo "刷新时间: $(date)"
        sleep 10
    done
}

# 生成摘要报告
generate_summary() {
    echo -e "${BLUE}=== 生成作业摘要报告 ===${NC}"
    
    local report_file="$JOBS_DIR/outputs/ampt_jobs_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "AMPT Condor作业摘要报告"
        echo "======================="
        echo "生成时间: $(date)"
        echo "项目目录: $PROJECT_DIR"
        echo
        
        echo "## 作业状态"
        condor_q -nobatch -totals 2>/dev/null || echo "无运行中的作业"
        echo
        
        echo "## 结果文件统计"
        show_results
        echo
        
        echo "## 最近10个完成的作业"
        if [ -d "$JOBS_DIR/outputs/results" ]; then
            find "$JOBS_DIR/outputs/results" -name "*_summary.txt" -exec basename {} \; | \
            sed 's/_summary.txt//' | sort -V | tail -10
        fi
        
    } > "$report_file"
    
    echo "报告已生成: $report_file"
}

# 主函数
main() {
    check_condor
    
    case "${1:-status}" in
        "status")
            show_status
            ;;
        "list")
            list_jobs
            ;;
        "logs")
            show_logs "$2"
            ;;
        "results")
            show_results
            ;;
        "clean")
            clean_files
            ;;
        "submit")
            submit_jobs "$2"
            ;;
        "kill")
            kill_jobs
            ;;
        "watch")
            watch_jobs
            ;;
        "summary")
            generate_summary
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