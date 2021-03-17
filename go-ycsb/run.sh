#!/bin/bash

TYPE=$1

# Directory to save data
DATA=../data
CMD=../../go-ycsb/bin/go-ycsb
# Direcotry to save logs
LOG=./ycsb_logs

RECORDCOUNT=3000000
OPERATIONCOUNT=10000000
THREADCOUNT=4
FIELDCOUNT=10
FIELDLENGTH=100
MAXSCANLENGTH=10

PROPS="-p recordcount=${RECORDCOUNT} \
    -p operationcount=${OPERATIONCOUNT} \
    -p threadcount=${THREADCOUNT} \
    -p fieldcount=${FIELDCOUNT} \
    -p fieldlength=${FIELDLENGTH} \
    -p maxscanlength=${MAXSCANLENGTH}"
PROPS+=" ${@:2}"
WORKLOADS=

mkdir -p ${DATA}
mkdir -p ${LOG} 

DBDATA=${DATA}

PROPS+=" -p rocksdb.dir=${DBDATA}"
WORKLOADS="-P property/rocksdb"


if [ ${TYPE} == 'load' ]; then 
    echo "clear data before load"
    PROPS+=" -p dropdata=true"
fi 

echo ${TYPE} ${WORKLOADS} ${PROPS}

if [ ${TYPE} == 'load' ]; then 
    $CMD load rocksdb ${WORKLOADS} -p workload=core ${PROPS} | tee ${LOG}/ycsb_load.log
elif [ ${TYPE} == 'run' ]; then
    for workload in a b c d e f 
    do 
        $CMD run rocksdb -P ./workloads/workload${workload} ${WORKLOADS} ${PROPS} | tee ${LOG}/ycsb_workload${workload}.log
    done
else
    echo "invalid type ${TYPE}"
    exit 1
fi 

