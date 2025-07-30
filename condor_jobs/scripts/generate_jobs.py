#!/usr/bin/env python3
"""
AMPT任务参数生成脚本
用于生成不同的ISHLF和ICOAL_METHOD参数组合
"""

import os
import sys
from itertools import product


def generate_custom_params(ishlf_list, icoal_list, output_file="config/job_params_custom.txt"):
    """生成自定义参数组合"""
    
    if len(ishlf_list) != len(icoal_list):
        print("错误: ISHLF和ICOAL_METHOD列表长度不匹配")
        return 0
        
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write("# AMPT作业参数配置文件 - 自定义组合\n")
        f.write("# 格式: ISHLF ICOAL_METHOD\n\n")
        
        for i, (ishlf, icoal) in enumerate(zip(ishlf_list, icoal_list)):
            f.write(f"# Job {i:03d}\n")
            f.write(f"{ishlf} {icoal}\n")
    
    print(f"生成了 {len(ishlf_list)} 个自定义作业参数")
    print(f"输出文件: {output_file}")
    return len(ishlf_list)

def generate_params(output_file=None, jobs_per_combo=1):
    """生成AMPT作业参数组合"""
    
    if output_file is None:
        output_file = "config/job_params.txt"
    
    # AMPT参数组合: 关键的打乱和聚合方法组合
    params = [
        (0, 1),  # 基准: 不打乱 + 经典聚合
        (5, 1),  # u+d+s打乱 + 经典聚合
        (0, 2),  # 不打乱 + BM竞争聚合
        (0, 3),  # 不打乱 + 随机聚合
        (5, 2),  # u+d+s打乱 + BM竞争聚合
        (5, 3),  # u+d+s打乱 + 随机聚合
    ]
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write("# AMPT作业参数配置文件\n")
        f.write("# 格式: ISHLF ICOAL_METHOD\n")
        total_jobs = len(params) * jobs_per_combo
        f.write(f"# 总共 {total_jobs} 个作业 ({len(params)}个参数组合 × {jobs_per_combo}个重复)\n")
        f.write(f"# 每个作业200个事件，总计 {total_jobs * 200} 个事件\n\n")
        
        job_id = 0
        for ishlf, icoal in params:
            for repeat in range(jobs_per_combo):
                if jobs_per_combo > 1:
                    f.write(f"# Job {job_id:03d}: ISHLF={ishlf}, ICOAL={icoal} (重复 {repeat+1}/{jobs_per_combo})\n")
                else:
                    f.write(f"# Job {job_id:03d}: ISHLF={ishlf}, ICOAL={icoal}\n")
                f.write(f"{ishlf} {icoal}\n")
                job_id += 1
    
    print(f"生成了 {job_id} 个AMPT作业参数")
    print(f"输出文件: {output_file}")
    return job_id

def main():
    """主函数"""
    if len(sys.argv) > 2:
        print("用法:")
        print("  python generate_jobs.py [N]                    # 生成AMPT作业参数，每个组合N个重复 (默认1)")
        print()
        print("示例:")
        print("  python generate_jobs.py                        # 6个参数组合，每个1个重复 = 6个任务 = 1200个事件") 
        print("  python generate_jobs.py 500                    # 6个参数组合，每个500个重复 = 3000个任务 = 600000个事件")
        return
    
    jobs_per_combo = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1
    
    # 生成AMPT作业参数
    generate_params(jobs_per_combo=jobs_per_combo)

if __name__ == "__main__":
    main()