#include "root_interface.h"
#include <iostream>
#include <cstring>
#include "analysis_core.h"

// Global variables definition
TFile* ampt_file = nullptr;
TTree* ampt_tree = nullptr;

// Event data
int current_eventID;
int current_runID;
int current_nParticles;
double current_impactParameter;
int current_npart1, current_npart2;
int current_nelp, current_ninp, current_nelt, current_ninthj;
double current_phiRP;

// Particle arrays
int particle_pid[MAX_PARTICLES];
double particle_px[MAX_PARTICLES];
double particle_py[MAX_PARTICLES];
double particle_pz[MAX_PARTICLES];
double particle_mass[MAX_PARTICLES];
double particle_x[MAX_PARTICLES];
double particle_y[MAX_PARTICLES];
double particle_z[MAX_PARTICLES];
double particle_t[MAX_PARTICLES];

// Current particle counter
int particle_count = 0;

// Additional data for specialized files
int current_miss = 0;

extern "C" {

void init_root_() {
    
    // Initialize real-time analysis
    init_analysis_();
    
    // Create ROOT file
    ampt_file = new TFile("ana/ampt.root", "RECREATE");
    if (!ampt_file || ampt_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create ROOT file" << std::endl;
        return;
    }
    
    // Create tree
    ampt_tree = new TTree("ampt", "AMPT final hadrons");
    
    // 关键内存管理设置 - 解决200事件内存累积问题
    ampt_tree->SetAutoFlush(50);              // 每50个事件刷盘，更可预测的内存管理
    ampt_tree->SetAutoSave(200);              // 每200个事件创建恢复点（适合200事件任务）
    
    // Create branches - event header
    ampt_tree->Branch("eventID", &current_eventID, "eventID/I");
    ampt_tree->Branch("runID", &current_runID, "runID/I");  
    ampt_tree->Branch("nParticles", &current_nParticles, "nParticles/I");
    ampt_tree->Branch("impactParameter", &current_impactParameter, "impactParameter/D");
    ampt_tree->Branch("npart1", &current_npart1, "npart1/I");
    ampt_tree->Branch("npart2", &current_npart2, "npart2/I");
    ampt_tree->Branch("nelp", &current_nelp, "nelp/I");
    ampt_tree->Branch("ninp", &current_ninp, "ninp/I");
    ampt_tree->Branch("nelt", &current_nelt, "nelt/I");
    ampt_tree->Branch("ninthj", &current_ninthj, "ninthj/I");
    ampt_tree->Branch("phiRP", &current_phiRP, "phiRP/D");
    
    // Create branches - particle arrays (using D for double)
    ampt_tree->Branch("pid", particle_pid, "pid[nParticles]/I");
    ampt_tree->Branch("px", particle_px, "px[nParticles]/D");
    ampt_tree->Branch("py", particle_py, "py[nParticles]/D");
    ampt_tree->Branch("pz", particle_pz, "pz[nParticles]/D");
    ampt_tree->Branch("mass", particle_mass, "mass[nParticles]/D");
    ampt_tree->Branch("x", particle_x, "x[nParticles]/D");
    ampt_tree->Branch("y", particle_y, "y[nParticles]/D");
    ampt_tree->Branch("z", particle_z, "z[nParticles]/D");
    ampt_tree->Branch("t", particle_t, "t[nParticles]/D");
    
    std::cout << "ROOT interface initialized" << std::endl;
}

void finalize_root_() {
    
    if (ampt_file && ampt_tree) {
        ampt_file->cd();
        // 强制保存所有数据并刷新basket，确保数据完整性
        ampt_tree->AutoSave("SaveSelf;FlushBaskets");
        ampt_tree->Write();  // Simple write without flags
        ampt_file->Close();
        delete ampt_file;
        ampt_file = nullptr;
        ampt_tree = nullptr;
        
        std::cout << "ROOT interface finalized" << std::endl;
    }
    
    // Finalize real-time analysis
    finalize_analysis_();
}

void write_ampt_event_header_(int* eventID, int* runID, int* nParticles, double* b,
                            int* np1, int* np2, int* nelp, int* ninp, int* nelt, int* nint, double* phiRP) {
    
    // Store event header data
    current_eventID = *eventID;
    current_runID = *runID;
    current_nParticles = *nParticles;
    current_impactParameter = *b;
    current_npart1 = *np1;
    current_npart2 = *np2;
    current_nelp = *nelp;
    current_ninp = *ninp;
    current_nelt = *nelt;
    current_ninthj = *nint;
    current_phiRP = *phiRP;
    
    // Reset particle counter
    particle_count = 0;
    
    // Initialize arrays to zero
    memset(particle_pid, 0, sizeof(particle_pid));
    memset(particle_px, 0, sizeof(particle_px));
    memset(particle_py, 0, sizeof(particle_py));
    memset(particle_pz, 0, sizeof(particle_pz));
    memset(particle_mass, 0, sizeof(particle_mass));
    memset(particle_x, 0, sizeof(particle_x));
    memset(particle_y, 0, sizeof(particle_y));
    memset(particle_z, 0, sizeof(particle_z));
    memset(particle_t, 0, sizeof(particle_t));
}

void write_ampt_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                        double* x, double* y, double* z, double* t) {
    if (particle_count >= MAX_PARTICLES) {
        std::cerr << "ERROR: Too many particles, limit is " << MAX_PARTICLES << std::endl;
        return;
    }
    
    
    // Store particle data
    particle_pid[particle_count] = *pid;
    particle_px[particle_count] = *px;
    particle_py[particle_count] = *py;
    particle_pz[particle_count] = *pz;
    particle_mass[particle_count] = *mass;
    particle_x[particle_count] = *x;
    particle_y[particle_count] = *y;
    particle_z[particle_count] = *z;
    particle_t[particle_count] = *t;
    
    particle_count++;
    
    
    // When we have all particles, fill the tree and analyze event
    if (particle_count == current_nParticles) {
        if (ampt_tree) {
            ampt_tree->Fill();
        }
        
        // Perform real-time analysis on completed event
        analyze_current_event_();
    }
}

