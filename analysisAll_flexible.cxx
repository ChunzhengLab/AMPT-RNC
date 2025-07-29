#include <iostream>
#include <vector>
#include <map>
#include <deque>
#include <fstream>
#include <string>
#include <algorithm>
#include <sstream>

#include "TFile.h"
#include "TTree.h"
#include "TChain.h"
#include "TH1D.h"
#include "TProfile.h"
#include "TVector3.h"
#include "TLorentzVector.h"
#include "TMath.h"
#include "TRandom3.h"
#include "TStopwatch.h"

using namespace std;

// Global constants
const size_t MIXPOOLSIZE = 4;
typedef std::pair<int, int> PIDPairs;

// Particle definitions
vector<string> vec_pid_hadron = {"pi+", "pi-", "K+", "K-", "p", "pbar", "n", "nbar", "phi", "Lambda", "LambdaBar"};
vector<int> vec_pdg_hadron = {211, -211, 321, -321, 2212, -2212, 2112, -2112, 333, 3122, -3122};

// Quark definitions (u, d, s quarks and antiquarks)
vector<string> vec_pid_quark = {"u", "ubar", "d", "dbar", "s", "sbar"};
vector<int> vec_pdg_quark = {2, -2, 1, -1, 3, -3};

// ROOT file format configuration
struct ROOTFormat {
    string tree_name;
    string nParticles_branch;
    string impactParameter_branch;
    string pid_branch;
    string px_branch, py_branch, pz_branch;
    string x_branch, y_branch, z_branch;
    
    // Data types and array sizes
    bool use_double_precision = true;
    int max_particles = 20000;
    
    // Additional branches (optional)
    string eventID_branch = "";
    string runID_branch = "";
    
    void print() const {
        cout << "ROOT Format Configuration:" << endl;
        cout << "  Tree name: " << tree_name << endl;
        cout << "  nParticles: " << nParticles_branch << endl;
        cout << "  impactParameter: " << impactParameter_branch << endl;
        cout << "  PID: " << pid_branch << endl;
        cout << "  Momentum: " << px_branch << ", " << py_branch << ", " << pz_branch << endl;
        cout << "  Position: " << x_branch << ", " << y_branch << ", " << z_branch << endl;
        cout << "  Max particles: " << max_particles << endl;
        cout << "  Double precision: " << (use_double_precision ? "Yes" : "No") << endl;
    }
};

// Predefined formats for different AMPT outputs
map<string, ROOTFormat> predefined_formats = {
    {"ampt", {
        "ampt",                    // tree_name
        "nParticles",             // nParticles_branch
        "impactParameter",        // impactParameter_branch
        "pid",                    // pid_branch
        "px", "py", "pz",        // momentum branches
        "x", "y", "z",           // position branches
        true, 20000,             // double precision, max particles
        "eventID", "runID"       // optional branches
    }},
    {"hadron_before_art", {
        "hadron_before_art",
        "nParticles",
        "impactParameter", 
        "pid",
        "px", "py", "pz",
        "x", "y", "z",
        true, 20000,
        "eventID", ""
        // Note: also contains miss, nelp, ninp, nelt, ninthj, mass, t branches
        // but we only need the essential ones for analysis
    }},
    {"hadron_before_melting", {
        "hadron_before_melting",
        "nParticles",
        "impactParameter",
        "pid", 
        "px", "py", "pz",
        "x", "y", "z",
        true, 20000,
        "eventID", ""
        // Note: also contains miss, nelp, ninp, nelt, ninthj, mass, t branches
        // but we only need the essential ones for analysis
    }},
    {"zpc", {
        "zpc",
        "nParticles",
        "impactParameter",
        "pid",
        "px", "py", "pz",
        "x", "y", "z",
        true, 20000,
        "eventID", ""
        // Note: ZPC parton data after cascade
    }},
    {"parton_initial", {
        "parton_initial",
        "nParticles",
        "impactParameter",  // Note: may not have this branch, will be handled
        "pid",
        "px", "py", "pz",
        "x", "y", "z",
        true, 20000,
        "eventID", ""
        // Note: also contains istrg0, xstrg0, ystrg0 string info branches
    }},
    {"legacy_format", {
        "AMPT",
        "Event.multi",
        "Event.impactpar",
        "ID",
        "Px", "Py", "Pz",
        "X", "Y", "Z",
        false, 99999,
        "", ""
    }}
};

