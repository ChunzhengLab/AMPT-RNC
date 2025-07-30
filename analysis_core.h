#ifndef ANALYSIS_CORE_H
#define ANALYSIS_CORE_H

#include <vector>
#include <map>
#include <string>
#include "TH1D.h"
#include "TH2D.h"
#include "TProfile.h"
#include "TFile.h"

// 粒子对类型定义
typedef std::pair<int, int> PIDPairs;

class AnalysisCore {
private:
    // 事件统计
    int processed_events;
    
    // 基础直方图
    TH1D* h_mult;
    TH1D* h_mult_cent[9];  // 9个中心度
    TH1D* h_centrality;
    
    // 两粒子关联的TProfile - 对齐原版结构
    TProfile* p_delta_momentum;
    TProfile* p_gamma_momentum;
    TProfile* p_delta_spatial;
    TProfile* p_gamma_spatial;
    
    // 粒子定义和映射
    std::vector<std::string> pid_names;
    std::vector<int> pid_codes;
    std::map<PIDPairs, int> pidpair_to_bin;
    
    // 角度关联直方图 - 对齐原版
    std::map<PIDPairs, TH1D*> map_h1_angCorr_momentum_pidpair;
    std::map<PIDPairs, TH1D*> map_h1_angCorr_spatial_pidpair;
    
    // 粒子筛选
    bool isHadronMode;
    
    // 辅助函数
    int GetCentrality(double impactParameter);
    bool AcceptParticle(int pid, double px, double py, double pz);
    bool AcceptHadron(int pid, double pt, double eta);
    bool AcceptParton(int pid, double pt, double eta);
    double range_delta_phi(double dphi);
    
public:
    AnalysisCore();
    ~AnalysisCore();
    
    // 初始化
    void Initialize(bool hadronMode = true);
    
    // 分析单个事件
    void AnalyzeEvent(int eventID, 
                     double impactParameter,
                     int nParticles,
                     int* pid,
                     double* px, double* py, double* pz,
                     double* x, double* y, double* z);
    
    // 保存结果
    void SaveResults(const char* filename);
    void SaveCheckpoint();
    
    // 获取统计信息
    int GetProcessedEvents() const { return processed_events; }
};

// 全局分析对象（每种数据流一个）
extern AnalysisCore* g_analysis_ampt;
extern AnalysisCore* g_analysis_zpc;
extern AnalysisCore* g_analysis_parton;

#endif // ANALYSIS_CORE_H