// ===== ZPC ROOT interface =====
TFile* zpc_file = nullptr;
TTree* zpc_tree = nullptr;
int zpc_particle_count = 0;

void init_zpc_root_() {
    
    zpc_file = new TFile("ana/zpc.root", "RECREATE");
    if (!zpc_file || zpc_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create zpc ROOT file" << std::endl;
        return;
    }
    
    zpc_tree = new TTree("zpc", "AMPT zero momentum frame partons");
    
    // 内存管理设置
    zpc_tree->SetAutoFlush(50);
    zpc_tree->SetAutoSave(200);
    
    // Create branches - event header (IAEVT, MISS, MUL, bimp, NELP, NINP, NELT, NINTHJ)
    zpc_tree->Branch("eventID", &current_eventID, "eventID/I");
    zpc_tree->Branch("miss", &current_miss, "miss/I");
    zpc_tree->Branch("nParticles", &current_nParticles, "nParticles/I");
    zpc_tree->Branch("impactParameter", &current_impactParameter, "impactParameter/D");
    zpc_tree->Branch("nelp", &current_nelp, "nelp/I");
    zpc_tree->Branch("ninp", &current_ninp, "ninp/I");
    zpc_tree->Branch("nelt", &current_nelt, "nelt/I");
    zpc_tree->Branch("ninthj", &current_ninthj, "ninthj/I");
    
    // Create branches - particle arrays (ITYP5, PX5, PY5, PZ5, XMASS5, GX5, GY5, GZ5, FT5)
    zpc_tree->Branch("pid", particle_pid, "pid[nParticles]/I");
    zpc_tree->Branch("px", particle_px, "px[nParticles]/D");
    zpc_tree->Branch("py", particle_py, "py[nParticles]/D");
    zpc_tree->Branch("pz", particle_pz, "pz[nParticles]/D");
    zpc_tree->Branch("mass", particle_mass, "mass[nParticles]/D");
    zpc_tree->Branch("x", particle_x, "x[nParticles]/D");
    zpc_tree->Branch("y", particle_y, "y[nParticles]/D");
    zpc_tree->Branch("z", particle_z, "z[nParticles]/D");
    zpc_tree->Branch("t", particle_t, "t[nParticles]/D");
    
    std::cout << "ZPC ROOT interface initialized" << std::endl;
}

