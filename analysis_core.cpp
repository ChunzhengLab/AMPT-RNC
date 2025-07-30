#include "analysis_core.h"
#include <iostream>
#include <cmath>
#include <vector>
#include <algorithm>
#include "TMath.h"
#include "TString.h"

using namespace std;

// 全局分析对象
AnalysisCore* g_analysis_ampt = nullptr;
AnalysisCore* g_analysis_zpc = nullptr;
AnalysisCore* g_analysis_parton = nullptr;
AnalysisCore* g_analysis_hadron_before_art = nullptr;
AnalysisCore* g_analysis_hadron_before_melting = nullptr;

AnalysisCore::AnalysisCore() : processed_events(0), isHadronMode(true) {
    p_delta_momentum = nullptr;
    p_gamma_momentum = nullptr;
    p_delta_spatial = nullptr;
    p_gamma_spatial = nullptr;
}

AnalysisCore::~AnalysisCore() {
    // ROOT会自动管理内存，但显式删除更安全
    delete p_delta_momentum;
    delete p_gamma_momentum;
    delete p_delta_spatial;
    delete p_gamma_spatial;
    
    // 删除角度关联直方图
    for (auto& pair : map_h1_angCorr_momentum_pidpair) {
        delete pair.second;
    }
    for (auto& pair : map_h1_angCorr_spatial_pidpair) {
        delete pair.second;
    }
    
    // 删除单粒子直方图
    for (auto& pair : map_h1_pt_pid) {
        delete pair.second;
    }
    for (auto& pair : map_h1_phi_pid) {
        delete pair.second;
    }
    for (auto& pair : map_p_v2_pid) {
        delete pair.second;
    }
}

void AnalysisCore::Initialize(bool hadronMode, const string& analysis_name) {
    isHadronMode = hadronMode;
    this->analysis_name = analysis_name;
    
    // 设置粒子定义 - 与analysisAll_flexible.cxx完全对齐
    if (isHadronMode) {
        pid_names = {"pipos", "pineg", "Kpos", "Kneg", "p", "pbar", "n", "nbar", "phi", "Lambda", "LambdaBar"};
        pid_codes = {211, -211, 321, -321, 2212, -2212, 2112, -2112, 333, 3122, -3122};
    } else {
        pid_names = {"u", "ubar", "d", "dbar", "s", "sbar"};
        pid_codes = {2, -2, 1, -1, 3, -3};
    }
    
    // 移除所有中心度相关的直方图
    
    // 计算粒子对的总数 - 与原版算法相同
    int nPairTypes = (pid_names.size() * (pid_names.size() + 1)) / 2;
    
    // 创建TProfile - 使用具体的分析名称避免冲突
    p_delta_momentum = new TProfile(Form("p_delta_momentum_%s", analysis_name.c_str()), 
                                    "Delta = <cos(phi_1 - phi_2)> in momentum space;Pair type;Delta", 
                                    nPairTypes, 0, nPairTypes);
    p_gamma_momentum = new TProfile(Form("p_gamma_momentum_%s", analysis_name.c_str()), 
                                    "Gamma = <cos(phi_1 + phi_2)> in momentum space;Pair type;Gamma", 
                                    nPairTypes, 0, nPairTypes);
    p_delta_spatial = new TProfile(Form("p_delta_spatial_%s", analysis_name.c_str()), 
                                   "Delta = <cos(phi_1 - phi_2)> in spatial coordinates;Pair type;Delta", 
                                   nPairTypes, 0, nPairTypes);
    p_gamma_spatial = new TProfile(Form("p_gamma_spatial_%s", analysis_name.c_str()), 
                                   "Gamma = <cos(phi_1 + phi_2)> in spatial coordinates;Pair type;Gamma", 
                                   nPairTypes, 0, nPairTypes);
    
    // 设置bin标签并建立映射，同时初始化角度关联直方图 - 与原版完全对齐
    int binIndex = 1;
    pidpair_to_bin.clear();
    map_h1_angCorr_momentum_pidpair.clear();
    map_h1_angCorr_spatial_pidpair.clear();
    
    for (size_t i = 0; i < pid_names.size(); i++) {
        for (size_t j = i; j < pid_names.size(); j++) {
            int pid_i = pid_codes[i];
            int pid_j = pid_codes[j];
            PIDPairs pidpair = make_pair(min(pid_i, pid_j), max(pid_i, pid_j));
            
            string pair_label = pid_names[i] + "-" + pid_names[j];
            p_delta_momentum->GetXaxis()->SetBinLabel(binIndex, pair_label.c_str());
            p_gamma_momentum->GetXaxis()->SetBinLabel(binIndex, pair_label.c_str());
            p_delta_spatial->GetXaxis()->SetBinLabel(binIndex, pair_label.c_str());
            p_gamma_spatial->GetXaxis()->SetBinLabel(binIndex, pair_label.c_str());
            
            pidpair_to_bin[pidpair] = binIndex;
            
            // 初始化角度关联直方图 - 对齐原版参数，使用具体分析名称
            string pair_name = pid_names[i] + "_" + pid_names[j];
            map_h1_angCorr_momentum_pidpair[pidpair] = new TH1D(Form("h1_angCorr_momentum_%s_%s", analysis_name.c_str(), pair_name.c_str()), 
                                                               "", 32, -TMath::Pi()/2, 3*TMath::Pi()/2);
            map_h1_angCorr_spatial_pidpair[pidpair] = new TH1D(Form("h1_angCorr_spatial_%s_%s", analysis_name.c_str(), pair_name.c_str()), 
                                                              "", 32, -TMath::Pi()/2, 3*TMath::Pi()/2);
            
            binIndex++;
        }
    }
    
    processed_events = 0;
    
    // 初始化分粒子直方图
    InitializeParticleHistograms();
}

