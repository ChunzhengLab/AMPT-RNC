#include "root_interface.h"
#include <iostream>
#include <cstring>

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

extern "C" {

void init_root_() {
    std::cout << "DEBUG: init_root() called" << std::endl;
    
    // Create ROOT file
    ampt_file = new TFile("ana/ampt.root", "RECREATE");
    if (!ampt_file || ampt_file->IsZombie()) {
        std::cerr << "ERROR: Cannot create ROOT file" << std::endl;
        return;
    }
    
    // Create tree
    ampt_tree = new TTree("ampt", "AMPT final hadrons");
    
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
    std::cout << "DEBUG: finalize_root() called" << std::endl;
    
    if (ampt_file && ampt_tree) {
        std::cout << "DEBUG: Tree entries before write: " << ampt_tree->GetEntries() << std::endl;
        ampt_file->cd();
        ampt_tree->Write();  // Simple write without flags
        ampt_file->Close();
        delete ampt_file;
        ampt_file = nullptr;
        ampt_tree = nullptr;
        
        std::cout << "ROOT interface finalized" << std::endl;
    }
}

void write_ampt_event_header_(int* eventID, int* runID, int* nParticles, double* b,
                            int* np1, int* np2, int* nelp, int* ninp, int* nelt, int* nint, double* phiRP) {
    std::cout << "DEBUG: write_ampt_event_header() called with eventID=" << *eventID 
              << " nParticles=" << *nParticles << std::endl;
    
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
    
    // Debug output for first few particles with ALL parameters
    if (particle_count < 3) {
        std::cout << "DEBUG: write_ampt_particle() particle " << (particle_count + 1) 
                  << " RECEIVED:" << std::endl;
        std::cout << "  pid=" << *pid << " px=" << *px << " py=" << *py << " pz=" << *pz 
                  << " mass=" << *mass << std::endl;
        std::cout << "  x=" << *x << " y=" << *y << " z=" << *z << " t=" << *t << std::endl;
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
    
    // Progress output
    if (particle_count % 1000 == 0) {
        std::cout << "DEBUG: Processed " << particle_count << " particles" << std::endl;
    }
    
    // When we have all particles, fill the tree
    if (particle_count == current_nParticles) {
        if (ampt_tree) {
            ampt_tree->Fill();
            std::cout << "DEBUG: Event " << current_eventID << " filled to ROOT tree with " 
                      << particle_count << " particles" << std::endl;
        }
    }
}

} // extern "C"