# AMPT B/M Competition 算法实现 - 下一步计划

## 当前状态总结

### 已完成的工作 ✅

1. **模块化coalescence系统已建立**
   - 创建了czcoal.f模块
   - 实现了方法选择接口 (icoal_method: 1=classic, 2=BM_comp)
   - 添加了drbmRatio参数支持
   - 修复了所有common block类型声明问题
   - 系统可正常编译和运行

2. **B/M competition算法分析完成**
   - 深入分析了newHF版本的算法实现
   - 理解了核心判断逻辑: `drAvg0 < (drbmRatio * dr0m)`
   - 识别了关键参数: drbmRatio=0.53 (轻夸克), drbmHQ=1.0 (重夸克)
   - 发现了接口差异问题

3. **夸克计数功能实现**
   - 在CZCOAL_BMCOMP()中实现了动态计数nq和nqbar
   - 验证了通过NJSGS和K2SGS数组计算夸克数的可行性
   - 代码已编译成功，等待测试验证

### 当前代码状态

**czcoal.f文件中的CZCOAL_BMCOMP()函数已实现：**
```fortran
SUBROUTINE CZCOAL_BMCOMP()
  ! 动态计算nq和nqbar
  nq = 0
  nqbar = 0
  do i=1,NSG
    if(NJSGS(i).eq.2) then        ! 介子: 1q + 1qbar
      nq = nq + 1
      nqbar = nqbar + 1  
    elseif(NJSGS(i).eq.3) then    ! 重子/反重子: 3q同类型
      if(K2SGS(i,1).gt.0) then
        nq = nq + 3               ! 重子
      else
        nqbar = nqbar + 3         ! 反重子
      endif
    endif
  enddo
  
  write(6,*) 'B/M competition: NSG=',NSG,', nq=',nq,', nqbar=',nqbar
  write(6,*) '  drbmRatio=',drbmRatio
  
  ! 目前仍使用经典算法
  call czcoal_classic()
end
```

## 下一步实现计划

### 步骤1: 验证夸克计数正确性 🔄

**目标**: 确认我们的夸克计数逻辑与newHF的nq/nqbar计算结果一致

**具体操作**:
1. 修改input.ampt: `icoal_method: 1 -> 2` 来测试B/M模式
2. 运行小规模测试，观察输出：
   ```bash
   echo "12345" | ./ampt 2>&1 | head -50
   ```
3. 检查输出中的 "B/M competition: NSG=X, nq=Y, nqbar=Z" 信息
4. 验证 nq + nqbar 的总数是否合理 (应该等于总的parton数)
5. 检查nq和nqbar的比例是否符合物理预期

### 步骤2: 实现真正的B/M Competition逻辑 🎯

**核心算法**（基于newHF分析）:
```fortran
! 对每个parton ip1:
!   1. 找到最近的meson partner (q-qbar pair) -> dr0m
!   2. 找到最近的baryon partner (3q system) -> drAvg0  
!   3. B/M竞争判断:
      if(drAvg0.lt.drbig.and.dr0m.lt.drbig) then
        if(drAvg0.lt.(drbmRatio*dr0m)) then
          npmb=3  ! 形成重子
        else  
          npmb=2  ! 形成介子
        endif
      endif
```

**实现要点**:
- 简化距离计算（避免复杂的Lorentz变换）
- 不包含重夸克特殊处理 (按用户要求)
- 重用现有的数据结构和辅助函数

### 步骤3: 距离计算函数 📏

**需要实现**:
```fortran
SUBROUTINE CZCOAL_DISTANCE_CALC(ip1, ip2, icall, distance)
  ! icall=2: meson distance (2-body)
  ! icall=3: baryon distance (3-body average)  
  ! 使用简化的空间距离计算
end
```

### 步骤4: 测试和验证 🧪

**验证步骤**:
1. 对比classic vs B/M模式的输出差异
2. 检查B/M比例是否受drbmRatio参数影响
3. 验证系统稳定性和性能

### 步骤5: 优化和完善 🔧

1. 添加调试输出开关
2. 优化算法性能
3. 添加参数合理性检查
4. 完善错误处理

## 重要技术细节

### 数据结构理解
- `NJSGS(i)`: 第i个string group的parton数 (2=meson, 3=baryon)
- `K2SGS(i,j)`: 第i个group中第j个parton的类型 (正=夸克, 负=反夸克)
- `GXSGS,GYSGS,GZSGS`: 空间坐标用于距离计算

### 关键参数
- `drbmRatio = 0.53`: 轻夸克B/M形成距离比例因子 
- 不实现重夸克特殊处理 (drbmHQ参数)

### 风险点和注意事项

1. **数据结构理解正确性**: 需要通过测试验证nq/nqbar计算是否正确
2. **距离计算复杂性**: newHF使用复杂的相对论时空距离，我们采用简化版本
3. **算法兼容性**: 确保B/M模式与现有系统兼容
4. **性能考虑**: B/M竞争可能增加计算复杂度

## 建议的测试流程

```bash
# 1. 当前状态测试
make && echo "12345" | ./ampt | head -20

# 2. 切换到BM模式测试 (修改input.ampt中icoal_method=2)
echo "12345" | ./ampt 2>&1 | grep "B/M competition"

# 3. 比较输出差异
# 4. 调整参数测试 (drbmRatio值)
```

## 文件修改检查清单

- [x] czcoal.f: CZCOAL_BMCOMP()函数已实现夸克计数
- [ ] 待测试: 验证夸克计数正确性  
- [ ] 待实现: 真正的B/M竞争逻辑
- [ ] 待实现: 距离计算函数
- [ ] 待测试: 完整的B/M competition流程

## 下个session的第一个任务

**优先级最高**: 测试当前的夸克计数功能是否正确工作
1. 修改input.ampt设置`icoal_method=2` 
2. 运行测试并检查输出
3. 验证nq和nqbar的数值是否合理

如果计数功能正常，再继续实现真正的B/M竞争算法。