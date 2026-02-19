#!/bin/sh
#run ls command on a list of directories to trigger cvmfs fetch of files in those directories

ls -l /cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/setup.sh
source /cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/setup.sh

# Define list of directories (POSIX compatible - space-separated)
DIRS="
/cvmfs/sft.cern.ch/lcg/views/*${LCG_VERSION}/${LCG_ARCH}/share/jupyter/kernels/
/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw
$ROOTSYS
"

# Loop over directories
printf "\033[1;36mListing contents of: \033[0m\n"
for dir in $DIRS; do
    [ -z "$dir" ] && continue  # Skip empty lines
    printf $dir
    ls -l --color "$dir" > /dev/null 2>&1 || printf "\033[1;31mDirectory not found or inaccessible: $dir\033[0m\n"
    echo ""
done

printf "\033[1;36mLoading PyROOT\033[0m\n"
python3 -c "import ROOT; print('ROOT version:', ROOT.gROOT.GetVersion())"
