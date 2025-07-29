#!/usr/bin/env python3
"""
AMPT任务参数生成脚本
用于生成不同的ISHLF和ICOAL_METHOD参数组合
"""

import os
import sys
from itertools import product

def generate_job_params(output_file="config/job_params.txt", jobs_per_combo=1):
    """生成作业参数文件
    
    Args:
        output_file: 输出文件路径
        jobs_per_combo: 每个参数组合生成的任务数 (每个任务500个事件)
    """
    
    # 定义参数范围
    ishlf_values = [0, 5]                  # ZPC前打乱参数: 0=不打乱, 5=u+d+s夸克打乱
    icoal_values = [1, 2, 3]              # 聚合方式参数
    
    # 参数说明
    ishlf_desc = {
        0: "不打乱",
        1: "d夸克打乱", 
        2: "u夸克打乱",
        3: "s夸克打乱",
        4: "u+d夸克打乱",
        5: "u+d+s夸克打乱",
        6: "全部打乱"
    }
    
    icoal_desc = {
        1: "经典聚合",
        2: "BM竞争聚合", 
        3: "随机聚合"
    }
    
    # 创建输出目录
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write("# AMPT作业参数配置文件 - 自动生成\n")
        f.write("# 格式: ISHLF ICOAL_METHOD\n")
        f.write("# ISHLF: 0=不打乱, 1=d夸克, 2=u夸克, 3=s夸克, 4=u+d夸克, 5=u+d+s夸克, 6=全部打乱\n")
        f.write("# ICOAL_METHOD: 1=经典聚合, 2=BM竞争聚合, 3=随机聚合\n")
        total_jobs = len(ishlf_values) * len(icoal_values) * jobs_per_combo
        f.write(f"# 总共 {total_jobs} 个作业 ({len(ishlf_values) * len(icoal_values)}个参数组合 × {jobs_per_combo}个重复)\n")
        f.write(f"# 每个作业500个事件，总计 {total_jobs * 500} 个事件\n\n")
        
        job_id = 0
        for ishlf, icoal in product(ishlf_values, icoal_values):
            for repeat in range(jobs_per_combo):
                if jobs_per_combo > 1:
                    f.write(f"# Job {job_id:03d}: {ishlf_desc[ishlf]} + {icoal_desc[icoal]} (重复 {repeat+1}/{jobs_per_combo})\n")
                else:
                    f.write(f"# Job {job_id:03d}: {ishlf_desc[ishlf]} + {icoal_desc[icoal]}\n")
                f.write(f"{ishlf} {icoal}\n")
                job_id += 1
    
    print(f"生成了 {job_id} 个作业参数组合")
    print(f"输出文件: {output_file}")
    return job_id

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

def generate_subset_params(mode="quick", output_file=None, jobs_per_combo=1):
    """生成特定子集的参数组合"""
    
    if output_file is None:
        output_file = f"config/job_params_{mode}.txt"
    
    if mode == "quick":
        # 快速测试: 只测试关键组合 (只用0和5)
        params = [
            (0, 1),  # 基准: 不打乱 + 经典聚合
            (5, 1),  # u+d+s打乱 + 经典聚合
            (0, 2),  # 不打乱 + BM竞争聚合
            (0, 3),  # 不打乱 + 随机聚合
            (5, 2),  # u+d+s打乱 + BM竞争聚合
            (5, 3),  # u+d+s打乱 + 随机聚合
        ]
    elif mode == "reshuffle":
        # 只测试打乱效应 (固定经典聚合, 只用0和5)
        params = [(i, 1) for i in [0, 5]]
    elif mode == "coalescence":
        # 只测试聚合方式 (固定不打乱)
        params = [(0, i) for i in [1, 2, 3]]
    else:
        print(f"未知模式: {mode}")
        return 0
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write(f"# AMPT作业参数配置文件 - {mode}测试\n")
        f.write("# 格式: ISHLF ICOAL_METHOD\n")
        total_jobs = len(params) * jobs_per_combo
        f.write(f"# 总共 {total_jobs} 个作业 ({len(params)}个参数组合 × {jobs_per_combo}个重复)\n")
        f.write(f"# 每个作业500个事件，总计 {total_jobs * 500} 个事件\n\n")
        
        job_id = 0
        for ishlf, icoal in params:
            for repeat in range(jobs_per_combo):
                if jobs_per_combo > 1:
                    f.write(f"# Job {job_id:03d}: ISHLF={ishlf}, ICOAL={icoal} (重复 {repeat+1}/{jobs_per_combo})\n")
                else:
                    f.write(f"# Job {job_id:03d}: ISHLF={ishlf}, ICOAL={icoal}\n")
                f.write(f"{ishlf} {icoal}\n")
                job_id += 1
    
    print(f"生成了 {job_id} 个{mode}测试作业参数")
    print(f"输出文件: {output_file}")
    return job_id

def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("用法:")
        print("  python generate_jobs.py all [N]                # 生成所有组合，每个组合N个重复 (默认1)")
        print("  python generate_jobs.py quick [N]              # 快速测试，每个组合N个重复 (默认1)")
        print("  python generate_jobs.py reshuffle [N]          # 打乱测试，每个组合N个重复 (默认1)")
        print("  python generate_jobs.py coalescence [N]        # 聚合测试，每个组合N个重复 (默认1)")
        print("  python generate_jobs.py custom 0,5 1,2,3       # 自定义组合")
        print()
        print("示例:")
        print("  python generate_jobs.py all 10                 # 6个参数组合，每个10个重复 = 60个任务 = 30000个事件")
        print("  python generate_jobs.py quick 5                # 6个参数组合，每个5个重复 = 30个任务 = 15000个事件")
        return
    
    mode = sys.argv[1]
    jobs_per_combo = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 1
    
    if mode == "all":
        generate_job_params(jobs_per_combo=jobs_per_combo)
    elif mode in ["quick", "reshuffle", "coalescence"]:
        generate_subset_params(mode, jobs_per_combo=jobs_per_combo)
    elif mode == "custom":
        if len(sys.argv) != 4:
            print("自定义模式用法: python generate_jobs.py custom ISHLF_LIST ICOAL_LIST")
            print("示例: python generate_jobs.py custom 0,5 1,2,3")
            return
        
        ishlf_list = [int(x) for x in sys.argv[2].split(',')]
        icoal_list = [int(x) for x in sys.argv[3].split(',')]
        generate_custom_params(ishlf_list, icoal_list)
    else:
        print(f"未知模式: {mode}")

if __name__ == "__main__":
    main()