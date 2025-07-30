# Makefile for AMPT with ROOT interface
# Usage: make -f Makefile.simple

# ROOT configuration
ROOTCONFIG = root-config
ROOTCFLAGS = $(shell $(ROOTCONFIG) --cflags)
ROOTLIBS = $(shell $(ROOTCONFIG) --libs)

# Compiler settings
CXX = g++
FC = gfortran
CXXFLAGS = -O2 -Wall -fPIC $(ROOTCFLAGS)
FCFLAGS = -O2 -fdefault-real-8 -fdefault-double-8

# Find gfortran library path
GFORTRAN_LIB = $(shell gfortran -print-file-name=libgfortran.dylib | xargs dirname)

# Source files
FSRC = main.f amptsub.f linana.f zpc.f art1f.f hijing1.383_ampt.f hipyset1.35.f czcoal.f
CXXSRC = root_interface.cpp analysis_core.cpp

# Object files
FOBJ = $(FSRC:.f=.o)
CXXOBJ = $(CXXSRC:.cpp=.o)

# Target executable
TARGET = ampt

# Default target
all: $(TARGET)

# Build target with ROOT support
$(TARGET): $(FOBJ) $(CXXOBJ)
	$(CXX) -o $@ $(FOBJ) $(CXXOBJ) $(ROOTLIBS) -L$(GFORTRAN_LIB) -lgfortran

# Fortran object files
%.o: %.f
	$(FC) $(FCFLAGS) -c $< -o $@

# C++ object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean
clean:
	rm -f *.o $(TARGET) *.tmp

# Clean all including ROOT files
clean-all: clean
	rm -f ana/*.root

.PHONY: all clean clean-all
