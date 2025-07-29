#!/bin/bash
# test_all_consistency.sh - 综合测试所有ROOT接口的数据一致性

echo "=== AMPT ROOT接口综合数据一致性测试 ==="
echo "测试时间: $(date)"

# 清理并运行一次新的模拟
echo -e "\n运行新的AMPT模拟..."
rm -f ana/*.root ana/*.dat ana/parton-initial-afterPropagation.dat
echo "20030819" | ./ampt > /tmp/ampt_output.log 2>&1

# 检查生成的文件
echo -e "\n生成的文件:"
ls -la ana/*.dat ana/*.root | awk '{print $9 " (" $5 " bytes)"}'

# ============ 1. AMPT.DAT 数据一致性测试 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. AMPT.DAT 数据一致性测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 事件头对比
echo -e "\n1.1 事件头对比:"
echo "dat文件事件头:"
head -1 ana/ampt.dat | awk '{printf "eventID=%s runID=%s nParticles=%s impactParameter=%s npart1=%s npart2=%s nelp=%s ninp=%s nelt=%s ninthj=%s phiRP=%s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11}'

echo "ROOT文件事件头:"
cat > /tmp/check_ampt_header.C << 'EOF'
void check_ampt_header() {
    TFile* f = TFile::Open("ana/ampt.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("ampt");
    if (!t) return;
    
    int eventID, runID, nParticles, npart1, npart2, nelp, ninp, nelt, ninthj;
    double impactParameter, phiRP;
    
    t->SetBranchAddress("eventID", &eventID);
    t->SetBranchAddress("runID", &runID);
    t->SetBranchAddress("nParticles", &nParticles);
    t->SetBranchAddress("impactParameter", &impactParameter);
    t->SetBranchAddress("npart1", &npart1);
    t->SetBranchAddress("npart2", &npart2);
    t->SetBranchAddress("nelp", &nelp);
    t->SetBranchAddress("ninp", &ninp);
    t->SetBranchAddress("nelt", &nelt);
    t->SetBranchAddress("ninthj", &ninthj);
    t->SetBranchAddress("phiRP", &phiRP);
    
    t->GetEntry(0);
    printf("eventID=%d runID=%d nParticles=%d impactParameter=%.4f npart1=%d npart2=%d nelp=%d ninp=%d nelt=%d ninthj=%d phiRP=%.4f\n",
           eventID, runID, nParticles, impactParameter, npart1, npart2, nelp, ninp, nelt, ninthj, phiRP);
    f->Close();
}
EOF
root -l -b -q /tmp/check_ampt_header.C 2>/dev/null | grep "eventID"

# 前3个粒子对比
echo -e "\n1.2 前3个粒子数据对比:"
echo "dat文件数据:"
awk 'NR>1 && NR<=4 {printf "粒子%d: pid=%s px=%s py=%s pz=%s mass=%s x=%s y=%s z=%s t=%s\n", NR-1, $1, $2, $3, $4, $5, $6, $7, $8, $9}' ana/ampt.dat

echo "ROOT文件数据:"
cat > /tmp/check_ampt_particles.C << 'EOF'
void check_ampt_particles() {
    TFile* f = TFile::Open("ana/ampt.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("ampt");
    if (!t) return;
    
    int nPart;
    double px[10000], py[10000], pz[10000], mass[10000];
    double x[10000], y[10000], z[10000], tt[10000];
    int pid[10000];
    
    t->SetBranchAddress("nParticles", &nPart);
    t->SetBranchAddress("pid", pid);
    t->SetBranchAddress("px", px);
    t->SetBranchAddress("py", py);
    t->SetBranchAddress("pz", pz);
    t->SetBranchAddress("mass", mass);
    t->SetBranchAddress("x", x);
    t->SetBranchAddress("y", y);
    t->SetBranchAddress("z", z);
    t->SetBranchAddress("t", tt);
    
    t->GetEntry(0);
    
    for(int i=0; i<3 && i<nPart; i++) {
        printf("粒子%d: pid=%d px=%.3f py=%.3f pz=%.4f mass=%.4f x=%.5f y=%.5f z=%.6f t=%.1f\n", 
               i+1, pid[i], px[i], py[i], pz[i], mass[i], x[i], y[i], z[i], tt[i]);
    }
    f->Close();
}
EOF
root -l -b -q /tmp/check_ampt_particles.C 2>/dev/null | grep "粒子"

# ============ 2. ZPC.DAT 数据一致性测试 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. ZPC.DAT 数据一致性测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "ana/zpc.dat" ]; then
    # 事件头对比
    echo -e "\n2.1 事件头对比:"
    echo "dat文件事件头:"
    head -1 ana/zpc.dat | awk '{printf "eventID=%s miss=%s nParticles=%s impactParameter=%s nelp=%s ninp=%s nelt=%s ninthj=%s\n", $1, $2, $3, $4, $5, $6, $7, $8}'
    
    echo "ROOT文件事件头:"
    cat > /tmp/check_zpc_header.C << 'EOF'
void check_zpc_header() {
    TFile* f = TFile::Open("ana/zpc.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("zpc");
    if (!t) return;
    
    int eventID, miss, nParticles, nelp, ninp, nelt, ninthj;
    double impactParameter;
    
    t->SetBranchAddress("eventID", &eventID);
    t->SetBranchAddress("miss", &miss);
    t->SetBranchAddress("nParticles", &nParticles);
    t->SetBranchAddress("impactParameter", &impactParameter);
    t->SetBranchAddress("nelp", &nelp);
    t->SetBranchAddress("ninp", &ninp);
    t->SetBranchAddress("nelt", &nelt);
    t->SetBranchAddress("ninthj", &ninthj);
    
    t->GetEntry(0);
    printf("eventID=%d miss=%d nParticles=%d impactParameter=%.4f nelp=%d ninp=%d nelt=%d ninthj=%d\n",
           eventID, miss, nParticles, impactParameter, nelp, ninp, nelt, ninthj);
    f->Close();
}
EOF
    root -l -b -q /tmp/check_zpc_header.C 2>/dev/null | grep "eventID"
    
    # 前3个粒子对比
    echo -e "\n2.2 前3个粒子数据对比:"
    echo "dat文件数据:"
    awk 'NR>1 && NR<=4 {printf "粒子%d: pid=%s px=%s py=%s pz=%s mass=%s x=%s y=%s z=%s t=%s\n", NR-1, $1, $2, $3, $4, $5, $6, $7, $8, $9}' ana/zpc.dat
    
    echo "ROOT文件数据:"
    cat > /tmp/check_zpc_particles.C << 'EOF'
void check_zpc_particles() {
    TFile* f = TFile::Open("ana/zpc.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("zpc");
    if (!t) return;
    
    int nPart;
    double px[20000], py[20000], pz[20000], mass[20000];
    double x[20000], y[20000], z[20000], tt[20000];
    int pid[20000];
    
    t->SetBranchAddress("nParticles", &nPart);
    t->SetBranchAddress("pid", pid);
    t->SetBranchAddress("px", px);
    t->SetBranchAddress("py", py);
    t->SetBranchAddress("pz", pz);
    t->SetBranchAddress("mass", mass);
    t->SetBranchAddress("x", x);
    t->SetBranchAddress("y", y);
    t->SetBranchAddress("z", z);
    t->SetBranchAddress("t", tt);
    
    t->GetEntry(0);
    
    for(int i=0; i<3 && i<nPart; i++) {
        printf("粒子%d: pid=%d px=%.6f py=%.6f pz=%.6f mass=%.4f x=%.5f y=%.5f z=%.5f t=%.2f\n", 
               i+1, pid[i], px[i], py[i], pz[i], mass[i], x[i], y[i], z[i], tt[i]);
    }
    f->Close();
}
EOF
    root -l -b -q /tmp/check_zpc_particles.C 2>/dev/null | grep "粒子"
else
    echo "ZPC.dat文件未生成（可能因为isoft设置）"
fi

# ============ 3. PARTON-INITIAL-AFTERPROPAGATION.DAT 数据一致性测试 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. PARTON-INITIAL-AFTERPROPAGATION.DAT 数据一致性测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "ana/parton-initial-afterPropagation.dat" ]; then
    # 事件头对比
    echo -e "\n3.1 事件头对比:"
    echo "dat文件事件头:"
    head -1 ana/parton-initial-afterPropagation.dat | awk '{printf "eventID=%s miss=%s nParticles=%s\n", $1, $2, $3}'
    
    echo "ROOT文件事件头:"
    cat > /tmp/check_parton_header.C << 'EOF'
void check_parton_header() {
    TFile* f = TFile::Open("ana/parton-initial.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("parton_initial");
    if (!t) return;
    
    int eventID, miss, nParticles;
    t->SetBranchAddress("eventID", &eventID);
    t->SetBranchAddress("miss", &miss);
    t->SetBranchAddress("nParticles", &nParticles);
    
    t->GetEntry(0);
    printf("eventID=%d miss=%d nParticles=%d\n", eventID, miss, nParticles);
    f->Close();
}
EOF
    root -l -b -q /tmp/check_parton_header.C 2>/dev/null | grep "eventID"
    
    # 前3个粒子对比
    echo -e "\n3.2 前3个粒子数据对比:"
    echo "dat文件数据:"
    awk 'NR>1 && NR<=4 {printf "粒子%d: pid=%s px=%.2f py=%.2f pz=%.2f mass=%.3f x=%.2f y=%.2f z=%.2f t=%.2f istrg0=%s xstrg0=%.2f ystrg0=%.2f\n", NR-1, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12}' ana/parton-initial-afterPropagation.dat
    
    echo "ROOT文件数据:"
    cat > /tmp/check_parton_particles.C << 'EOF'
void check_parton_particles() {
    TFile* f = TFile::Open("ana/parton-initial.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("parton_initial");
    if (!t) return;
    
    int nPart;
    double px[20000], py[20000], pz[20000], mass[20000];
    double x[20000], y[20000], z[20000], tt[20000];
    int pid[20000], istrg0[20000];
    double xstrg0[20000], ystrg0[20000];
    
    t->SetBranchAddress("nParticles", &nPart);
    t->SetBranchAddress("pid", pid);
    t->SetBranchAddress("px", px);
    t->SetBranchAddress("py", py);
    t->SetBranchAddress("pz", pz);
    t->SetBranchAddress("mass", mass);
    t->SetBranchAddress("x", x);
    t->SetBranchAddress("y", y);
    t->SetBranchAddress("z", z);
    t->SetBranchAddress("t", tt);
    t->SetBranchAddress("istrg0", istrg0);
    t->SetBranchAddress("xstrg0", xstrg0);
    t->SetBranchAddress("ystrg0", ystrg0);
    
    t->GetEntry(0);
    
    for(int i=0; i<3 && i<nPart; i++) {
        printf("粒子%d: pid=%d px=%.2f py=%.2f pz=%.2f mass=%.3f x=%.2f y=%.2f z=%.2f t=%.2f istrg0=%d xstrg0=%.2f ystrg0=%.2f\n", 
               i+1, pid[i], px[i], py[i], pz[i], mass[i], x[i], y[i], z[i], tt[i], istrg0[i], xstrg0[i], ystrg0[i]);
    }
    f->Close();
}
EOF
    root -l -b -q /tmp/check_parton_particles.C 2>/dev/null | grep "粒子"
else
    echo "parton-initial-afterPropagation.dat文件未生成"
fi

# ============ 4. HADRONS-BEFORE-ART.DAT 数据一致性测试 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. HADRONS-BEFORE-ART.DAT 数据一致性测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "ana/hadrons-before-ART.dat" ]; then
    # 事件头对比
    echo -e "\n4.1 事件头对比:"
    echo "dat文件事件头:"
    head -1 ana/hadrons-before-ART.dat | awk '{printf "eventID=%s miss=%s nParticles=%s impactParameter=%s nelp=%s ninp=%s nelt=%s ninthj=%s\n", $1, $2, $3, $4, $5, $6, $7, $8}'
    
    echo "ROOT文件事件头:"
    cat > /tmp/check_hadron_before_art_header.C << 'EOF'
void check_hadron_before_art_header() {
    TFile* f = TFile::Open("ana/hadron-before-art.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("hadron_before_art");
    if (!t) return;
    
    int eventID, miss, nParticles, nelp, ninp, nelt, ninthj;
    double impactParameter;
    
    t->SetBranchAddress("eventID", &eventID);
    t->SetBranchAddress("miss", &miss);
    t->SetBranchAddress("nParticles", &nParticles);
    t->SetBranchAddress("impactParameter", &impactParameter);
    t->SetBranchAddress("nelp", &nelp);
    t->SetBranchAddress("ninp", &ninp);
    t->SetBranchAddress("nelt", &nelt);
    t->SetBranchAddress("ninthj", &ninthj);
    
    t->GetEntry(0);
    printf("eventID=%d miss=%d nParticles=%d impactParameter=%.4f nelp=%d ninp=%d nelt=%d ninthj=%d\n",
           eventID, miss, nParticles, impactParameter, nelp, ninp, nelt, ninthj);
    f->Close();
}
EOF
    root -l -b -q /tmp/check_hadron_before_art_header.C 2>/dev/null | grep "eventID"
    
    # 前3个粒子对比
    echo -e "\n4.2 前3个粒子数据对比:"
    echo "dat文件数据:"
    awk 'NR>1 && NR<=4 {printf "粒子%d: pid=%s px=%s py=%s pz=%s mass=%s x=%s y=%s z=%s t=%s\n", NR-1, $1, $2, $3, $4, $5, $6, $7, $8, $9}' ana/hadrons-before-ART.dat
    
    echo "ROOT文件数据:"
    cat > /tmp/check_hadron_before_art_particles.C << 'EOF'
void check_hadron_before_art_particles() {
    TFile* f = TFile::Open("ana/hadron-before-art.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("hadron_before_art");
    if (!t) return;
    
    int nPart;
    double px[10000], py[10000], pz[10000], mass[10000];
    double x[10000], y[10000], z[10000], tt[10000];
    int pid[10000];
    
    t->SetBranchAddress("nParticles", &nPart);
    t->SetBranchAddress("pid", pid);
    t->SetBranchAddress("px", px);
    t->SetBranchAddress("py", py);
    t->SetBranchAddress("pz", pz);
    t->SetBranchAddress("mass", mass);
    t->SetBranchAddress("x", x);
    t->SetBranchAddress("y", y);
    t->SetBranchAddress("z", z);
    t->SetBranchAddress("t", tt);
    
    t->GetEntry(0);
    
    for(int i=0; i<3 && i<nPart; i++) {
        printf("粒子%d: pid=%d px=%.3f py=%.3f pz=%.4f mass=%.4f x=%.5f y=%.5f z=%.6f t=%.1f\n", 
               i+1, pid[i], px[i], py[i], pz[i], mass[i], x[i], y[i], z[i], tt[i]);
    }
    f->Close();
}
EOF
    root -l -b -q /tmp/check_hadron_before_art_particles.C 2>/dev/null | grep "粒子"
else
    echo "hadrons-before-ART.dat文件未生成（可能因为isoft设置）"
fi

# ============ 5. HADRONS-BEFORE-MELTING.DAT 数据一致性测试 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. HADRONS-BEFORE-MELTING.DAT 数据一致性测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "ana/hadrons-before-melting.dat" ]; then
    # 事件头对比
    echo -e "\n5.1 事件头对比:"
    echo "dat文件事件头:"
    head -1 ana/hadrons-before-melting.dat | awk '{printf "eventID=%s miss=%s nParticles=%s impactParameter=%s nelp=%s ninp=%s nelt=%s ninthj=%s\n", $1, $2, $3, $4, $5, $6, $7, $8}'
    
    echo "ROOT文件事件头:"
    cat > /tmp/check_hadron_before_melting_header.C << 'EOF'
void check_hadron_before_melting_header() {
    TFile* f = TFile::Open("ana/hadron-before-melting.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("hadron_before_melting");
    if (!t) return;
    
    int eventID, miss, nParticles, nelp, ninp, nelt, ninthj;
    double impactParameter;
    
    t->SetBranchAddress("eventID", &eventID);
    t->SetBranchAddress("miss", &miss);
    t->SetBranchAddress("nParticles", &nParticles);
    t->SetBranchAddress("impactParameter", &impactParameter);
    t->SetBranchAddress("nelp", &nelp);
    t->SetBranchAddress("ninp", &ninp);
    t->SetBranchAddress("nelt", &nelt);
    t->SetBranchAddress("ninthj", &ninthj);
    
    t->GetEntry(0);
    printf("eventID=%d miss=%d nParticles=%d impactParameter=%.4f nelp=%d ninp=%d nelt=%d ninthj=%d\n",
           eventID, miss, nParticles, impactParameter, nelp, ninp, nelt, ninthj);
    f->Close();
}
EOF
    root -l -b -q /tmp/check_hadron_before_melting_header.C 2>/dev/null | grep "eventID"
    
    # 前3个粒子对比
    echo -e "\n5.2 前3个粒子数据对比:"
    echo "dat文件数据:"
    awk 'NR>1 && NR<=4 {printf "粒子%d: pid=%s px=%s py=%s pz=%s mass=%s x=%s y=%s z=%s t=%s\n", NR-1, $1, $2, $3, $4, $5, $6, $7, $8, $9}' ana/hadrons-before-melting.dat
    
    echo "ROOT文件数据:"
    cat > /tmp/check_hadron_before_melting_particles.C << 'EOF'
void check_hadron_before_melting_particles() {
    TFile* f = TFile::Open("ana/hadron-before-melting.root");
    if (!f || f->IsZombie()) return;
    TTree* t = (TTree*)f->Get("hadron_before_melting");
    if (!t) return;
    
    int nPart;
    double px[10000], py[10000], pz[10000], mass[10000];
    double x[10000], y[10000], z[10000], tt[10000];
    int pid[10000];
    
    t->SetBranchAddress("nParticles", &nPart);
    t->SetBranchAddress("pid", pid);
    t->SetBranchAddress("px", px);
    t->SetBranchAddress("py", py);
    t->SetBranchAddress("pz", pz);
    t->SetBranchAddress("mass", mass);
    t->SetBranchAddress("x", x);
    t->SetBranchAddress("y", y);
    t->SetBranchAddress("z", z);
    t->SetBranchAddress("t", tt);
    
    t->GetEntry(0);
    
    for(int i=0; i<3 && i<nPart; i++) {
        printf("粒子%d: pid=%d px=%.3f py=%.3f pz=%.4f mass=%.4f x=%.5f y=%.5f z=%.6f t=%.1f\n", 
               i+1, pid[i], px[i], py[i], pz[i], mass[i], x[i], y[i], z[i], tt[i]);
    }
    f->Close();
}
EOF
    root -l -b -q /tmp/check_hadron_before_melting_particles.C 2>/dev/null | grep "粒子"
else
    echo "hadrons-before-melting.dat文件未生成（可能因为isoft设置）"
fi

# ============ 6. 汇总统计 ============
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. 汇总统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n文件大小对比:"
echo "ampt.dat: $(ls -lh ana/ampt.dat 2>/dev/null | awk '{print $5}') / ampt.root: $(ls -lh ana/ampt.root 2>/dev/null | awk '{print $5}')"
echo "zpc.dat: $(ls -lh ana/zpc.dat 2>/dev/null | awk '{print $5}') / zpc.root: $(ls -lh ana/zpc.root 2>/dev/null | awk '{print $5}')"
echo "parton-initial-afterPropagation.dat: $(ls -lh ana/parton-initial-afterPropagation.dat 2>/dev/null | awk '{print $5}') / parton-initial.root: $(ls -lh ana/parton-initial.root 2>/dev/null | awk '{print $5}')"
echo "hadrons-before-ART.dat: $(ls -lh ana/hadrons-before-ART.dat 2>/dev/null | awk '{print $5}') / hadron-before-art.root: $(ls -lh ana/hadron-before-art.root 2>/dev/null | awk '{print $5}')"
echo "hadrons-before-melting.dat: $(ls -lh ana/hadrons-before-melting.dat 2>/dev/null | awk '{print $5}') / hadron-before-melting.root: $(ls -lh ana/hadron-before-melting.root 2>/dev/null | awk '{print $5}')"

echo -e "\n粒子数量对比:"
if [ -f "ana/ampt.dat" ]; then
    echo "ampt: dat文件=$(($(wc -l < ana/ampt.dat) - 1))粒子 / ROOT文件=$(root -l -b -q -e "TFile* f = TFile::Open(\"ana/ampt.root\"); TTree* t = (TTree*)f->Get(\"ampt\"); int n; t->SetBranchAddress(\"nParticles\", &n); t->GetEntry(0); printf(\"%d\", n); f->Close();" 2>/dev/null | tail -1)粒子"
fi
if [ -f "ana/zpc.dat" ]; then
    echo "zpc: dat文件=$(($(wc -l < ana/zpc.dat) - 1))粒子 / ROOT文件=$(root -l -b -q -e "TFile* f = TFile::Open(\"ana/zpc.root\"); TTree* t = (TTree*)f->Get(\"zpc\"); int n; t->SetBranchAddress(\"nParticles\", &n); t->GetEntry(0); printf(\"%d\", n); f->Close();" 2>/dev/null | tail -1)粒子"
fi
if [ -f "ana/parton-initial-afterPropagation.dat" ]; then
    echo "parton-initial: dat文件=$(($(wc -l < ana/parton-initial-afterPropagation.dat) - 1))粒子 / ROOT文件=$(root -l -b -q -e "TFile* f = TFile::Open(\"ana/parton-initial.root\"); TTree* t = (TTree*)f->Get(\"parton_initial\"); int n; t->SetBranchAddress(\"nParticles\", &n); t->GetEntry(0); printf(\"%d\", n); f->Close();" 2>/dev/null | tail -1)粒子"
fi
if [ -f "ana/hadrons-before-ART.dat" ]; then
    echo "hadron-before-art: dat文件=$(($(wc -l < ana/hadrons-before-ART.dat) - 1))粒子 / ROOT文件=$(root -l -b -q -e "TFile* f = TFile::Open(\"ana/hadron-before-art.root\"); TTree* t = (TTree*)f->Get(\"hadron_before_art\"); int n; t->SetBranchAddress(\"nParticles\", &n); t->GetEntry(0); printf(\"%d\", n); f->Close();" 2>/dev/null | tail -1)粒子"
fi
if [ -f "ana/hadrons-before-melting.dat" ]; then
    echo "hadron-before-melting: dat文件=$(($(wc -l < ana/hadrons-before-melting.dat) - 1))粒子 / ROOT文件=$(root -l -b -q -e "TFile* f = TFile::Open(\"ana/hadron-before-melting.root\"); TTree* t = (TTree*)f->Get(\"hadron_before_melting\"); int n; t->SetBranchAddress(\"nParticles\", &n); t->GetEntry(0); printf(\"%d\", n); f->Close();" 2>/dev/null | tail -1)粒子"
fi

# 清理临时文件
rm -f /tmp/check_*.C

echo -e "\n测试完成！"