// 移除GetCentrality函数

bool AnalysisCore::AcceptHadron(int pid, double pt, double eta) {
    // 接受的强子PID - 与analysisAll_flexible.cxx完全对齐
    int accepted_pids[] = {211, -211, 321, -321, 2212, -2212, 2112, -2112, 333, 3122, -3122};
    
    bool pid_ok = false;
    for (int apid : accepted_pids) {
        if (pid == apid) {
            pid_ok = true;
            break;
        }
    }
    if (!pid_ok) return false;
    
    // 通用切割条件
    if (pt < 0.2 || fabs(eta) > 0.8) return false;
    
    // 粒子特定的pT切割 - 完全对齐原版
    if (abs(pid) == 211) {  // pions
        if (pt < 0.2 || pt > 2.5) return false;
    }
    if (abs(pid) == 321) {  // kaons
        if (pt < 0.5 || pt > 2.5) return false;
    }
    if (abs(pid) == 2212 || abs(pid) == 2112) {  // protons/neutrons
        if (pt < 0.7 || pt > 5.0) return false;
    }
    if (abs(pid) == 333) {  // phi
        if (pt < 0.3 || pt > 4.3) return false;
    }
    if (abs(pid) == 3122) {  // Lambda
        if (pt < 1.0 || pt > 10.0) return false;
    }
    
    return true;
}

bool AnalysisCore::AcceptParton(int pid, double pt, double eta) {
    // 接受的夸克PID - 对齐原版顺序 {2, -2, 1, -1, 3, -3}
    int accepted_pids[] = {2, -2, 1, -1, 3, -3}; // u, ubar, d, dbar, s, sbar
    
    bool pid_ok = false;
    for (int apid : accepted_pids) {
        if (pid == apid) {
            pid_ok = true;
            break;
        }
    }
    
    if (!pid_ok) return false;
    if (pt < 0.1 || fabs(eta) > 1.0) return false;  // 夸克可以有更低的pT和更大的eta范围
    
    // 夸克特定切割（比强子宽松）
    if (abs(pid) <= 3) {  // u, d, s夸克及反夸克
        if (pt > 20.0) return false;  // 现实夸克pT上限
    }
    
    return true;
}

double AnalysisCore::range_delta_phi(double dphi) {
    // 与analysisAll_flexible.cxx完全相同的函数
    while (dphi > 3*TMath::Pi()/2) dphi -= 2 * TMath::Pi();
    while (dphi < -TMath::Pi()/2) dphi += 2 * TMath::Pi();
    return dphi;
}

