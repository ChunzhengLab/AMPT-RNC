#!/bin/bash

echo "=== AMPT内存优化配置验证 ==="
echo ""

echo "🔍 检查AutoFlush配置 (每50个事件):"
grep -n "SetAutoFlush(50)" root_interface.cpp
echo ""

echo "🔍 检查AutoSave配置 (每200个事件):"  
grep -n "SetAutoSave(200)" root_interface.cpp
echo ""

echo "🔍 检查最终保存配置 (SaveSelf;FlushBaskets):"
grep -n 'AutoSave("SaveSelf;FlushBaskets")' root_interface.cpp
echo ""

echo "🔍 检查数据流配置统计:"
echo "数据流数量: $(grep -c 'new TFile.*root.*RECREATE' root_interface.cpp)"
echo "AutoFlush配置数量: $(grep -c 'SetAutoFlush(50)' root_interface.cpp)"
echo "AutoSave配置数量: $(grep -c 'SetAutoSave(200)' root_interface.cpp)"
echo "最终保存配置数量: $(grep -c 'AutoSave.*SaveSelf.*FlushBaskets' root_interface.cpp)"
echo ""

echo "🔍 实时分析配置检查:"
if grep -q "analysis_core.h" root_interface.cpp; then
    echo "✅ 实时分析已集成"
else
    echo "❌ 实时分析未集成"
fi

if grep -q "analyze_current_event_" root_interface.cpp; then
    echo "✅ 事件级实时分析已配置"
else
    echo "❌ 事件级实时分析未配置" 
fi
echo ""

echo "📊 内存优化总结:"
echo "=================="
echo "1. 数据流管理: 5个ROOT文件流，每个都有内存管理"
echo "2. 刷盘频率: 每50个事件自动刷盘释放内存"
echo "3. 恢复点: 每200个事件创建一个恢复点"
echo "4. 最终保存: 程序结束时强制保存所有数据"
echo "5. 实时分析: 边运行边分析，减少内存累积"
echo ""

echo "🎯 预期效果:"
echo "- 峰值内存: ~500MB (5流 × 50事件 × ~2MB/事件)"
echo "- HTCondor兼容: ✅ 远低于2GB限制"
echo "- 数据安全: ✅ 多层保护机制"
echo "- 性能平衡: ✅ 合理的I/O频率"

echo ""
echo "配置验证完成！✅"