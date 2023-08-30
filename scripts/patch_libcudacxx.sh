set -e -x

ARCH=$(uname -i)
echo "ARCH:  $ARCH"

if [ $ARCH = "aarch64" ]; then

  patch -i /tmp/libcudacxx_aarch64_cuda_11_4.diff /usr/local/cuda-11.4/targets/aarch64-linux/include/cuda/std/detail/libcxx/include/cmath

fi