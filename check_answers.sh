#!/bin/bash

if [ -z "$1" ]; then
    echo "ERROR: no arguments given to $0"
    exit 1
fi

failed=false

mkdir -p results

for problem in $1/*; do
    printf "$problem "
    problem_id=$(basename ${problem%.sql})
    result="results/$problem_id.out"
    expected="expected/$problem_id.out"
    psql < $problem > $result
    DIFF=$(diff -B $expected $result)
    if [ -z "$DIFF" ]; then
        echo pass
    else
        echo fail
        failed=true
    fi
done

if [ "$failed" = "true" ]; then
    exit 2
fi