void finalize_zpc_root_() {
    
    if (zpc_file && zpc_tree) {
        zpc_file->cd();
        zpc_tree->AutoSave("SaveSelf;FlushBaskets");
        zpc_tree->Write();
        zpc_file->Close();
        delete zpc_file;
        zpc_file = nullptr;
        zpc_tree = nullptr;
        
        std::cout << "ZPC ROOT interface finalized" << std::endl;
    }
}

void write_zpc_event_header_(int* eventID, int* miss, int* nParticles, double* b,
                            int* nelp, int* ninp, int* nelt, int* ninthj) {
    
    current_eventID = *eventID;
    current_miss = *miss;
    current_nParticles = *nParticles;
    current_impactParameter = *b;
    current_nelp = *nelp;
    current_ninp = *ninp;
    current_nelt = *nelt;
    current_ninthj = *ninthj;
    
    zpc_particle_count = 0;
    
    // Initialize arrays
    memset(particle_pid, 0, sizeof(particle_pid));
    memset(particle_px, 0, sizeof(particle_px));
    memset(particle_py, 0, sizeof(particle_py));
    memset(particle_pz, 0, sizeof(particle_pz));
    memset(particle_mass, 0, sizeof(particle_mass));
    memset(particle_x, 0, sizeof(particle_x));
    memset(particle_y, 0, sizeof(particle_y));
    memset(particle_z, 0, sizeof(particle_z));
    memset(particle_t, 0, sizeof(particle_t));
}

void write_zpc_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                        double* x, double* y, double* z, double* t) {
    if (zpc_particle_count >= MAX_PARTICLES) {
        std::cerr << "ERROR: Too many ZPC particles, limit is " << MAX_PARTICLES << std::endl;
        return;
    }
    
    
    particle_pid[zpc_particle_count] = *pid;
    particle_px[zpc_particle_count] = *px;
    particle_py[zpc_particle_count] = *py;
    particle_pz[zpc_particle_count] = *pz;
    particle_mass[zpc_particle_count] = *mass;
    particle_x[zpc_particle_count] = *x;
    particle_y[zpc_particle_count] = *y;
    particle_z[zpc_particle_count] = *z;
    particle_t[zpc_particle_count] = *t;
    
    zpc_particle_count++;
    
    
    if (zpc_particle_count == current_nParticles) {
        if (zpc_tree) {
            zpc_tree->Fill();
        }
        
        // Perform real-time analysis on completed ZPC event
        analyze_zpc_event_();
    }
}

// ===== PARTON INITIAL ROOT interface =====
TFile* parton_file = nullptr;
TTree* parton_tree = nullptr;
int parton_particle_count = 0;

// Additional arrays for parton data (12 fields total)
int parton_istrg0[MAX_PARTICLES];
double parton_xstrg0[MAX_PARTICLES];
double parton_ystrg0[MAX_PARTICLES];

