#!/bin/bash

# ==============================================================================
# AMPT 事件进度检查脚本
# 用途：检查单个或多个作业的 ampt.dat 文件中已完成的事件数量
# ==============================================================================

# 默认基础路径
DEFAULT_BASE_PATH="/storage/fdunphome/wangchunzheng/AMPT-RNC/condor_jobs/outputs"

# 事件头匹配模式
EVENT_PATTERN="^ *[0-9]+ +[0-9]+ +[0-9]{4,} +[0-9]+\.[0-9]+"

# 帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [文件路径/作业ID...]

选项:
    -h, --help      显示帮助信息
    -c, --count     只显示事件计数，不显示详细信息
    -a, --all       检查所有作业（自动扫描 outputs/ 目录）
    -w, --watch     持续监控模式（每5秒刷新）
    -s, --summary   显示汇总信息
    -b, --base      指定基础路径（默认: $DEFAULT_BASE_PATH）

参数:
    文件路径        直接指定 ampt.dat 文件路径
    作业ID          指定作业ID（如 0, 1, 2...），自动构建路径

示例:
    $0 0 1 2                        # 检查作业 0, 1, 2
    $0 -a                           # 检查所有作业
    $0 -a -c                        # 只显示所有作业的事件计数
    $0 -w -a                        # 持续监控所有作业
    $0 /path/to/ampt.dat            # 检查指定文件
    $0 -s -a                        # 显示汇总统计

EOF
}

# 检查单个文件的事件
check_single_file() {
    local file="$1"
    local show_details="$2"
    local job_label="$3"
    
    if [ ! -f "$file" ]; then
        echo "$job_label: 文件不存在"
        return 1
    fi
    
    local total_events=$(grep -c -E "$EVENT_PATTERN" "$file" 2>/dev/null || echo "0")
    local file_size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "0")
    
    if [ "$show_details" = "false" ]; then
        echo "$job_label: $total_events 个事件"
        return 0
    fi
    
    echo "=== $job_label ==="
    echo "文件: $file"
    echo "大小: $file_size"
    echo "事件数: $total_events"
    
    if [ "$total_events" -gt 0 ]; then
        echo "最新事件:"
        grep -E "$EVENT_PATTERN" "$file" | tail -1 | awk '{printf "  事件 %d: %d 个粒子, 撞击参数 %.2f\n", $1, $3, $4}'
    fi
    echo ""
}

# 获取作业路径
get_job_path() {
    local job_id="$1"
    local base_path="${2:-$DEFAULT_BASE_PATH}"
    echo "${base_path}/job_${job_id}/ana/ampt.dat"
}

# 扫描所有作业
scan_all_jobs() {
    local base_dir="${1:-$DEFAULT_BASE_PATH}"
    find "$base_dir" -name "job_*" -type d 2>/dev/null | sort -V | while read job_dir; do
        local job_id=$(basename "$job_dir" | sed 's/job_//')
        echo "$job_id"
    done
}

# 显示汇总信息
show_summary() {
    local files=("$@")
    local total_jobs=0
    local active_jobs=0
    local total_events=0
    local completed_jobs=0
    
    echo "=== 汇总统计 ==="
    
    for file in "${files[@]}"; do
        if [[ "$file" =~ job_([0-9]+) ]]; then
            job_id="${BASH_REMATCH[1]}"
        else
            job_id="unknown"
        fi
        
        total_jobs=$((total_jobs + 1))
        
        if [ -f "$file" ]; then
            local events=$(grep -c -E "$EVENT_PATTERN" "$file" 2>/dev/null || echo "0")
            total_events=$((total_events + events))
            
            if [ "$events" -gt 0 ]; then
                active_jobs=$((active_jobs + 1))
                
                # 假设200个事件为完成标准
                if [ "$events" -ge 200 ]; then
                    completed_jobs=$((completed_jobs + 1))
                fi
            fi
        fi
    done
    
    echo "总作业数: $total_jobs"
    echo "活跃作业: $active_jobs"
    echo "完成作业: $completed_jobs"
    echo "总事件数: $total_events"
    echo "平均事件: $((total_events / (active_jobs > 0 ? active_jobs : 1)))"
    echo ""
}

# 持续监控
watch_mode() {
    local files=("$@")
    local show_details="$1"
    shift
    
    echo "开始监控模式（每5秒刷新）"
    echo "按 Ctrl+C 退出"
    echo ""
    
    while true; do
        clear
        echo "=== AMPT 作业监控 - $(date) ==="
        echo ""
        
        for file in "${files[@]}"; do
            if [[ "$file" =~ job_([0-9]+) ]]; then
                job_label="作业 ${BASH_REMATCH[1]}"
            else
                job_label=$(basename "$file")
            fi
            
            check_single_file "$file" "$show_details" "$job_label"
        done
        
        show_summary "${files[@]}"
        sleep 5
    done
}

# 解析命令行参数
SHOW_DETAILS=true
CHECK_ALL=false
WATCH_MODE=false
SHOW_SUMMARY=false
BASE_PATH="$DEFAULT_BASE_PATH"
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--count)
            SHOW_DETAILS=false
            shift
            ;;
        -a|--all)
            CHECK_ALL=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -s|--summary)
            SHOW_SUMMARY=true
            shift
            ;;
        -b|--base)
            BASE_PATH="$2"
            shift 2
            ;;
        -*)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            # 判断是作业ID还是文件路径
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                # 是数字，作为作业ID处理
                FILES+=($(get_job_path "$1" "$BASE_PATH"))
            else
                # 作为文件路径处理
                FILES+=("$1")
            fi
            shift
            ;;
    esac
done

# 如果指定了 -a 选项，扫描所有作业
if [ "$CHECK_ALL" = "true" ]; then
    FILES=()
    while IFS= read -r job_id; do
        FILES+=($(get_job_path "$job_id" "$BASE_PATH"))
    done < <(scan_all_jobs "$BASE_PATH")
fi

# 如果没有指定文件，默认检查当前目录
if [ ${#FILES[@]} -eq 0 ]; then
    FILES=("ampt.dat")
fi

# 执行检查
if [ "$WATCH_MODE" = "true" ]; then
    watch_mode "$SHOW_DETAILS" "${FILES[@]}"
else
    for file in "${FILES[@]}"; do
        if [[ "$file" =~ job_([0-9]+) ]]; then
            job_label="作业 ${BASH_REMATCH[1]}"
        else
            job_label=$(basename "$file")
        fi
        
        check_single_file "$file" "$SHOW_DETAILS" "$job_label"
    done
    
    if [ "$SHOW_SUMMARY" = "true" ] && [ ${#FILES[@]} -gt 1 ]; then
        show_summary "${FILES[@]}"
    fi
fi