#!/bin/bash
#run ls command on a list of directories to trigger cvmfs fetch of files in those directories

# Fetch CMSSW
(
    rm -rf CMSSW_*
    source /opt/cms/entrypoint.sh
    printf "\033[1;36mFetching CMSSW\033[0m\n"
    scramv1 project CMSSW CMSSW_15_1_1
    cd CMSSW_15_1_1/src || exit 1
    cmsenv
    mkdir L1Trigger
    cp -r "$CMSSW_RELEASE_BASE/src/L1Trigger/Phase2L1GMT" .
    scram b -j 4
    rm -rf *
    cd ../.. || exit 1
)

# Fetch LCG software
(
    printf "\033[1;36mListing /cvmfs/sft.cern.ch/lcg/${LCG_VERSION}/${LCG_ARCH}/setup.sh \033[0m\n"
    ls -l "/cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/setup.sh"

    printf "\033[1;36mSourcing /cvmfs/sft.cern.ch/lcg/${LCG_VERSION}/${LCG_ARCH}/setup.sh \033[0m\n"
    source "/cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/setup.sh"

    # Define list of directories (space-separated)
    DIRS="
/cvmfs/sft.cern.ch/lcg/views/LCG_${LCG_VERSION}/${LCG_ARCH}/share/jupyter/kernels/
/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw
$ROOTSYS
$ROOTSYS/lib
$ROOTSYS/include
"

    # Loop over directories
    printf "\033[1;36mListing contents of: \033[0m\n"
    for dir in $DIRS; do
            [ -z "$dir" ] && continue
            printf "%s" "$dir"
            ls -l --color "$dir" > /dev/null 2>&1 || printf "\033[1;31mDirectory not found or inaccessible: %s\033[0m\n" "$dir"
            echo ""
    done

    printf "\033[1;36mLoading PyROOT\033[0m\n"
    python3 -c "import ROOT; print('ROOT version:', ROOT.gROOT.GetVersion())"

    printf "\033[1;36mLoading matplotlib\033[0m\n"
    python3 -c "import matplotlib; print('matplotlib version:', matplotlib.__version__)"

    printf "\033[1;36mLoading numpy\033[0m\n"
    python3 -c "import numpy; print('numpy version:', numpy.__version__)"
)