void init_parton_initial_root_() {
    
    parton_file = new TFile("ana/parton-initial.root", "RECREATE");
    if (!parton_file || parton_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create parton initial ROOT file" << std::endl;
        return;
    }
    
    parton_tree = new TTree("parton_initial", "AMPT initial partons after propagation");
    
    // 内存管理设置
    parton_tree->SetAutoFlush(50);
    parton_tree->SetAutoSave(200);
    
    // Create branches - event header (iaevt, miss, mul, bimp)
    parton_tree->Branch("eventID", &current_eventID, "eventID/I");
    parton_tree->Branch("miss", &current_miss, "miss/I");
    parton_tree->Branch("nParticles", &current_nParticles, "nParticles/I");
    parton_tree->Branch("impactParameter", &current_impactParameter, "impactParameter/D");
    
    // Create branches - particle arrays (12 fields: ityp, px, py, pz, xmass, gx, gy, gz, ft, istrg0, xstrg0, ystrg0)
    parton_tree->Branch("pid", particle_pid, "pid[nParticles]/I");
    parton_tree->Branch("px", particle_px, "px[nParticles]/D");
    parton_tree->Branch("py", particle_py, "py[nParticles]/D");
    parton_tree->Branch("pz", particle_pz, "pz[nParticles]/D");
    parton_tree->Branch("mass", particle_mass, "mass[nParticles]/D");
    parton_tree->Branch("x", particle_x, "x[nParticles]/D");
    parton_tree->Branch("y", particle_y, "y[nParticles]/D");
    parton_tree->Branch("z", particle_z, "z[nParticles]/D");
    parton_tree->Branch("t", particle_t, "t[nParticles]/D");
    parton_tree->Branch("istrg0", parton_istrg0, "istrg0[nParticles]/I");
    parton_tree->Branch("xstrg0", parton_xstrg0, "xstrg0[nParticles]/D");
    parton_tree->Branch("ystrg0", parton_ystrg0, "ystrg0[nParticles]/D");
    
    std::cout << "Parton initial ROOT interface initialized" << std::endl;
}

void finalize_parton_initial_root_() {
    
    if (parton_file && parton_tree) {
        parton_file->cd();
        parton_tree->AutoSave("SaveSelf;FlushBaskets");
        parton_tree->Write();
        parton_file->Close();
        delete parton_file;
        parton_file = nullptr;
        parton_tree = nullptr;
        
        std::cout << "Parton initial ROOT interface finalized" << std::endl;
    }
}

void write_parton_initial_event_header_(int* eventID, int* miss, int* nParticles, double* b) {
    
    current_eventID = *eventID;
    current_miss = *miss;
    current_nParticles = *nParticles;
    current_impactParameter = *b;
    
    parton_particle_count = 0;
    
    // Initialize arrays
    memset(particle_pid, 0, sizeof(particle_pid));
    memset(particle_px, 0, sizeof(particle_px));
    memset(particle_py, 0, sizeof(particle_py));
    memset(particle_pz, 0, sizeof(particle_pz));
    memset(particle_mass, 0, sizeof(particle_mass));
    memset(particle_x, 0, sizeof(particle_x));
    memset(particle_y, 0, sizeof(particle_y));
    memset(particle_z, 0, sizeof(particle_z));
    memset(particle_t, 0, sizeof(particle_t));
    memset(parton_istrg0, 0, sizeof(parton_istrg0));
    memset(parton_xstrg0, 0, sizeof(parton_xstrg0));
    memset(parton_ystrg0, 0, sizeof(parton_ystrg0));
}

void write_parton_initial_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                                   double* x, double* y, double* z, double* t, 
                                   int* istrg0, double* xstrg0, double* ystrg0) {
    if (parton_particle_count >= MAX_PARTICLES) {
        std::cerr << "ERROR: Too many parton particles, limit is " << MAX_PARTICLES << std::endl;
        return;
    }
    
    
    particle_pid[parton_particle_count] = *pid;
    particle_px[parton_particle_count] = *px;
    particle_py[parton_particle_count] = *py;
    particle_pz[parton_particle_count] = *pz;
    particle_mass[parton_particle_count] = *mass;
    particle_x[parton_particle_count] = *x;
    particle_y[parton_particle_count] = *y;
    particle_z[parton_particle_count] = *z;
    particle_t[parton_particle_count] = *t;
    parton_istrg0[parton_particle_count] = *istrg0;
    parton_xstrg0[parton_particle_count] = *xstrg0;
    parton_ystrg0[parton_particle_count] = *ystrg0;
    
    parton_particle_count++;
    
    
    if (parton_particle_count == current_nParticles) {
        if (parton_tree) {
            parton_tree->Fill();
        }
        
        // Perform real-time analysis on completed parton event
        analyze_parton_event_();
    }
}

