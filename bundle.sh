#!/bin/bash

LOGS_DIR="arc-bundle-logs"
LOGS_FILE="$LOGS_DIR/bundle.md"
LOGS_TGZ="$(date +%Y-%m-%d-%H-%M)-${LOGS_DIR}.tgz"
POD_LOGS_DIR="${LOGS_DIR}/pod_logs"
RUNNER_PODS_LOGS_DIR="${POD_LOGS_DIR}/runner_pod_logs"
HELM_INFO_DIR="${LOGS_DIR}/helm-info"

if [ ! -e $LOGS_DIR ]; then
  mkdir $LOGS_DIR
fi

if [ ! -e $POD_LOGS_DIR ]; then
  mkdir $POD_LOGS_DIR
fi

if [ -e $LOGS_FILE ]; then
  rm $LOGS_FILE
fi

if [ ! -e $HELM_INFO_DIR ]; then
  mkdir $HELM_INFO_DIR
fi

# Default values of arguments
POLL_COUNT=12
DELAY=1
RUNNER_LOG_TIMEOUT=10

# Dependency check
DEPS=("kubectl" "jq" "helm")

for cmd in "${DEPS[@]}"; do
    if ! command -v ${cmd} &> /dev/null; then
        echo "${cmd} could not be found. ${cmd} is required."
        exit 1
    fi
done

