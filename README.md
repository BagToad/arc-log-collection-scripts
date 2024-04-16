# ARC Log Collection Scripts

ARC Log Collection Scripts is a collection of Shell scripts to dump diagnostic information and logs from your [Actions Runner Controller](https://github.com/actions/actions-runner-controller) deployment. 

- [`bundle.sh`](bundle.sh) collects logs from the ARC components and runner pods.
- [`runner-monitor.sh`](runner-monitor.sh) monitors and collects logs from the runner pods until the monitor script is killed.

## Anatomy of the ARC Log Bundle

A key output of the ARC log bundle is the `bundle.md` file, which contains a summary of the ARC deployment, metrics, and logs from _ALL_ pods.

The ARC Log Bundle consists of the following components:

- 📂 arc-bundle-logs
    - 📂 helm_info
        - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`_all.yaml
        - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`_values.yaml
    - 📂 pod_logs
        - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`.log
        - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`\_meta.txt
        - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`\_meta.yaml
    - 📂 bundle.md

## Anatomy of the Runner Monitor Log Directory

The Runner Monitor Log Directory consists of the following components:

- 📂 runner-pod-logs
    - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`\_runner.log
    - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`\_runner_meta.txt
    - 📂 `[PODNAME]`\_NS\_`[NAMESPACE]`\_runner_meta.yaml

## Privacy

The ARC bundle logs collect logs from _ALL_ pods in your ARC deployment because [GitHub recommends deploying ARC in a dedicated cluster](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/deploying-runner-scale-sets-with-actions-runner-controller#deploying-a-runner-scale-set). 

If you have deployed ARC in a shared cluster, the logs may contain sensitive information from other workloads. It is your responsiblity to review the logs before sharing them with others, including GitHub. 

Efforts are made to sanitize sensitive information from the logs, such as removing `github_token` and `github_app_private_key` from the Helm configuration output. 

It is your responsibility to review the logs before sharing them with others, including GitHub. Redact any sensitive information. If manual redaction is not reasonable, delete pod logs containing sensitive information. 

## Getting Started

### Prerequisites

A BASH shell with the `kubectl`, `helm`, `jq`, and other standard Linux utilities installed.

### Usage

1. Clone the repository:

```shell
git clone https://github.com/BagToad/arc-log-collection-scripts.git
```

2. Navigate to the directory where you've cloned the repository:

```shell
cd arc-log-collection-scripts
```

Run the desired scripts:

```shell
# Generate an ARC log bundle snapshot.
./bundle.sh

# Generate logs for runner pods only. 
./runner_monitor.sh
# CTRL+C when finished monitoring.
```

## Examples

```shell
./bundle.sh -p 0 -d 0 -r 0         #Disable polling for ephemeralrunner pods and do not tail runner pod logs.
./bundle.sh -p 10 -d 5 -r 60       #Run the script with an ephemeralrunner poll count of 10, delay of 5 seconds, and runner pod log tail timeout of 60 seconds
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing and Support

Pull requests are welcome. For major changes, please open an issue first to discuss your change.