// ===== HADRONS BEFORE ART ROOT interface =====
TFile* hadron_before_art_file = nullptr;
TTree* hadron_before_art_tree = nullptr;
int hadron_before_art_particle_count = 0;

void init_hadron_before_art_root_() {
    
    hadron_before_art_file = new TFile("ana/hadron-before-art.root", "RECREATE");
    if (!hadron_before_art_file || hadron_before_art_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create hadron before ART ROOT file" << std::endl;
        return;
    }
    
    hadron_before_art_tree = new TTree("hadron_before_art", "AMPT hadrons before ART cascade");
    
    // 内存管理设置
    hadron_before_art_tree->SetAutoFlush(50);
    hadron_before_art_tree->SetAutoSave(200);
    
    // Create branches - event header (J(IAEVT), MISS, IAINT2(1), bimp, NELP, NINP, NELT, NINTHJ)
    hadron_before_art_tree->Branch("eventID", &current_eventID, "eventID/I");
    hadron_before_art_tree->Branch("miss", &current_miss, "miss/I");
    hadron_before_art_tree->Branch("nParticles", &current_nParticles, "nParticles/I");
    hadron_before_art_tree->Branch("impactParameter", &current_impactParameter, "impactParameter/D");
    hadron_before_art_tree->Branch("nelp", &current_nelp, "nelp/I");
    hadron_before_art_tree->Branch("ninp", &current_ninp, "ninp/I");
    hadron_before_art_tree->Branch("nelt", &current_nelt, "nelt/I");
    hadron_before_art_tree->Branch("ninthj", &current_ninthj, "ninthj/I");
    
    // Create branches - particle arrays (standard 9 fields)
    hadron_before_art_tree->Branch("pid", particle_pid, "pid[nParticles]/I");
    hadron_before_art_tree->Branch("px", particle_px, "px[nParticles]/D");
    hadron_before_art_tree->Branch("py", particle_py, "py[nParticles]/D");
    hadron_before_art_tree->Branch("pz", particle_pz, "pz[nParticles]/D");
    hadron_before_art_tree->Branch("mass", particle_mass, "mass[nParticles]/D");
    hadron_before_art_tree->Branch("x", particle_x, "x[nParticles]/D");
    hadron_before_art_tree->Branch("y", particle_y, "y[nParticles]/D");
    hadron_before_art_tree->Branch("z", particle_z, "z[nParticles]/D");
    hadron_before_art_tree->Branch("t", particle_t, "t[nParticles]/D");
    
    std::cout << "Hadron before ART ROOT interface initialized" << std::endl;
}

void finalize_hadron_before_art_root_() {
    
    if (hadron_before_art_file && hadron_before_art_tree) {
        hadron_before_art_file->cd();
        hadron_before_art_tree->AutoSave("SaveSelf;FlushBaskets");
        hadron_before_art_tree->Write();
        hadron_before_art_file->Close();
        delete hadron_before_art_file;
        hadron_before_art_file = nullptr;
        hadron_before_art_tree = nullptr;
        
        std::cout << "Hadron before ART ROOT interface finalized" << std::endl;
    }
}

void write_hadron_before_art_event_header_(int* eventID, int* miss, int* nParticles, double* b,
                                           int* nelp, int* ninp, int* nelt, int* ninthj) {
    
    current_eventID = *eventID;
    current_miss = *miss;
    current_nParticles = *nParticles;
    current_impactParameter = *b;
    current_nelp = *nelp;
    current_ninp = *ninp;
    current_nelt = *nelt;
    current_ninthj = *ninthj;
    
    hadron_before_art_particle_count = 0;
    
    // Initialize arrays
    memset(particle_pid, 0, sizeof(particle_pid));
    memset(particle_px, 0, sizeof(particle_px));
    memset(particle_py, 0, sizeof(particle_py));
    memset(particle_pz, 0, sizeof(particle_pz));
    memset(particle_mass, 0, sizeof(particle_mass));
    memset(particle_x, 0, sizeof(particle_x));
    memset(particle_y, 0, sizeof(particle_y));
    memset(particle_z, 0, sizeof(particle_z));
    memset(particle_t, 0, sizeof(particle_t));
}

