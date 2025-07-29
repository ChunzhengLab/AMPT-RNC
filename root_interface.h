#ifndef ROOT_INTERFACE_SIMPLE_H
#define ROOT_INTERFACE_SIMPLE_H

// Simple ROOT interface for AMPT without complex classes
// Based on the successful test_root_simple.cpp approach

#include <TFile.h>
#include <TTree.h>

// Global variables for ROOT interface
extern TFile* ampt_file;
extern TTree* ampt_tree;

// Event data structure (simple arrays)
const int MAX_PARTICLES = 99999;
extern int current_eventID;
extern int current_runID;
extern int current_nParticles;
extern double current_impactParameter;
extern int current_npart1, current_npart2;
extern int current_nelp, current_ninp, current_nelt, current_ninthj;
extern double current_phiRP;

// Particle arrays - using double to match Fortran real*8
extern int particle_pid[MAX_PARTICLES];
extern double particle_px[MAX_PARTICLES];
extern double particle_py[MAX_PARTICLES];
extern double particle_pz[MAX_PARTICLES];
extern double particle_mass[MAX_PARTICLES];
extern double particle_x[MAX_PARTICLES];
extern double particle_y[MAX_PARTICLES];
extern double particle_z[MAX_PARTICLES];
extern double particle_t[MAX_PARTICLES];

// Current particle counter
extern int particle_count;

// C interface functions for Fortran - using double to match Fortran real*8
extern "C" {
    void init_root_();
    void finalize_root_();
    void write_ampt_event_header_(int* eventID, int* runID, int* nParticles, double* b,
                                int* np1, int* np2, int* nelp, int* ninp, int* nelt, int* nint, double* phiRP);
    void write_ampt_particle_(int* pid, double* px, double* py, double* pz, double* mass,
                            double* x, double* y, double* z, double* t);
    void write_parton_initial_event_header_(int* eventID, int* miss, int* nParticles, double* b);
}

#endif