// Event class for mixing
class Event {
public:
    vector<int> pid_trks;
    vector<TVector3> p3_trks;
    vector<TVector3> x3_trks;
    
    Event(const vector<int>& pids, const vector<TVector3>& p3s, const vector<TVector3>& x3s) 
        : pid_trks(pids), p3_trks(p3s), x3_trks(x3s) {}
};

// Data reader class - handles different ROOT formats
class AMPTDataReader {
private:
    TChain* chain;
    ROOTFormat format;
    
    // Branch variables - using void* for flexibility
    Int_t nParticles;
    Double_t impactParameter_d;
    Float_t impactParameter_f;
    
    // Particle arrays - double precision
    Int_t* pid_d;
    Double_t* px_d; Double_t* py_d; Double_t* pz_d;
    Double_t* x_d; Double_t* y_d; Double_t* z_d;
    
    // Particle arrays - single precision (for legacy format)
    Int_t* pid_f;
    Float_t* px_f; Float_t* py_f; Float_t* pz_f;
    Float_t* x_f; Float_t* y_f; Float_t* z_f;
    
public:
    AMPTDataReader(const ROOTFormat& fmt) : format(fmt), chain(nullptr) {
        // Allocate arrays
        if (format.use_double_precision) {
            pid_d = new Int_t[format.max_particles];
            px_d = new Double_t[format.max_particles];
            py_d = new Double_t[format.max_particles];
            pz_d = new Double_t[format.max_particles];
            x_d = new Double_t[format.max_particles];
            y_d = new Double_t[format.max_particles];
            z_d = new Double_t[format.max_particles];
        } else {
            pid_f = new Int_t[format.max_particles];
            px_f = new Float_t[format.max_particles];
            py_f = new Float_t[format.max_particles];
            pz_f = new Float_t[format.max_particles];
            x_f = new Float_t[format.max_particles];
            y_f = new Float_t[format.max_particles];
            z_f = new Float_t[format.max_particles];
        }
    }
    
    ~AMPTDataReader() {
        if (format.use_double_precision) {
            delete[] pid_d; delete[] px_d; delete[] py_d; delete[] pz_d;
            delete[] x_d; delete[] y_d; delete[] z_d;
        } else {
            delete[] pid_f; delete[] px_f; delete[] py_f; delete[] pz_f;
            delete[] x_f; delete[] y_f; delete[] z_f;
        }
        if (chain) delete chain;
    }
    
    bool Initialize(const string& input) {
        chain = new TChain(format.tree_name.c_str());
        
        // Add files to chain
        if (input.find(".list") != string::npos) {
            ifstream fin(input);
            string filename;
            while (getline(fin, filename)) {
                if (!filename.empty()) {
                    chain->Add(filename.c_str());
                }
            }
            fin.close();
        } else {
            chain->Add(input.c_str());
        }
        
        if (chain->GetEntries() == 0) {
            cout << "Error: No entries found in chain" << endl;
            return false;
        }
        
        cout << "Loaded " << chain->GetEntries() << " events from " << format.tree_name << endl;
        
        // Set branch addresses
        chain->SetBranchAddress(format.nParticles_branch.c_str(), &nParticles);
        
        if (format.use_double_precision) {
            chain->SetBranchAddress(format.impactParameter_branch.c_str(), &impactParameter_d);
            chain->SetBranchAddress(format.pid_branch.c_str(), pid_d);
            chain->SetBranchAddress(format.px_branch.c_str(), px_d);
            chain->SetBranchAddress(format.py_branch.c_str(), py_d);
            chain->SetBranchAddress(format.pz_branch.c_str(), pz_d);
            chain->SetBranchAddress(format.x_branch.c_str(), x_d);
            chain->SetBranchAddress(format.y_branch.c_str(), y_d);
            chain->SetBranchAddress(format.z_branch.c_str(), z_d);
        } else {
            chain->SetBranchAddress(format.impactParameter_branch.c_str(), &impactParameter_f);
            chain->SetBranchAddress(format.pid_branch.c_str(), pid_f);
            chain->SetBranchAddress(format.px_branch.c_str(), px_f);
            chain->SetBranchAddress(format.py_branch.c_str(), py_f);
            chain->SetBranchAddress(format.pz_branch.c_str(), pz_f);
            chain->SetBranchAddress(format.x_branch.c_str(), x_f);
            chain->SetBranchAddress(format.y_branch.c_str(), y_f);
            chain->SetBranchAddress(format.z_branch.c_str(), z_f);
        }
        
        return true;
    }
    