bool AnalysisCore::AcceptParticle(int pid, double px, double py, double pz) {
    double pt = sqrt(px*px + py*py);
    double p = sqrt(px*px + py*py + pz*pz);
    double eta = 0.5 * log((p + pz) / (p - pz + 1e-10));
    
    if (isHadronMode) {
        return AcceptHadron(pid, pt, eta);
    } else {
        return AcceptParton(pid, pt, eta);
    }
}

void AnalysisCore::AnalyzeEvent(int eventID, double impactParameter, int nParticles,
                               int* pid, double* px, double* py, double* pz,
                               double* x, double* y, double* z) {
    // 移除所有中心度判断和多重数统计
    
    // 收集接受的粒子并填充单粒子直方图
    vector<int> accepted_indices;
    for (int i = 0; i < nParticles; i++) {
        if (AcceptParticle(pid[i], px[i], py[i], pz[i])) {
            accepted_indices.push_back(i);
            
            // 填充单粒子直方图
            double pt = sqrt(px[i]*px[i] + py[i]*py[i]);
            double phi = atan2(py[i], px[i]);
            int particle_pid = pid[i];
            
            // 检查是否有该粒子类型的直方图
            if (map_h1_pt_pid.find(particle_pid) != map_h1_pt_pid.end()) {
                map_h1_pt_pid[particle_pid]->Fill(pt);
                map_h1_phi_pid[particle_pid]->Fill(phi);
                map_p_v2_pid[particle_pid]->Fill(pt, cos(2*phi));
            }
        }
    }
    
    // 两粒子关联分析
    int nAccepted = accepted_indices.size();
    for (int i = 0; i < nAccepted; i++) {
        int idx_i = accepted_indices[i];
        
        for (int j = i + 1; j < nAccepted; j++) {
            int idx_j = accepted_indices[j];
            
            // 动量空间的方位角
            double phi_momentum_i = atan2(py[idx_i], px[idx_i]);
            double phi_momentum_j = atan2(py[idx_j], px[idx_j]);
            
            // 坐标空间的方位角
            double phi_spatial_i = atan2(y[idx_i], x[idx_i]);
            double phi_spatial_j = atan2(y[idx_j], x[idx_j]);
            
            // Delta = <cos(phi_1 - phi_2)>
            double delta_momentum = cos(phi_momentum_i - phi_momentum_j);
            double delta_spatial = cos(phi_spatial_i - phi_spatial_j);
            
            // Gamma = <cos(phi_1 + phi_2)>
            double gamma_momentum = cos(phi_momentum_i + phi_momentum_j);
            double gamma_spatial = cos(phi_spatial_i + phi_spatial_j);
            
            // 创建粒子对并找到对应的bin - 对齐原版逻辑
            int pdg_i = pid[idx_i];
            int pdg_j = pid[idx_j];
            PIDPairs pidpair = make_pair(min(pdg_i, pdg_j), max(pdg_i, pdg_j));
            
            // 检查此粒子对是否在我们的映射中
            auto it = pidpair_to_bin.find(pidpair);
            if (it != pidpair_to_bin.end()) {
                int bin = it->second;
                
                // 填充TProfile - 使用粒子对bin而不是中心度bin
                p_delta_momentum->Fill(bin - 0.5, delta_momentum);
                p_gamma_momentum->Fill(bin - 0.5, gamma_momentum);
                p_delta_spatial->Fill(bin - 0.5, delta_spatial);
                p_gamma_spatial->Fill(bin - 0.5, gamma_spatial);
            }
        }
    }
    
    // 角度关联分析 - 移除中心度筛选，对所有事件进行分析
    for (size_t iTrk = 0; iTrk < accepted_indices.size(); iTrk++) {
        int idx_i = accepted_indices[iTrk];
        int pdg_i = pid[idx_i];
        double phi_momentum_i = atan2(py[idx_i], px[idx_i]);
        double phi_spatial_i = atan2(y[idx_i], x[idx_i]);
        
        for (size_t jTrk = 0; jTrk < accepted_indices.size(); jTrk++) {
            if (iTrk == jTrk) continue;
            
            int idx_j = accepted_indices[jTrk];
            int pdg_j = pid[idx_j];
            double phi_momentum_j = atan2(py[idx_j], px[idx_j]);
            double phi_spatial_j = atan2(y[idx_j], x[idx_j]);
            
            PIDPairs pidpair = make_pair(min(pdg_i, pdg_j), max(pdg_i, pdg_j));
            
            // 检查此粒子对是否在我们的映射中
            auto it = map_h1_angCorr_momentum_pidpair.find(pidpair);
            if (it != map_h1_angCorr_momentum_pidpair.end()) {
                // 动量空间关联
                double dphi_momentum = range_delta_phi(phi_momentum_i - phi_momentum_j);
                it->second->Fill(dphi_momentum);
                
                // 空间关联
                double dphi_spatial = range_delta_phi(phi_spatial_i - phi_spatial_j);
                map_h1_angCorr_spatial_pidpair[pidpair]->Fill(dphi_spatial);
            }
        }
    }
    
    processed_events++;
    
    // 定期输出进度
    if (processed_events % 10 == 0) {
        cout << "Analysis: Processed " << processed_events << " events" << endl;
    }
    
    // 定期保存checkpoint
    if (processed_events % 50 == 0) {
        SaveCheckpoint();
    }
}

