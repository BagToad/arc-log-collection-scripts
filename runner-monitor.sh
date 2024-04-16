#!/bin/bash

# Monitor runner pods and write runner logs. 

RUNNER_PODS_LOGS_DIR="runner-pod-logs"

if [ ! -d "${RUNNER_PODS_LOGS_DIR}" ]; then
    mkdir -p ${RUNNER_PODS_LOGS_DIR}
fi

# Default values of arguments
POLL_COUNT=12
DELAY=1
RUNNER_LOG_TIMEOUT=2

# Dependency check
DEPS=("kubectl" "jq" "helm")

for cmd in "${DEPS[@]}"; do
    if ! command -v ${cmd} &> /dev/null; then
        echo "${cmd} could not be found. ${cmd} is required."
        exit 1
    fi
done

function help() {
  echo -e "Monitor runner pods and dump out runner logs.\n"
  echo -e "Usage: $0 [option...]\n"
  echo -e "Options:\n"
  echo -e "   -p, --poll <count>                 Set the poll count. This is the number of times to poll ephemeralrunner pods."
  echo -e "                                       Example: -p 10\n"
  echo -e "   -d, --delay <seconds>              Set the delay between each ephemeralrunner poll in seconds."
  echo -e "                                       Example: -d 5\n"
  echo -e "   -r, --runner-log-timeout <seconds> Tail runner logs for this duration in seconds. After this duration, the script will stop monitoring the logs."
  echo -e "                                       Example: -r 60\n"
  echo -e "   -h, --help                         Display this help message and exit.\n"
  echo -e "Examples:\n"
  echo -e "   $0 -p 10 -d 5 -r 60                Run the script with an ephemeralrunner poll count of 10, delay of 5 seconds, and runner pod log tail timeout of 60 seconds.\n"
  echo -e "   $0 -p 0 -d 0 -r 0                  Disable polling for ephemeralrunner pods and do not tail runner pod logs.\n"
  exit 1
}

# Loop through arguments and process them
for arg in "$@"
do
    case $arg in
        -p|--poll)
        POLL_COUNT=$2
        shift # Remove --loop or -l from processing
        ;;
        -d|--delay)
        DELAY=$2
        shift # Remove --delay or -d from processing
        ;;
        -r|--runner-log-timeout)
        RUNNER_LOG_TIMEOUT=$2
        shift # Remove --runner-log-timeout or -r from processing
        ;;
        -h|--help)
        help
        shift
        ;;
        *)
        shift # Remove generic argument from processing
        ;;
    esac
done

while true; do
    runner_pods=$(kubectl get ephemeralrunners --all-namespaces -o jsonpath="{.items[*].metadata.name}")
    if [ -z "$runner_pods" ]; then
        echo "No runner pods found."
        sleep ${DELAY}
        continue
    fi

    for pod in $runner_pods; do
        #kubectl get ephemeralrunners --all-namespaces -o json
        sleep 1
        namespace=$(kubectl get ephemeralrunners --all-namespaces -o jsonpath="{.items[?(@.metadata.name == '${pod}')].metadata.namespace}")
        repository=$(kubectl get ephemeralrunners --all-namespaces -o jsonpath="{.items[?(@.metadata.name == '${pod}')].metadata.labels."actions.github.com/repository"}")
        echo -e "⚠️ ${pod} is a runner pod!\n" 2>&1
        echo "repo is ${repository}"
        pod_log="${RUNNER_PODS_LOGS_DIR}/${pod}_${namespace}.log"
        meta_dump="${RUNNER_PODS_LOGS_DIR}/${pod}_NS_${namespace}_meta.txt"
        meta_yaml_dump="${RUNNER_PODS_LOGS_DIR}/${pod}_NS_${namespace}_meta.yaml"
        if ! kubectl get pod $pod -n $namespace &> /dev/null; then
            # Pod is dead
            echo -e "runner pod "${pod}" is dead.\n"
            continue
        fi
        if [ -s ${pod_log} ]; then
            echo -e "Log for ${pod} in ${namespace} already exists. Skipping...\n"
            continue
        fi
        echo -e "Writing log: \`${pod_log}\`...\n" 2>&1
        # Get more information from runner pods.
        echo -e "Runner pod labels:" 2>&1
        kubectl get pod ${pod} -n ${namespace} -o jsonpath='{.metadata.labels}' 2>&1 | jq . 2>&1
        echo -e "Runner repo:" 2>&1
        kubectl get pod ${pod} -n ${namespace} -o jsonpath='{.metadata.labels.actions\.github\.com/repository}'
        echo -e "Dumping pod meta to ${meta_dump}..."
        kubectl describe pod ${pod} -n ${namespace} > ${meta_dump}
        echo -e "Dumping pod meta to ${meta_yaml_dump}..."
        kubectl get pod ${pod} -n ${namespace} -o yaml > ${meta_yaml_dump}
        echo -e "Tailing logs for ${pod} in ${namespace} until dead or timeout (${RUNNER_LOG_TIMEOUT}s)" 2>&1
        (kubectl logs $pod -n $namespace --tail=-1 -f 2>&1 > ${pod_log}) &
        LOG_PID=$!
        while true; do
            if ! kubectl get pod $pod -n $namespace &> /dev/null; then
            # Pod is dead
            if ps -p $LOG_PID -o comm= | grep -q "^kubectl logs$"; then
                kill $LOG_PID
            fi
            echo -e "runner pod "${pod}" is dead.\n"
            break
            fi
            if [ $RUNNER_LOG_TIMEOUT -le 0 ]; then
            # Timeout has been reached
            if ps -p $LOG_PID -o comm= | grep -q "^kubectl logs$"; then
                kill $LOG_PID
            fi
            echo -e "Monitoring runner pod log has timed out\n"
            break
            fi
            RUNNER_LOG_TIMEOUT=$((RUNNER_LOG_TIMEOUT-1))
            sleep 1
        done
    done
done