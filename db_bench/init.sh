#! /bin/bash
echo ***把动态链接库make install-shared进行安装***
# 参数1：选择新旧版本
if [ $# -ne 1 ]; then
    echo "./init.sh [new/old]"
    exit 0
fi

if [ $1 = new ]; then
    cd ../../rocksdb-cf6a77/
    sudo make uninstall-shared
    sudo make install-shared
    cd ../test-rocksdb-data/db_bench/
elif [ $1 = old ]; then
    cd ../../rocksdb-953f8b/
    sudo make uninstall-shared
    sudo make install-shared
    cd ../test-rocksdb-data/db_bench/
else
    echo "unknown param $1"
    exit
fi