void write_hadron_before_art_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                                       double* x, double* y, double* z, double* t) {
    if (hadron_before_art_particle_count >= MAX_PARTICLES) {
        std::cerr << "ERROR: Too many hadron before ART particles, limit is " << MAX_PARTICLES << std::endl;
        return;
    }
    
    
    particle_pid[hadron_before_art_particle_count] = *pid;
    particle_px[hadron_before_art_particle_count] = *px;
    particle_py[hadron_before_art_particle_count] = *py;
    particle_pz[hadron_before_art_particle_count] = *pz;
    particle_mass[hadron_before_art_particle_count] = *mass;
    particle_x[hadron_before_art_particle_count] = *x;
    particle_y[hadron_before_art_particle_count] = *y;
    particle_z[hadron_before_art_particle_count] = *z;
    particle_t[hadron_before_art_particle_count] = *t;
    
    hadron_before_art_particle_count++;
    
    
    if (hadron_before_art_particle_count == current_nParticles) {
        if (hadron_before_art_tree) {
            hadron_before_art_tree->Fill();
        }
    }
}

// ===== HADRON BEFORE MELTING ROOT interface =====
TFile* hadron_before_melting_file = nullptr;
TTree* hadron_before_melting_tree = nullptr;
int hadron_before_melting_particle_count = 0;

void init_hadron_before_melting_root_() {
    
    hadron_before_melting_file = new TFile("ana/hadron-before-melting.root", "RECREATE");
    if (!hadron_before_melting_file || hadron_before_melting_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create hadron-before-melting.root file" << std::endl;
        return;
    }
    
    hadron_before_melting_tree = new TTree("hadron_before_melting", "AMPT hadrons before string melting");
    
    // 内存管理设置
    hadron_before_melting_tree->SetAutoFlush(50);
    hadron_before_melting_tree->SetAutoSave(200);
    
    // Event header branches
    hadron_before_melting_tree->Branch("eventID", &current_eventID, "eventID/I");
    hadron_before_melting_tree->Branch("miss", &current_miss, "miss/I");
    hadron_before_melting_tree->Branch("nParticles", &current_nParticles, "nParticles/I");
    hadron_before_melting_tree->Branch("impactParameter", &current_impactParameter, "impactParameter/D");
    hadron_before_melting_tree->Branch("nelp", &current_nelp, "nelp/I");
    hadron_before_melting_tree->Branch("ninp", &current_ninp, "ninp/I");
    hadron_before_melting_tree->Branch("nelt", &current_nelt, "nelt/I");
    hadron_before_melting_tree->Branch("ninthj", &current_ninthj, "ninthj/I");
    
    // Particle data branches
    hadron_before_melting_tree->Branch("pid", particle_pid, "pid[nParticles]/I");
    hadron_before_melting_tree->Branch("px", particle_px, "px[nParticles]/D");
    hadron_before_melting_tree->Branch("py", particle_py, "py[nParticles]/D");
    hadron_before_melting_tree->Branch("pz", particle_pz, "pz[nParticles]/D");
    hadron_before_melting_tree->Branch("mass", particle_mass, "mass[nParticles]/D");
    hadron_before_melting_tree->Branch("x", particle_x, "x[nParticles]/D");
    hadron_before_melting_tree->Branch("y", particle_y, "y[nParticles]/D");
    hadron_before_melting_tree->Branch("z", particle_z, "z[nParticles]/D");
    hadron_before_melting_tree->Branch("t", particle_t, "t[nParticles]/D");
    
    std::cout << "Hadron before melting ROOT interface initialized" << std::endl;
}

