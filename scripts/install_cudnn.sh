set -e -x

L4T=$1
DEV=$2

apt-get update

if [ "$(uname -m)" = "x86_64" ]; then
    # Adding sources for discrete NVIDIA GPU
    apt install -y libcudnn8-dev=8.2.4.15-1+cuda11.4 
    if $DEV ; then
      apt install -y libcudnn8=8.2.4.15-1+cuda11.4
    fi
else
    # NVIDIA CUDA cuDNN
    apt-get install -y libcudnn8
    if $DEV ; then
      apt-get install -y libcudnn8-dev
    fi
fi

rm -rf /var/lib/apt/lists/* \
apt-get clean