    Long64_t GetEntries() const { return chain ? chain->GetEntries() : 0; }
    
    void GetEntry(Long64_t entry) { if (chain) chain->GetEntry(entry); }
    
    // Unified data access interface
    int GetNParticles() const { return nParticles; }
    
    double GetImpactParameter() const { 
        return format.use_double_precision ? impactParameter_d : impactParameter_f; 
    }
    
    int GetPID(int i) const { 
        return format.use_double_precision ? pid_d[i] : pid_f[i]; 
    }
    
    TVector3 GetMomentum(int i) const {
        if (format.use_double_precision) {
            return TVector3(px_d[i], py_d[i], pz_d[i]);
        } else {
            return TVector3(px_f[i], py_f[i], pz_f[i]);
        }
    }
    
    TVector3 GetPosition(int i) const {
        if (format.use_double_precision) {
            return TVector3(x_d[i], y_d[i], z_d[i]);
        } else {
            return TVector3(x_f[i], y_f[i], z_f[i]);
        }
    }
};

// Function declarations
int GetCentrality(float b);
float range_delta_phi(float dphi);
float range_phi(float phi);
bool isTrackAccepted(int pid, float pT, float eta, float phi);
bool isQuarkAccepted(int pid, float pT, float eta, float phi);
ROOTFormat DetectFormat(const string& filename);
void ShowFormats();
bool IsHadronData(const string& tree_name);
bool IsQuarkData(const string& tree_name);

// Auto-detect ROOT format from file
ROOTFormat DetectFormat(const string& filename) {
    string test_file = filename;
    
    // If it's a list file, get the first file
    if (filename.find(".list") != string::npos) {
        ifstream fin(filename);
        getline(fin, test_file);
        fin.close();
    }
    
    TFile* f = TFile::Open(test_file.c_str());
    if (!f || f->IsZombie()) {
        cout << "Warning: Cannot open file " << test_file << ", using default format" << endl;
        return predefined_formats["ampt"];
    }
    
    // Check which tree exists and return corresponding format
    for (auto& pair : predefined_formats) {
        if (f->Get(pair.second.tree_name.c_str())) {
            cout << "Auto-detected format: " << pair.first << endl;
            f->Close();
            return pair.second;
        }
    }
    
    f->Close();
    cout << "Warning: No matching format found, using default" << endl;
    return predefined_formats["ampt"];
}

void ShowFormats() {
    cout << "Available predefined formats:" << endl;
    for (auto& pair : predefined_formats) {
        cout << "  " << pair.first << ": " << pair.second.tree_name << endl;
    }
}