void finalize_hadron_before_melting_root_() {
    
    if (hadron_before_melting_file && hadron_before_melting_tree) {
        hadron_before_melting_file->cd();
        hadron_before_melting_tree->AutoSave("SaveSelf;FlushBaskets");
        hadron_before_melting_tree->Write();
        hadron_before_melting_file->Close();
        delete hadron_before_melting_file;
        hadron_before_melting_file = nullptr;
        hadron_before_melting_tree = nullptr;
        
        std::cout << "Hadron before melting ROOT interface finalized" << std::endl;
    }
}

void write_hadron_before_melting_event_header_(int* eventID, int* miss, int* nParticles, double* b,
                                             int* nelp, int* ninp, int* nelt, int* ninthj) {
    
    current_eventID = *eventID;
    current_miss = *miss;
    current_nParticles = *nParticles;
    current_impactParameter = *b;
    current_nelp = *nelp;
    current_ninp = *ninp;
    current_nelt = *nelt;
    current_ninthj = *ninthj;
    
    hadron_before_melting_particle_count = 0;
    
    // Clear arrays
    memset(particle_pid, 0, sizeof(particle_pid));
    memset(particle_px, 0, sizeof(particle_px));
    memset(particle_py, 0, sizeof(particle_py));
    memset(particle_pz, 0, sizeof(particle_pz));
    memset(particle_mass, 0, sizeof(particle_mass));
    memset(particle_x, 0, sizeof(particle_x));
    memset(particle_y, 0, sizeof(particle_y));
    memset(particle_z, 0, sizeof(particle_z));
    memset(particle_t, 0, sizeof(particle_t));
}

void write_hadron_before_melting_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                                         double* x, double* y, double* z, double* t) {
    if (hadron_before_melting_particle_count >= MAX_PARTICLES) {
        std::cerr << "ERROR: Too many hadron before melting particles, limit is " << MAX_PARTICLES << std::endl;
        return;
    }
    
    
    particle_pid[hadron_before_melting_particle_count] = *pid;
    particle_px[hadron_before_melting_particle_count] = *px;
    particle_py[hadron_before_melting_particle_count] = *py;
    particle_pz[hadron_before_melting_particle_count] = *pz;
    particle_mass[hadron_before_melting_particle_count] = *mass;
    particle_x[hadron_before_melting_particle_count] = *x;
    particle_y[hadron_before_melting_particle_count] = *y;
    particle_z[hadron_before_melting_particle_count] = *z;
    particle_t[hadron_before_melting_particle_count] = *t;
    
    hadron_before_melting_particle_count++;
    
    
    if (hadron_before_melting_particle_count == current_nParticles) {
        if (hadron_before_melting_tree) {
            hadron_before_melting_tree->Fill();
        }
    }
}

// ===== Real-time analysis implementation =====
void init_analysis_() {
    // Initialize analysis objects for different data streams
    if (!g_analysis_ampt) {
        g_analysis_ampt = new AnalysisCore();
        g_analysis_ampt->Initialize(true);  // hadron mode
        std::cout << "Real-time analysis for AMPT data initialized" << std::endl;
    }
    
    if (!g_analysis_zpc) {
        g_analysis_zpc = new AnalysisCore();
        g_analysis_zpc->Initialize(false);  // parton mode for ZPC
        std::cout << "Real-time analysis for ZPC data initialized" << std::endl;
    }
    
    if (!g_analysis_parton) {
        g_analysis_parton = new AnalysisCore();
        g_analysis_parton->Initialize(false);  // parton mode
        std::cout << "Real-time analysis for Parton data initialized" << std::endl;
    }
}

void finalize_analysis_() {
    // Save analysis results for all data streams
    if (g_analysis_ampt) {
        g_analysis_ampt->SaveResults("ana/ampt_analysis.root");
        delete g_analysis_ampt;
        g_analysis_ampt = nullptr;
        std::cout << "AMPT analysis results saved" << std::endl;
    }
    
    if (g_analysis_zpc) {
        g_analysis_zpc->SaveResults("ana/zpc_analysis.root");
        delete g_analysis_zpc;
        g_analysis_zpc = nullptr;
        std::cout << "ZPC analysis results saved" << std::endl;
    }
    
    if (g_analysis_parton) {
        g_analysis_parton->SaveResults("ana/parton-initial_analysis.root");
        delete g_analysis_parton;
        g_analysis_parton = nullptr;
        std::cout << "Parton analysis results saved" << std::endl;
    }
    
    std::cout << "Real-time analysis results saved" << std::endl;
}

