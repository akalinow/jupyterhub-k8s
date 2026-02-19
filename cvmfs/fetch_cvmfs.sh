#!/bin/sh
#run ls command on a list of directories to trigger cvmfs fetch of files in those directories

# Define list of directories (POSIX compatible - space-separated)
DIRS="
/cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/setup.sh
/cvmfs/sft.cern.ch/lcg/views/${LCG_VERSION}/${LCG_ARCH}/share/jupyter/kernels/
/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw
"

# Loop over directories
for dir in $DIRS; do
    [ -z "$dir" ] && continue  # Skip empty lines
    echo "Listing contents of $dir to trigger cvmfs fetch..."
    ls -l --color "$dir" 2>/dev/null || echo "Directory not found or inaccessible: $dir"
    echo ""
done