void AnalysisCore::SaveResults(const char* filename) {
    TFile* f = new TFile(filename, "RECREATE");
    
    // 移除多重数和中心度相关的直方图
    
    // 写入delta和gamma的TProfile
    p_delta_momentum->Write();
    p_gamma_momentum->Write();
    p_delta_spatial->Write();
    p_gamma_spatial->Write();
    
    // 写入角度关联直方图
    for (auto& pair : map_h1_angCorr_momentum_pidpair) {
        pair.second->Write();
    }
    for (auto& pair : map_h1_angCorr_spatial_pidpair) {
        pair.second->Write();
    }
    
    // 写入单粒子直方图
    for (auto& pair : map_h1_pt_pid) {
        pair.second->Write();
    }
    for (auto& pair : map_h1_phi_pid) {
        pair.second->Write();
    }
    for (auto& pair : map_p_v2_pid) {
        pair.second->Write();
    }
    
    f->Close();
    
    cout << "Analysis results saved to " << filename << endl;
    cout << "Total events processed: " << processed_events << endl;
}

void AnalysisCore::InitializeParticleHistograms() {
    // 为每种粒子类型创建pt、phi和v2直方图
    for (size_t i = 0; i < pid_codes.size(); i++) {
        int pid = pid_codes[i];
        string pid_name = pid_names[i];
        
        // pt直方图 (0-10 GeV, 100 bins)
        map_h1_pt_pid[pid] = new TH1D(Form("h1_pt_%s_%s", analysis_name.c_str(), pid_name.c_str()),
                                      Form("p_T distribution for %s;p_T (GeV/c);Counts", pid_name.c_str()),
                                      100, 0, 10);
        
        // phi直方图 (-pi to pi, 64 bins)
        map_h1_phi_pid[pid] = new TH1D(Form("h1_phi_%s_%s", analysis_name.c_str(), pid_name.c_str()),
                                       Form("#phi distribution for %s;#phi (rad);Counts", pid_name.c_str()),
                                       64, -TMath::Pi(), TMath::Pi());
        
        // v2 TProfile (pt vs cos(2*phi))
        map_p_v2_pid[pid] = new TProfile(Form("p_v2_%s_%s", analysis_name.c_str(), pid_name.c_str()),
                                         Form("v_2 vs p_T for %s;p_T (GeV/c);<cos(2#phi)>", pid_name.c_str()),
                                         50, 0, 5);
    }
}

void AnalysisCore::SaveCheckpoint() {
    const char* checkpoint_file = isHadronMode ? 
        "ana/analysis_checkpoint_hadron.root" : "ana/analysis_checkpoint_parton.root";
    SaveResults(checkpoint_file);
}