int main(int argc, char** argv) {
    if (argc < 3) {
        cout << "Usage: " << argv[0] << " <input.root|.list> <output.root> [format]" << endl;
        cout << "  format: auto (default), ampt, hadron_before_art, hadron_before_melting, legacy_format" << endl;
        cout << endl;
        ShowFormats();
        return 1;
    }
    
    TStopwatch timer;
    timer.Start();
    
    string inputFile = argv[1];
    string outputFile = argv[2];
    string format_name = (argc > 3) ? argv[3] : "auto";
    
    // Determine format
    ROOTFormat format;
    if (format_name == "auto") {
        format = DetectFormat(inputFile);
    } else {
        if (predefined_formats.find(format_name) == predefined_formats.end()) {
            cout << "Error: Unknown format " << format_name << endl;
            ShowFormats();
            return 1;
        }
        format = predefined_formats[format_name];
    }
    
    format.print();
    
    // Determine if this is hadron or quark data
    bool isHadron = IsHadronData(format.tree_name);
    bool isQuark = IsQuarkData(format.tree_name);
    
    cout << "Data type: " << (isHadron ? "Hadron" : isQuark ? "Quark/Parton" : "Unknown") << endl;
    
    // Initialize data reader
    AMPTDataReader reader(format);
    if (!reader.Initialize(inputFile)) {
        cout << "Error: Failed to initialize data reader" << endl;
        return 1;
    }
    
    // Create histograms (same as original)
    TH1D* h_mult = new TH1D("mult", "Multiplicity", 1000, 0, 10000);
    TH1D* h_centrality = new TH1D("centrality", "Centrality", 10, 0, 10);
    
    // Single particle histograms - adapt to data type
    vector<TH1D*> vec_h_pt_pid, vec_h_eta_pid, vec_h_phi_pid;
    vector<TH1D*> vec_h_r_spatial_pid, vec_h_eta_spatial_pid, vec_h_phi_spatial_pid;
    vector<TProfile*> vec_p_v2_pid, vec_p_v2_spatial_pid;
    
    // Choose particle list based on data type
    vector<string>* pid_names = isHadron ? &vec_pid_hadron : &vec_pid_quark;
    vector<int>* pid_codes = isHadron ? &vec_pdg_hadron : &vec_pdg_quark;
    
    for (size_t i = 0; i < pid_names->size(); i++) {
        string particle_name = (*pid_names)[i];
        vec_h_pt_pid.push_back(new TH1D(Form("h_pt_%s", particle_name.c_str()), "", 100, 0, 10));
        vec_h_eta_pid.push_back(new TH1D(Form("h_eta_%s", particle_name.c_str()), "", 50, -2.5, 2.5));
        vec_h_phi_pid.push_back(new TH1D(Form("h_phi_%s", particle_name.c_str()), "", 50, -TMath::Pi(), TMath::Pi()));
        
        vec_h_r_spatial_pid.push_back(new TH1D(Form("h_r_spatial_%s", particle_name.c_str()), "", 50, 0, 20));
        vec_h_eta_spatial_pid.push_back(new TH1D(Form("h_eta_spatial_%s", particle_name.c_str()), "", 50, -2.5, 2.5));
        vec_h_phi_spatial_pid.push_back(new TH1D(Form("h_phi_spatial_%s", particle_name.c_str()), "", 50, -TMath::Pi(), TMath::Pi()));
        
        vec_p_v2_pid.push_back(new TProfile(Form("p_v2_%s", particle_name.c_str()), "", 50, 0, 5));
        vec_p_v2_spatial_pid.push_back(new TProfile(Form("p_v2_spatial_%s", particle_name.c_str()), "", 50, 0, 20));
    }
    
    // Angular correlation histograms (simplified for demo)
    map<PIDPairs, TH1D*> map_h1_angCorr_sameEvt_pidpair_cent0010;
    map<PIDPairs, TH1D*> map_h1_angCorr_sameEvt_pidpair_cent3040;
    map<PIDPairs, TH1D*> map_h1_angCorr_sameEvt_pidpair_cent6070;
    
    // Initialize correlation histograms  
    for (size_t i = 0; i < pid_names->size(); i++) {
        for (size_t j = i; j < pid_names->size(); j++) {
            int pid_i = (*pid_codes)[i];
            int pid_j = (*pid_codes)[j];
            PIDPairs pidpair = make_pair(min(pid_i, pid_j), max(pid_i, pid_j));
            
            string pair_name = (*pid_names)[i] + "_" + (*pid_names)[j];
            
            map_h1_angCorr_sameEvt_pidpair_cent0010[pidpair] = new TH1D(Form("h1_angCorr_sameEvt_%s_cent0010", pair_name.c_str()), "", 30, -0.5*TMath::Pi(), 1.5*TMath::Pi());
            map_h1_angCorr_sameEvt_pidpair_cent3040[pidpair] = new TH1D(Form("h1_angCorr_sameEvt_%s_cent3040", pair_name.c_str()), "", 30, -0.5*TMath::Pi(), 1.5*TMath::Pi());
            map_h1_angCorr_sameEvt_pidpair_cent6070[pidpair] = new TH1D(Form("h1_angCorr_sameEvt_%s_cent6070", pair_name.c_str()), "", 30, -0.5*TMath::Pi(), 1.5*TMath::Pi());
        }
    }
    
    // Event mixing pools
    deque<Event> mixPool_0010, mixPool_3040, mixPool_6070;
    
    // Event loop - using unified data reader interface
    Long64_t nEvents = reader.GetEntries();
    cout << "Processing " << nEvents << " events..." << endl;
    
    for (Long64_t iEvt = 0; iEvt < nEvents; iEvt++) {
        if (iEvt % 1000 == 0) cout << "Processing event " << iEvt << endl;
        
        reader.GetEntry(iEvt);
        
        int nParticles = reader.GetNParticles();
        double impactParameter = reader.GetImpactParameter();
        
        h_mult->Fill(nParticles);
        
        int cent = GetCentrality(impactParameter);
        if (cent < 0) continue;
        h_centrality->Fill(cent);
        
        // Collect accepted tracks
        vector<int> pid_trks;
        vector<TVector3> p3_trks, x3_trks;
        
        for (int iTrk = 0; iTrk < nParticles; iTrk++) {
            int pdg = reader.GetPID(iTrk);
            TVector3 p3 = reader.GetMomentum(iTrk);
            TVector3 x3 = reader.GetPosition(iTrk);
            
            float pT = p3.Pt();
            float eta = p3.Eta();
            float phi = p3.Phi();
            
            // Use appropriate acceptance function based on data type
            bool accepted = isHadron ? isTrackAccepted(pdg, pT, eta, phi) : isQuarkAccepted(pdg, pT, eta, phi);
            if (!accepted) continue;
            
            pid_trks.push_back(pdg);
            p3_trks.push_back(p3);
            x3_trks.push_back(x3);
            
            // Fill single particle histograms
            auto it = find(pid_codes->begin(), pid_codes->end(), pdg);
            if (it != pid_codes->end()) {
                int idx = distance(pid_codes->begin(), it);
                vec_h_pt_pid[idx]->Fill(pT);
                vec_h_eta_pid[idx]->Fill(eta);
                vec_h_phi_pid[idx]->Fill(phi);
                vec_p_v2_pid[idx]->Fill(pT, cos(2*phi));
                
                float r = x3.Pt();
                float eta_s = x3.Eta();
                float phi_s = x3.Phi();
                vec_h_r_spatial_pid[idx]->Fill(r);
                vec_h_eta_spatial_pid[idx]->Fill(eta_s);
                vec_h_phi_spatial_pid[idx]->Fill(phi_s);
                vec_p_v2_spatial_pid[idx]->Fill(r, cos(2*phi_s));
            }
        }
        
        // Add to mixing pool
        if (cent == 0) {
            mixPool_0010.emplace_back(pid_trks, p3_trks, x3_trks);
            if (mixPool_0010.size() > MIXPOOLSIZE) mixPool_0010.pop_front();
        } else if (cent == 3) {
            mixPool_3040.emplace_back(pid_trks, p3_trks, x3_trks);
            if (mixPool_3040.size() > MIXPOOLSIZE) mixPool_3040.pop_front();
        } else if (cent == 6) {
            mixPool_6070.emplace_back(pid_trks, p3_trks, x3_trks);
            if (mixPool_6070.size() > MIXPOOLSIZE) mixPool_6070.pop_front();
        }
        
        auto& mixPool = (cent == 0) ? mixPool_0010 : (cent == 3) ? mixPool_3040 : mixPool_6070;
        if (mixPool.size() < MIXPOOLSIZE) continue;
        
        auto& evt_this = mixPool.back();
        
        // Same event correlations (simplified)
        for (size_t iTrk = 0; iTrk < evt_this.pid_trks.size(); iTrk++) {
            int pdg_i = evt_this.pid_trks[iTrk];
            float phi_i = evt_this.p3_trks[iTrk].Phi();
            
            for (size_t jTrk = 0; jTrk < evt_this.pid_trks.size(); jTrk++) {
                if (iTrk == jTrk) continue;
                
                int pdg_j = evt_this.pid_trks[jTrk];
                float phi_j = evt_this.p3_trks[jTrk].Phi();
                
                PIDPairs pidpair = make_pair(min(pdg_i, pdg_j), max(pdg_i, pdg_j));
                
                float dphi = range_delta_phi(phi_i - phi_j);
                
                // Fill correlation histograms
                if (cent == 0) {
                    map_h1_angCorr_sameEvt_pidpair_cent0010[pidpair]->Fill(dphi);
                } else if (cent == 3) {
                    map_h1_angCorr_sameEvt_pidpair_cent3040[pidpair]->Fill(dphi);
                } else if (cent == 6) {
                    map_h1_angCorr_sameEvt_pidpair_cent6070[pidpair]->Fill(dphi);
                }
            }
        }
    }
    
    // Save output
    TFile* outFile = new TFile(outputFile.c_str(), "RECREATE");
    
    h_mult->Write();
    h_centrality->Write();
    
    for (auto h : vec_h_pt_pid) h->Write();
    for (auto h : vec_h_eta_pid) h->Write();
    for (auto h : vec_h_phi_pid) h->Write();
    for (auto h : vec_h_r_spatial_pid) h->Write();
    for (auto h : vec_h_eta_spatial_pid) h->Write();
    for (auto h : vec_h_phi_spatial_pid) h->Write();
    for (auto p : vec_p_v2_pid) p->Write();
    for (auto p : vec_p_v2_spatial_pid) p->Write();
    
    for (auto& pair : map_h1_angCorr_sameEvt_pidpair_cent0010) pair.second->Write();
    for (auto& pair : map_h1_angCorr_sameEvt_pidpair_cent3040) pair.second->Write();
    for (auto& pair : map_h1_angCorr_sameEvt_pidpair_cent6070) pair.second->Write();
    
    outFile->Close();
    
    timer.Stop();
    cout << "Analysis completed in " << timer.RealTime() << " seconds" << endl;
    cout << "Output saved to: " << outputFile << endl;
    
    return 0;
}