function help() {
  echo -e "\nThis script is used to gather logs, configurations, and other diagnostic information from an ARC deployment."
  echo -e "A directory will be made to store logs: ${LOGS_DIR}"
  echo -e "A markdown file will be created in the logs directory: ${LOGS_FILE}"
  echo -e "A tarball will be created in the current directory: ${LOGS_TGZ}\n"
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

echo -e "\nThis is $0 $@\n" >> $LOGS_FILE

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

# kubectl top
echo -e "## kubectl top\n" 2>&1 | tee -a $LOGS_FILE
echo -e "### Nodes\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
kubectl top nodes 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
echo -e "\n#### Pods\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
kubectl top pods -A 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
echo | tee -a $LOGS_FILE

# helm ls
echo -e "## Listing all helm releases in all namespaces\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
helm ls --all-namespaces 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE

# kubectl get customresourcedefinition
echo -e "\n## Listing all CRDs\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
kubectl get customresourcedefinition 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE

# kubectl get pods --all-namespaces
echo -e "\n## Listing all pods in all namespaces\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
kubectl get pods --all-namespaces 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE

# kubectl get deployments --all-namespaces
echo -e "\n## Listing all deployments in all namespaces\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
kubectl get deployments --all-namespaces 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE

# helm ls --all-namespaces
# List helm releases for Runner Scale Sets and Runner Scale Set Controllers
echo -e "\n## Listing Helm Releases for Runner Scale Sets\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
helm ls --all-namespaces | awk 'NR==1 || /gha-runner-scale-set-[0-9]*\.[0-9]\.[0-9]*/' 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
echo -e "\n## Listing Helm releases for Runner Scale Set Controllers\n" 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE
helm ls --all-namespaces | awk 'NR==1 || /gha-runner-scale-set-controller-[0-9]*\.[0-9]\.[0-9]*/' 2>&1 | tee -a $LOGS_FILE
echo '```' >> $LOGS_FILE

# kubectl get ephemeralrunners --all-namespaces
echo -e "\n## Polling \`ephemeralrunner\` Pods (${DELAY}s x ${POLL_COUNT})\n" 2>&1 | tee -a $LOGS_FILE
if [ ${POLL_COUNT} -le 0 -o ${DELAY} -le 0 ]; then
    echo "Skipping polling of ephemeralrunner pods because POLL_COUNT or DELAY is set to 0." 2>&1 | tee -a $LOGS_FILE
else
  for i in $(seq 1 $POLL_COUNT); do
      echo -e "### Listing ephemeral runner pods ($i/$POLL_COUNT at $(date -u)):\n" 2>&1 | tee -a $LOGS_FILE
      echo '```' >> $LOGS_FILE
      kubectl get ephemeralrunners --all-namespaces 2>&1 2>&1 | tee -a $LOGS_FILE
      echo '```' >> $LOGS_FILE
      echo | tee -a $LOGS_FILE
      sleep $DELAY
  done
fi

echo -e "\n## Collecting Helm Release Information for Runner Scale Sets\n" 2>&1 | tee -a $LOGS_FILE
runner_releases=$(helm ls --all-namespaces | awk '/gha-runner-scale-set-[0-9]*\.[0-9]\.[0-9]*/')

echo "$runner_releases" | while IFS= read -r release; do
  runner_name=$(echo $release | awk '{print $1}')
  runner_namespace=$(echo $release | awk '{print $2}')
  values_file=${HELM_INFO_DIR}/${runner_name}_NS_${runner_namespace}_values.yaml
  all_file=${HELM_INFO_DIR}/${runner_name}_NS_${runner_namespace}_all.yaml
  echo -e "Writing \`${values_file}\`...\n" 2>&1 | tee -a $LOGS_FILE
  helm get values ${runner_name} -n ${runner_namespace} | sed -e 's/\(github_token:\).*/\1 REDACTED/' -e 's/\(github_app_private_key:\).*/\1 REDACTED/' > ${values_file}
  echo -e "Writing \`${all_file}\`...\n" 2>&1 | tee -a $LOGS_FILE
  helm get all ${runner_name} -n ${runner_namespace} | sed -e 's/\(github_token:\).*/\1 REDACTED/' -e 's/\(github_app_private_key:\).*/\1 REDACTED/' > ${all_file}
done

echo -e "\n## Collecting Helm Release Information for Runner Controllers\n" 2>&1 | tee -a $LOGS_FILE
controller_releases=$(helm ls --all-namespaces | awk '/gha-runner-scale-set-controller-[0-9]*\.[0-9]\.[0-9]*/')
echo "$controller_releases" | while IFS= read -r release; do
  controller_name=$(echo $release | awk '{print $1}')
  controller_namespace=$(echo $release | awk '{print $2}')
  values_file=${HELM_INFO_DIR}/${controller_name}_NS-${controller_namespace}_values.yaml
  all_file=${HELM_INFO_DIR}/${controller_name}_NS-${controller_namespace}_all.yaml
  echo -e "Writing \`${values_file}\`...\n" 2>&1 | tee -a $LOGS_FILE
  helm get values ${controller_name} -n ${controller_namespace} | sed -e 's/\(github_token:\).*/\1 REDACTED/' -e 's/\(github_app_private_key:\).*/\1 REDACTED/' > ${values_file}
  echo -e "Writing \`${all_file}\`...\n" 2>&1 | tee -a $LOGS_FILE
  helm get all ${controller_name} -n ${controller_namespace} | sed -e 's/\(github_token:\).*/\1 REDACTED/' -e 's/\(github_app_private_key:\).*/\1 REDACTED/' > ${all_file}
done

echo -e "\n## Writing logs for pods" 2>&1 | tee -a $LOGS_FILE
echo -e "\n### Writing logs for runner pods" 2>&1 | tee -a $LOGS_FILE
# Get a list of all runner pods
runner_pods=$(kubectl get ephemeralrunners --all-namespaces -o jsonpath="{.items[*].metadata.name}")
for pod in $runner_pods; do
  echo -e "⚠️ ${pod} is a runner pod!\n" 2>&1 | tee -a $LOGS_FILE
  pod_log="${POD_LOGS_DIR}/${pod}_NS_${namespace}.log"
  meta_dump="${POD_LOGS_DIR}/${pod}_NS_${namespace}_meta.txt"
  meta_yaml_dump="${POD_LOGS_DIR}/${pod}_NS_${namespace}_meta.yaml"
  echo -e "Writing log: \`${pod_log}\`...\n" 2>&1 | tee -a $LOGS_FILE
  namespace=$(kubectl get ephemeralrunners --all-namespaces -o jsonpath="{.items[?(@.metadata.name == '${pod}')].metadata.namespace}")
  # Get more information from runner pods.

  echo -e "Runner pod labels:" 2>&1 | tee -a $LOGS_FILE
  echo '```' >> $LOGS_FILE
  kubectl get pod ${pod} -n ${namespace} -o jsonpath='{.metadata.labels}' 2>&1 | jq . 2>&1 | tee -a $LOGS_FILE
  echo '```' >> $LOGS_FILE
  echo -e "Dumping pod meta to ${meta_dump}..."
  kubectl describe pod ${pod} -n ${namespace} > ${meta_dump}
  echo -e "Dumping pod meta to ${meta_yaml_dump}..."
  kubectl get pod ${pod} -n ${namespace} -o yaml > ${meta_yaml_dump}
  echo -e "Tailing logs for ${pod} in ${namespace} until dead or timeout (${RUNNER_LOG_TIMEOUT}s)" 2>&1 | tee -a $LOGS_FILE
  (kubectl logs $pod -n $namespace --tail=-1 -f 2>&1 > ${pod_log}) &
  LOG_PID=$!

  while true; do
    if ! kubectl get pod $pod -n $namespace &> /dev/null; then
      # Pod is dead
      if ps -p $LOG_PID -o comm= | grep -q "^kubectl logs$"; then
        kill $LOG_PID
      fi
      echo -e "Pod is dead\n" | tee -a $LOGS_FILE
      break
    fi
    if [ $RUNNER_LOG_TIMEOUT -le 0 ]; then
      # Timeout has been reached
      if ps -p $LOG_PID -o comm= | grep -q "^kubectl logs$"; then
        kill $LOG_PID
      fi
      echo -e "Monitoring runner pod log has timed out\n" | tee -a $LOGS_FILE
      break
    fi
    RUNNER_LOG_TIMEOUT=$((RUNNER_LOG_TIMEOUT-1))
    sleep 1
  done
  # Move on to next pod. No need to check for errors in runner pods as those are job/workflow specific messages.
  continue
done

echo -e "\n### Writing logs for all pods in all namespaces\n" 2>&1 | tee -a $LOGS_FILE
# Get a list of all namespaces
namespaces=$(kubectl get ns -o jsonpath="{.items[*].metadata.name}")

for namespace in $namespaces; do
  # Get a list of all pods in the current namespace
  pods=$(kubectl get pods -n $namespace -o jsonpath="{.items[*].metadata.name}")
  for pod in $pods; do
    echo -e "### \`${pod}\` in namespace \`${namespace}\`\n" 2>&1 | tee -a $LOGS_FILE
    if ! kubectl get pod $pod -n $namespace &> /dev/null; then
      echo -e "⚠️ Pod \`${pod}\` in namespace \`${namespace}\` no longer exists, skipping..." 2>&1 | tee -a $LOGS_FILE
      continue
    fi
    pod_log="${POD_LOGS_DIR}/${pod}_${namespace}.log"
    meta_dump="${POD_LOGS_DIR}/${pod}_NS_${namespace}_meta.txt"
    meta_yaml_dump="${POD_LOGS_DIR}/${pod}_NS_${namespace}_meta.yaml"
    echo -e "Writing log: \`${pod_log}\`...\n" 2>&1 | tee -a $LOGS_FILE
    
    kubectl logs $pod -n $namespace 2>&1 > ${pod_log}
    # Check for errors in the pod log
    pod_errors=$(grep -i -n " error " ${pod_log})
    pod_error_count=$(echo "${pod_errors}" | wc -l)
    if [ -z "$pod_errors" ]; then
      echo -e  "No errors found in ${pod_log}\n" 2>&1 | tee -a $LOGS_FILE
      continue
    fi
    echo -e "${pod_error_count} ERRORs found in ${pod_log}\n" 2>&1 | tee -a $LOGS_FILE
    echo -e "last 10 ERROR lines found in ${pod_log}:\n" 2>&1 | tee -a $LOGS_FILE
    echo '```' >> $LOGS_FILE
    echo -e "${pod_errors}\n" | tail -10 2>&1 | tee -a $LOGS_FILE
    echo '```' >> $LOGS_FILE
    echo -e | tee -a $LOGS_FILE
  done
done

echo -e "\n### Compressing logs directory to $(date +%Y-%m-%d-%H-%M)-${LOGS_DIR}.tgz\n" 2>&1 | tee -a $LOGS_FILE
tar -czf $LOGS_TGZ ${LOGS_DIR}
