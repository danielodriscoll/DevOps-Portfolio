Phase 1:

Phase 2:
I found that i can use cache 'pip' on fresh vm, so the the next time the pipline is called, it's much quicker and efficent in loading previous requirements.txt

Learned how to set rules, stopped branches from merging to main on GitHub unless they pass the worflow checks -> LINT, TEST, BUILD
Also useful to avoid deleting my work and force pushing to main

I notoced the vulnerability scan of an image comes after it's pushed to a registery? I think it would make more sense to ensure an image is safe before pushing, hence I chnaged the workflow to: LINT TEST DOCKER, where Docker job will build, scan and then push image to registery, push only happens on main branch

I noticed I'm pushing a lot of commits where there's an issue that I could of checked locally e.g. checking ruff command that it works locally before seeing it brak on the worfklow, saves much more time, in future test run: commands locally first ruff

Trivy vulnerability check is good practice to see what need to be addressed in my image if anything, learned it's very important for .dockerignore file to avoid pushing an image with useless and sensitive data

I changed th epipleine to avoid rebuilding docker image unecessarily as it only ocntains myapp content, skipp docker stpes if myapp folder is unchanged. More eefiecent piplein ethat way. I can update other parts of the project without executing the full pipeline.

Note: technically building the image twice, once before the scan then once after -> need to make more efficent

Phase 3:
"Kind" acts like a kubernetes cluster, whether a server or VM etc, Learned that kubectl connects to the cluster (it's where I write most commands)

If updating image version that's on the cluster, I can apply deployment.yaml with new path to new image version on ghcr.io to kubectl (cluster brain) or i can do it on the command line as a set image argument, this causes rollout across pods where pods scale up +1 to 4 pods, then remove one old pod, ensures always 3 pods availble for failover

Can check pod logs which helps with tracking and debugging issues

Note, you can set revision number/tag to a rollout so that if there's issuse you can revert back to previous versions

Learned Ingress is not longer in development or being updated , so i decided to build kubernetes gateway instead

## Security Note
In production, secrets would be managed via HashiCorp Vault or AWS Secrets Manager, not stored in yaml files.

I went with Gateway API over Ingress because it separates infrastructure ownership from application routing using proper typed fields instead of vendor-specific annotations, and because the community ingress-nginx controller hit end of life in March 2026

I have realised I made the raw kubernetes files which have hardcoded values. Helm is a layer above these and manages value changes, so rather than me change values in each raw file, I can Put teh raw file sint Helm templates and update them with a value field , then have one single values file that will update each raw file with placeholders. Much more efficent.

Removed the raw files altogether to avoid confusion. I find the placeholder values hard to read on the teampltes for Helm, however the reusability and speed when it comes to updating files , makes it a better decision for this project. I learned that fo rthe screts later on e.g. teh AWS secres or passwords I can just use Helm secret variable, which I'll try and pull from AWS or Hashicorp vault for safety. Helm will also allow me to rollback easily and configure files.

Ran into this error:
Error: INSTALLATION FAILED: Unable to continue with install: Service "fastapi-app" in namespace "default" exists and cannot be imported into the current release: invalid ownership metadata; label validation error: missing key "app.kubernetes.io/managed-by": must be set to "Helm"; annotation validation error: missing key "meta.helm.sh/release-name": must be set to "fastapi-app"; annotation validation error: missing key "meta.helm.sh/release-namespace": must be set to "default"

Helm refused to install because Service fastapi-app already existed from earlier raw kubectl apply and lacked Helm's ownership labels — fixed by kubectl delete -f k8s/raw/ before running helm install, letting Helm create everything fresh with proper ownership metadata." . The way I understand it it objects created using yaml file sin kubernetes cluster an dalready existed, so when i went to recreate them using Helm, I got error.

Came accross an issue with RedHat's Yaml support extension on VScode. It doesn't recognise some of the syntax that Helm uses on a YAML file. It highlighted red syntax error when there actually was no error, e.g the dash on name: {{ .Values.appName }}-deployment . Fixed it by just makig it a textfile named as .yaml file (don't select yaml as language on vscode or extension kicks in)

So now with the autoscaler or HPA.yaml in place, kubernetes needs a way to track currnet pods and cpu information to know wheteher to upgrade or downgrade pods around our average of 70% CPU, so we need an add on called metrics-server which will ask kubelet in each pod how much cpu and memory is being used.

Metrics-server doesnt recognise the any pod in my current cluster as it requires TLS certificate that is signed, kubelets certificates are self signed which it doenst recognise. this is a safety feature of metricsserver. To diagnose the issue I  kubectl describe pods -n kube-system -l k8s-app=metrics-server to get a log of teh error, its a server 500 error when the readinees action (helath check of othe rpods) fails, so just because wer eon kind and ar enot as srict with security we can pass an arugment to tell metricserver to ignor eth eneed for certifictaes: -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

Note: when HPA is active it overwrites whatever replicaset number I set in deployment file or values, so i had it set to 3 and hpa scaled it down to th emin i set of 2

so now using kubectl get hpa, it sshowing my cpu usage from teh taret i set of 70% very useful, maybe I can use it fo rmetrics endpoint later on and dsiaply on dahsboards? 

Used 'hey' to simulate 10 concurrent users hammering the FastAPI app through the Gateway for 60 seconds, generating enough CPU load to push the HorizontalPodAutoscaler past its 70% target, confirming it automatically scaled from 2 to 4 replicas under load, then scaled back down after a cooldown period (approx 5 minutes) once traffic stopped. Note: used forward port argument to point laptop port at Gateway port to run hey command and do the load test.

Apparently it's better practice to have two checks - pull to main and then merge which creates push to main should be triggered. In bigger team settings they could both pass whilst affecting eachothe rduring merge so good to check twice.

So writing the CI jobs for Helm linter and Kubeconform (kubernetes syntax) I ran into a small issue. Helm syntax is not registered as offcial Kubernetes syntax so we use helm template to resolve all the values placeholders {{ }}. We ouput this to a file and run that by kubeconform.

when installing kubeconfrom there is actions/ based repos that we can download from the community but its not very well trusted and offical, so safer to downlaod the binary and adjust it myself with shell script, unlike azure/setup-helm which is an offcial microsft action.

