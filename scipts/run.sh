#! /bin/bash
date

echo "now loading ......"
go-ycsb load rocksdb -P ../workloads/myworkload -p rocksdb.dir=../ > ../log/workloada-load.log

date

echo "now running ......"
go-ycsb run rocksdb -P ../workloads/myworkload -p rocksdb.dir=../ > ../log/workloada-run.log

date