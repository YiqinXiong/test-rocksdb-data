#! /bin/bash
echo ***将对应版本db_bench复制到该目录进行测试***
# 参数1：选择新旧版本
if [ $# -ne 1 ]; then
    echo "./run.sh [new/old]"
    exit 0
fi

if [ $1 = new ]; then
    rm ./db_bench
    cp ../../rocksdb-cf6a77/db_bench ./db_bench
    ./benchmark.sh fillseq_enable_wal,updaterandom $1
elif [ $1 = old ]; then
    rm ./db_bench
    cp ../../rocksdb-953f8b/db_bench ./db_bench
    ./benchmark.sh fillseq_enable_wal,updaterandom $1
else
    echo "unknown param $1"
    exit
fi