// Helper functions (same as original)
int GetCentrality(float b) {
    for (int i = 1; i <= 10; ++i) {
        double rMax = sqrt(10.0 * i / 100.0) * 2.0 * pow(197., 1.0/3.0) * 1.2;
        if (b <= rMax) return i - 1;
    }
    return -1;
}

float range_delta_phi(float dphi) {
    while (dphi > TMath::Pi()) dphi -= 2 * TMath::Pi();
    while (dphi < -TMath::Pi()) dphi += 2 * TMath::Pi();
    return dphi;
}

float range_phi(float phi) {
    while (phi > TMath::Pi()) phi -= 2 * TMath::Pi();
    while (phi < -TMath::Pi()) phi += 2 * TMath::Pi();
    return phi;
}

bool IsHadronData(const string& tree_name) {
    return (tree_name == "ampt" || 
            tree_name == "hadron_before_art" || 
            tree_name == "hadron_before_melting");
}

bool IsQuarkData(const string& tree_name) {
    return (tree_name == "zpc" || 
            tree_name == "parton_initial");
}

bool isTrackAccepted(int pid, float pT, float eta, float phi) {
    // Check if particle type is in our hadron list
    if (find(vec_pdg_hadron.begin(), vec_pdg_hadron.end(), pid) == vec_pdg_hadron.end()) 
        return false;
    
    // General cuts
    if (pT < 0.2 || abs(eta) > 0.8) return false;
    
    // Particle-specific cuts
    if (abs(pid) == 211) {  // pions
        if (pT < 0.2 || pT > 2.5) return false;
    }
    if (abs(pid) == 321) {  // kaons
        if (pT < 0.5 || pT > 2.5) return false;
    }
    if (abs(pid) == 2212 || abs(pid) == 2112) {  // protons/neutrons
        if (pT < 0.7 || pT > 5.0) return false;
    }
    if (abs(pid) == 333) {  // phi
        if (pT < 0.3 || pT > 4.3) return false;
    }
    if (abs(pid) == 3122) {  // Lambda
        if (pT < 1.0 || pT > 10.0) return false;
    }
    
    return true;
}

bool isQuarkAccepted(int pid, float pT, float eta, float phi) {
    // Check if particle type is in our quark list (u, d, s and antiquarks)
    if (find(vec_pdg_quark.begin(), vec_pdg_quark.end(), pid) == vec_pdg_quark.end()) 
        return false;
    
    // General kinematic cuts for quarks
    if (pT < 0.1 || abs(eta) > 1.0) return false;  // Quarks can have lower pT
    
    // Quark-specific cuts (less restrictive than hadrons)
    if (abs(pid) <= 3) {  // u, d, s quarks and antiquarks
        if (pT > 20.0) return false;  // Upper limit for realistic quark pT
    }
    
    return true;
}