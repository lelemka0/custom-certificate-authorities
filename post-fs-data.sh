#!/system/bin/sh

MODDIR=${0%/*}
MODULE_LOG_FLAG="${MODDIR}/.log"
MODULE_LOG_FILE="${MODDIR}/log"

export MODDIR

#TESTING
touch $MODDIR/loaded
__LOG_FILE="/dev/null"
[ -f "$MODULE_LOG_FLAG" ] && __LOG_FILE=$MODULE_LOG_FILE

echo `date` "Start" | tee -a $__LOG_FILE
/system/bin/sh $MODDIR/start.sh 2>&1 | tee -a $__LOG_FILE