void analyze_current_event_() {
    // Analyze the current complete event using the global particle arrays
    if (g_analysis_ampt && particle_count > 0) {
        // Create arrays for analysis (convert from global storage)
        double* px_array = new double[particle_count];
        double* py_array = new double[particle_count];
        double* pz_array = new double[particle_count];
        double* x_array = new double[particle_count];
        double* y_array = new double[particle_count];
        double* z_array = new double[particle_count];
        
        for (int i = 0; i < particle_count; i++) {
            px_array[i] = particle_px[i];
            py_array[i] = particle_py[i];
            pz_array[i] = particle_pz[i];
            x_array[i] = particle_x[i];
            y_array[i] = particle_y[i];
            z_array[i] = particle_z[i];
        }
        
        // Call analysis
        g_analysis_ampt->AnalyzeEvent(
            current_eventID,
            current_impactParameter,
            particle_count,
            particle_pid,
            px_array, py_array, pz_array,
            x_array, y_array, z_array
        );
        
        // Clean up
        delete[] px_array;
        delete[] py_array;
        delete[] pz_array;
        delete[] x_array;
        delete[] y_array;
        delete[] z_array;
    }
}

void analyze_zpc_event_() {
    // Analyze ZPC event
    if (g_analysis_zpc && zpc_particle_count > 0) {
        // Create arrays for analysis
        double* px_array = new double[zpc_particle_count];
        double* py_array = new double[zpc_particle_count];
        double* pz_array = new double[zpc_particle_count];
        double* x_array = new double[zpc_particle_count];
        double* y_array = new double[zpc_particle_count];
        double* z_array = new double[zpc_particle_count];
        
        for (int i = 0; i < zpc_particle_count; i++) {
            px_array[i] = particle_px[i];
            py_array[i] = particle_py[i];
            pz_array[i] = particle_pz[i];
            x_array[i] = particle_x[i];
            y_array[i] = particle_y[i];
            z_array[i] = particle_z[i];
        }
        
        // Call analysis
        g_analysis_zpc->AnalyzeEvent(
            current_eventID,
            current_impactParameter,
            zpc_particle_count,
            particle_pid,
            px_array, py_array, pz_array,
            x_array, y_array, z_array
        );
        
        // Clean up
        delete[] px_array;
        delete[] py_array;
        delete[] pz_array;
        delete[] x_array;
        delete[] y_array;
        delete[] z_array;
    }
}

void analyze_parton_event_() {
    // Analyze parton event
    if (g_analysis_parton && parton_particle_count > 0) {
        // Create arrays for analysis
        double* px_array = new double[parton_particle_count];
        double* py_array = new double[parton_particle_count];
        double* pz_array = new double[parton_particle_count];
        double* x_array = new double[parton_particle_count];
        double* y_array = new double[parton_particle_count];
        double* z_array = new double[parton_particle_count];
        
        for (int i = 0; i < parton_particle_count; i++) {
            px_array[i] = particle_px[i];
            py_array[i] = particle_py[i];
            pz_array[i] = particle_pz[i];
            x_array[i] = particle_x[i];
            y_array[i] = particle_y[i];
            z_array[i] = particle_z[i];
        }
        
        // Call analysis
        g_analysis_parton->AnalyzeEvent(
            current_eventID,
            current_impactParameter,
            parton_particle_count,
            particle_pid,
            px_array, py_array, pz_array,
            x_array, y_array, z_array
        );
        
        // Clean up
        delete[] px_array;
        delete[] py_array;
        delete[] pz_array;
        delete[] x_array;
        delete[] y_array;
        delete[] z_array;
    }
}

} // extern "C"