## Phase 1:

## Phase 2:
I found that i can use cache 'pip' on fresh vm, so the the next time the pipline is called, it's much quicker and efficent in loading previous requirements.txt

Learned how to set rules, stopped branches from merging to main on GitHub unless they pass the worflow checks -> LINT, TEST, BUILD
Also useful to avoid deleting my work and force pushing to main

I notoced the vulnerability scan of an image comes after it's pushed to a registery? I think it would make more sense to ensure an image is safe before pushing, hence I chnaged the workflow to: LINT TEST DOCKER, where Docker job will build, scan and then push image to registery, push only happens on main branch

I noticed I'm pushing a lot of commits where there's an issue that I could of checked locally e.g. checking ruff command that it works locally before seeing it brak on the worfklow, saves much more time, in future test run: commands locally first ruff

Trivy vulnerability check is good practice to see what need to be addressed in my image if anything, learned it's very important for .dockerignore file to avoid pushing an image with useless and sensitive data

I changed th epipleine to avoid rebuilding docker image unecessarily as it only ocntains myapp content, skipp docker stpes if myapp folder is unchanged. More eefiecent piplein ethat way. I can update other parts of the project without executing the full pipeline.

Set Permissions at the start of docker build job as the default is read and write to the repo, I want to follow least privilege access, therefore set teh GITHUB token generated automaticlaly by the workflow to only be allowed read the repo and only allowed write to GHCR

Note: technically building the image twice, once before the scan then once after -> need to make more efficent

## Phase 3:
"Kind" acts like a kubernetes cluster, whether a server or VM etc, Learned that kubectl connects to the cluster (it's where I write most commands)

If updating image version that's on the cluster, I can apply deployment.yaml with new path to new image version on ghcr.io to kubectl (cluster brain) or i can do it on the command line as a set image argument, this causes rollout across pods where pods scale up +1 to 4 pods, then remove one old pod, ensures always 3 pods availble for failover

Can check pod logs which helps with tracking and debugging issues

Note, you can set revision number/tag to a rollout so that if there's issuse you can revert back to previous versions

Learned Ingress is not longer in development or being updated , so i decided to build kubernetes gateway instead

Security Note:
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

Ran kubeconform locally but had an error with HTTProute and Gateway Schemas. This happened because kubeconfrom is for core kubernetes types, to get around this we use -schema-location to point to a custome resource definition for API gateway and HTTProute on the community driven datreeio/CRDs-catalog. How do I ensure these comunity repos are safe and ensure security when auto downlaodingd CRDS?

Finsihed two workflows, tagged a new version fo rmy main repo and it failed  atrivy scan. I realised my requirements.txt contains devops tooling unrelated to the fastapi app being deployed and shipped to cloud. Like it doesnt not need ansible and pytest in it when being shipped. This is why my images were taking awhile to be built and scanned so spotted a security and bloating issue with trivy!

Discovered anothe rproblem, CI pipeline installs requirements.txt and needs ruff and lint from there to check code, but this conflictsa the idea of having runtime only requirmeents, so it' srecoomened to do two requirements , runtime one and devlopment&testing one. SO i Made two. One of tools and one of app only requirements.

Issue with trivy flagging high CVE's, after debugging it' snot to do with my app or its dependencies or even my requirements. It was the python:3.14-slim image used in th edocker file has underlying dependencies e.g. setuptools that are outdated. So trivy caught issues that I didn't really think were associated with me and my build. Fix is to update setuptools with RUN pip install --no-cache-dir --upgrade pip setuptools wheel in docker file. Why not just update everything to latest version? - could be riskyy and break code or unexpected beahvior.

Build tools (pip, setuptools, wheel) are needed to assemble an image but not to run the app. In a single-stage build they get shipped in the final image, adding vulnerabilities and bloat. A multi-stage build installs everything in a throwaway build stage, then copies only the finished app into a clean final stage, so build tooling (and its stale vendored files) never reaches production. This is the standard fix for 'build-tool CVEs in the runtime image.'

I've opted to rewrite my dockerfile into a multistage build file as its better practice as it doesnt add build tools to final image. Still failinh trivy scan on installing tools setupttols, msgpack unde rthe hood of python-slim althouh iv eupdated them to newest versions and have confirmed them its still using old versions or has them which trivy catches? Just removed them from the final image to avoid the error. need a better way of doing this in the furture.

## Phase 4
I learned that it's good practice to verify company software uisng keys. You download public key locally froM hashicorp, then when your downlaoading or installing software e.g. Terraform, you downlaod it ensureing the signature from matches our Hashicorp key using signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg]

Setting IAM user for terraform (terraform-user) rather than using root credentials, Best practice to not usee root AWS user when accessing services - least privileged access, i'LL START broad for now and tighten as I progress: AmazonEC2FullAccess, AmazonS3FullAccess, IAMReadOnlyAccess. Added IAM user acess key and secret key to AWS CLI locally in the default location (not th ebest practoce but safe fo rthis portfolio) In future it shoul dbe handle by secret manager or IAM Identity center manages SSO

Terraform Bootstrap: I created a small, separate Terraform config that runs once with local state, and its only job is to create the S3 bucket that will store my main infrastructure's remote state. I kept it separate because Terraform can't use a backend bucket to store its own state before that bucket exists. This separation also means the bucket never appears as a managed resource inside my main infrastructure's config, so my main state has no power to modify or destroy the bucket itself, even though it's constantly writing new state versions into it. That protects my state history from being wiped out by a routine change or a terraform destroy on my everyday infrastructure.

I pinned the AWS provider to ~> 5.0 so my setup stays reproducible and doesn't silently break on a major version bump, and set the region to eu-west-1 since it's closest to me. For the state bucket I turned on versioning so I can recover if the state ever gets corrupted, blocked all public access since state can contain sensitive values, and enabled AES256 encryption at rest

variables.tf works like Helm's values.yaml from Phase 3: it declares the configurable inputs the infrastructure needs (region, instance size, my IP), keeping them separate from main.tf, which defines the actual resources. This makes main.tf reusable, the same structure can deploy differently just by supplying different variable values, rather than editing the resource definitions. Sensitive/personal values (like my IP) are declared here but their actual values live in a gitignored terraform.tfvars, so they never get committed.

When writing main.tf, I caught that ssh to the EC2 would be tied to my IP which is fine but I was about to expose the serever to th epublic via http. Technically it's safe becasue theres nothing running on there or exposed , but I thought best to test and ensure everything works before I open it to the public. so I locked it http calls to my IP only (also must ensure I use port 443 for HTTPS) Example of AI making a security mistake.

I don't need to do the same for outound traffic as my server will need to fetch updates, or donwload image setc. However in a production environment you would have tight sceurity incase the server was compromised and we wante dto stop the attacker sending out data.

 Set a $1 budget alert, Free Tier usage alerts and destroyed resources after each session to esnure cost efficency (120 in credits). Wrote main.tf to provision three resources: an SSH key pair (uploading my public key so I can log in), a security group (firewall) locking SSH and HTTP to my own IP for private testing while leaving outbound open so the server can fetch updates and images, and a t3.micro EC2 instance. Hit and fixed a real-world issue, my home broadband IP changes dynamically, so SSH failed until I updated terraform.tfvars and re-applied, which demonstrated Terraform's value: one line changed, one firewall rule updated in place, no resources recreated. Successfully SSH'd into the live server (learning that a cloud instance has both a public IP for internet access and a private IP for AWS-internal networking, and that the first-connection fingerprint prompt is SSH's trust-on-first-use identity check).

Added Terraform validation and security scanning to CI as two separate jobs in ci.yml: terraform-validate runs fmt -check and validate (using init -backend=false so it needs no AWS credentials), and terraform-security runs tfsec to catch misconfigurations like open security groups or unencrypted storage, the IaC equivalent of Trivy scanning Docker images

After pushing new commit, the terraform jobs failed. Firstly due to incorrect foramtting, my public ssh key that get attached to the ec2 is obtained with file() from my local machine, but the ci piplien uses a new ubuntu VM which cant see outside the project folder. Solution woul dbe to add the ssh key as a variable into hidden terraform.tfvars and declare it in my variables.tf and call it in the main.tf. 

TFsec caught 4 security issues with my terraform folder.

Result #1 CRITICAL Security group rule allows egress to multiple public internet addresses. -> Impact Your port is egressing data to the internet
  Resolution Set a more restrictive cidr range

Result #2 HIGH Instance does not require IMDS access to require a token -> Impact Instance metadata service can be interacted with freely
  Resolution Enable HTTP token requirement for IMDS

Result #3 HIGH Root block device is not encrypted. -> Impact The block device could be compromised and read from
  Resolution Turn on encryption for all block devices

Result #4 LOW Security group rule does not have a description. -> Impact Descriptions provide context for the firewall rule reasons
  Resolution Add descriptions for all security groups rules

My CI pipeline caught 3 high vulnerable issues with the terraform setup.

To address 2 and 3 I used
  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    encrypted = true
  }

IMDSv2: blocks SSRF attacks from stealing IAM credentials via the instance metadata service

EBS encryption: encrypts the disk at rest so data isn't readable from physical drives or leaked snapshots, and satisfies compliance requirements like GDPR/HIPAA for free with one setting.

1 is actually safe as I've set it up to my local ip only can access, so it's a false positive. Just added # tfsec:ignore:aws-ec2-no-public-egress-sgr comment above egress{} which will ignore the vulnerability, get id aws-ec2-no-public-egress-sgr  from CI pipleine logs

Note: issue, uploaded new tag which triggers image to be built which contains docker

## Phase 5
So Terraform handles deploying the infrastructure. Whereas Ansible what is is insatlled and configured on a deployed machine e.g. package files, running services etc.

We could do configuration using a shell script on boot with Terraform, the issue is it's not idempotent and will cause issues if changes are made ( will have to start up a new instance and sh script.) Whereas Ansible will check current config and only change what needs to be changed.

With configuring secrets and passwords between ansible, my image repo etc I opted to go with AWS secret manager as it's as easy as adding another resource to Terraform during provisioning. Also it's kept on the cloud which is safer and more accessible for teams as opposed to locally. Downside, it costs 40cent a month per secret.

I noticed my old ghcr token expired which is good, so I made a new one for the aws-ec2 to pull my image, set th etoken to packages:read only so I follow least privilege access. To tighten my security in this ci/cd flow I changes my devops-portfolio package to privat erathe rthan public, forcing the authentication requirement that were going to apply through aws secrets.

I made an IAM user terraform-user so I could use Terraform from the AWS CLI locally, each time I ran Terraform commands they interacted with AWS's API, authenticated with that user's credentials (set up locally via aws configure). That's the *human/tool* identity for building infrastructure from my laptop.

Now for the deployment side, the EC2 itself needs to call AWS APIs at runtime (to fetch the ghcr token from Secrets Manager), without a human involved, and without credentials sitting on the server. That's a *machine* identity, which is what an IAM role attached to the EC2 provides: temporary credentials delivered via the instance metadata service, scoped tightly to just reading one specific secret. Ansible is the tool triggering the fetch, but the identity making the AWS call is the EC2 itself.

Two identities at two different times: terraform-user (my laptop, creating infrastructure) and ec2_role (the running server, accessing runtime resources), this is another example of least privilege.

From my understanding AWS IAM User is for long term credentials and logins by users and apps, roles are short term permissions with specific access (usually aws services), policies are the restrictions on what users/roles can access in JSON format.

Note when adding a role to EC2 it require a wrapper, in this case we have an IAM instance that gets attached to ec2 as an object. Attaching instance require delete and recreate of EC2 (be careful in future, its ok fo rmy project because I destroy anyway)

Ran into permission error, the user policies attached to my local laptop under terraform-user do not have necessary permissions: 
terraform-user is not authorized to perform: iam:CreateRole on resource:
/terraform-user is not authorized to perform: secretsmanager:CreateSecret
This is a good example of least privilege access working corrcetly, stopped my terraform-user from perfoming these actions, must update it's policies.

uploaded my ghcr token from aws cli once (only tim eit was in plain view ) to aws secret manager, where EC2 can read it.

Big error I made, git add and commit from within my ansible folder only pushed changes in that folder, not th entire devops-portfolio, so terraform and decision changes didnt upload. add . is currnet repo, git -A is entire repo. I used git restore which removed my progress. I got my work back using vscode command palatte - local history find entity and restore.

TFsec flagged a low security issue of me using the deafult aws-managed KMS key for secrets manager. To us emy own key it costs money which would go against the free tier I'm on. In production I owuld update this key and it's policies. But for this free tier portfolio, i'll use the default, risk is low because it's encrypted at rest anyway.

Running ansible-inventory --list was failing due to a default secuirty feature where this command will only allow and read an ansible directory that is not writable to everyone which mine was not so it failed. Fixed it with Chmod 755 on that directory, allowing only the owner full permissions and not the groups or others. This avoids malicios edits to .cfg file that Ansible could run. Good practice also on Linux to follow least privilege access rule so that if an attacker get access to a service the blast radius of what they can do is minimised.

My ISP keeps changing my ip throughout development, most be a secuirty feature, so it keeps breaking the ip in TFvars file.

This phase seems to be a real test to see if I like solving issue around connecting these tools. This ANsible phase has proven tricky so far. Ansible playbook failed on trying to install requests module as rpm from the linux image being used already contained it. It then broke authenticating to GHCR due to an expired token. This was the security detup of 30 days for a token that I setup in earlier phases working correctly. 

Ansible lookup plugins run on the controller (my laptop), not the host (the EC2). So the aws secret fetch uses my laptop's terraform-user credentials, not the EC2's IAM role (ec2-user). If I wanted the fetch to run on the EC2 using its role, I'd use the module form (a task) instead of a lookup. For this project the lookup is fine because my laptop has AWS credentials anyway but I note that if this were CI-driven deployment with no local AWS creds, the module form running on the EC2 (with its role) would be the right pattern

Made a silly mmistake, adjusted the Dockerfile to be multistage build to fix the setuptools error, howeveer I forgot to buil dthe images an dtets th econtaienr myself, turns out theres an issues that I spotted now when pulling that image with Ansible and trying to run it. The issue is the fastapi executable in the bin folder is not getting copied across to the second datge of the build so error running the script using:

CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]

So fastapi is the middleman which uses uvicorn under the hood, uvicorn is also in bin folder but also site-packages folder which does get copied across so will work

## Phase 6

So I'll expand phase 3 the kubernetes cluster to accommadate prometheus and Loki metrics & logs and dispaly them using Grafana. It's  abit more costly to do this with phase 5 THE ec2 running the image, so I might just use the AWS native CloudWatch for observability.

App already has /metrics endpoint which we need prometheus to scrape data from in order to monitor.

Installed the kube-prometheus-stack Helm chart using Helm commands into a dedicated namespace called "monitoring" this chart comes bundled with Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, and the Prometheus Operator in one

Added a ServiceMonitor custom resource to the Helm chart (in the templates folder), this is a Kubernetes-native way to register targets/endpoints to scrape with Prometheus.

The reason fo doing this over configuring premtheus.yml file directly is the operator (Service Monitor) watches for CRDs and reconfigures Prometheus automatically. This is a modern approach for Prometheus in Kubernetes.

Grafana comes with pre-built dashboards for Kubernetes internals (nodes, pods, cluster) but nothing for my app until Prometheus starts scraping via the ServiceMonitor.

So I readjusted my /metrics endpoint in my app/ , the fastapi-instrumentor package can use the Instrumentor Class to implement a middleware that allows prometheueus to automatically create a /metrics endpoint in order to track app metrics.

When rebuilding the image, came across error: ERROR: failed to build: failed to solve: error getting credentials - err: exit status 1, my docker config file picked up broken Windows helper reference since docker runs on windows. to fix it on WSL echo '{}' > ~/.docker/config.json TO EMPTY THE CONFIG.

New pods wouldn't rollout new v0.6.0 tag because the ghcr.io image repo was set to private during Phase 5 and the kind cluster has no pull secret Old pods stayed up safely because Kubernetes refuses to kill working pods until new ones are healthy, in order to complete rollout i must give GHCR permissions to my cluster

Diagnosed with kubectl describe pod -l app=fastapi-app → "unauthorized" error on image pull.

Same ghcr token already stored in AWS Secrets Manager for the EC2 deployment path, I'll create a seprate one from my Kind cluste rpath to seprate concerns and reduce risk if one ever got exposed.

Noticed something interesting when fixing rollout, after applying new token, 3 pods were rolled out when hpa is set to min 2 , max 4. I thought why 3 pods? get hpa -w said unknown/70% cpu which is the target I set, further investigations with kubectl get pods -n kube-system | grep metrics-server showed metrics-server pod was down?

I have metrics server pod down with CrashLoopBackOff meaning kubernetes keeps restarting it but it crashes? 

Diagnosing the problem more with kubetcl get deployment metrics-server -n kube-system

we get: READY 0/1 which means Deployment wants 1 pod healthy, has 0
AVAILABLE 0 means no healthy pod available
UP-TO-DATE 1 means Kubernetes has created the current version which tells me whatever we did create isn't working

describing th epod itself with:  kubectl describe pod -n kube-system -l k8s-app=metrics-server

I got information in the log sthat the conatiner was pulled sucessfully and running, but metrics-server responded with an error when kubelet asked are you ready: Readiness probe failed: HTTP probe failed with statuscode: 500

Continues to see if it's alive but dies: Liveness probe failed: Get "https://10.244.0.10:10250/livez": context deadline exceeded

To get root cause of why metrics-server was failling and retuning 500, I tried fetching the logs the conatiner with: kubectl logs -n kube-system -l k8s-app=metrics-server --previous --tail=100, but it returned nothing.

using kubectl get pods -n kube-system | grep metrics-server, I can see the pod crashed 25 seconds ago which tells me its still restarting over and over with error each time, so when i chekc the logs , a new pod is constantly being made or restarted with new id.

Trying to dig deeper into th eissue i foun dthis to b ete hmost readbale for reading console logs: docker exec devops-portfolio-cluster-control-plane journalctl -u kubelet --no-pager --since "10 minutes ago" | less -S

Here I found metrics-server, nginx-gateway , scheduler etc all thes epods were failing? 

I realised that the default kube-prometheus-stack is built for real multi-node clusters, not a laptop, so out of the box it scraped ~15 targets, evaluated hundreds of recording/alert rules constantly, and pulled heavy kubelet metrics I didn't need, which pegged all 8 CPUs (823%/800% in Docker) and froze the machine. I diagnosed it as resource exhaustion rather than a config bug from the kubelet logs (iptables ChainExists taking 3.7s, housekeeping took too long) and the fact that many unrelated components were failing at once, not just one. The fix came in two parts: first, capping WSL in .wslconfig with memory=3GB, swap=4GB, processors=4, and autoMemoryReclaim=gradual so it can never take more than half my cores or balloon memory and starve Windows; and dealing with wsl --shutdown silently failing because Docker Desktop's background service kept restarting WSL (its engine runs inside WSL), fixed by disabling Docker's start-on-login and fully quitting it before shutdown. Second, rather than patch a cluster that had been crash-looping for 53 days, I deleted it and rebuilt fresh with only what Phase 6 needs: Gateway API CRDs, metrics-server, the ghcr pull secret, my app, and a trimmed monitoring stack with Alertmanager, node-exporter, kube-state-metrics, all control-plane scrapers, and defaultRules disabled, plus hard CPU/memory limits on every remaining component. That dropped node CPU from 823% to ~52% while leaving the app's ServiceMonitor scraping untouched, with the remaining cost being mostly the unavoidable Kubernetes control plane itself. The lesson: observability stacks are far heavier than they look, and on constrained hardware the right move is running only what's strictly needed and capping the VM so one workload can't starve the host.

Built a Grafana dashboard with four panels, each chosen because it maps to one of the "four golden signals" style questions you actually ask about a running service: requests/sec (sum(rate(http_requests_total[1m]))) for traffic, p95 latency (histogram_quantile(0.95, ...) over the duration histogram buckets) for how slow the slowest realistic requests are, error rate (5xx responses over total) for whether it's failing, and running pod count (sum(up{job="fastapi-app"})) to see the HPA react. Together they answer "is it up, is it busy, is it slow, is it erroring" at a glance, which is the point of a dashboard.
Chose the pod-count query as sum(up{...}) rather than relying on kube-state-metrics, because I disabled kube-state-metrics in the trim. It sums the up value of each healthy scrape target, which gives the live pod count without an extra component running.
Ran a load test with hey (hey -z 90s -c 8) against the app while watching the dashboard, for two reasons: to prove the metrics pipeline actually captures real traffic (not just a flat idle graph), and to drive CPU past the HPA's 70% target so the pod-count panel visibly climbs from 1 toward its max, then settles back after the cooldown. That live movement is what makes the screenshot worth putting in the README. I kept concurrency modest (-c 8) because heavier runs tipped the laptop into resource exhaustion; the goal was a visible signal, not a stress test.
The error-rate panel correctly showed no data during normal traffic, since the app has no failing endpoint. That is the honest, healthy state rather than a bug, and I noted it rather than manufacturing errors just to colour the panel.
Hit a real bug surfaced only by the pipeline: my Phase 1 /metrics was a hand-rolled placeholder returning JSON, so Prometheus rejected it with "unsupported Content-Type". Fixed by wiring in the instrumentator properly (Instrumentator().instrument(app).expose(app)), which serves real Prometheus-format text.
Made the whole setup reproducible rather than hand-nursed: captured the trimmed stack config in observability/values-prometheus.yaml and wrote a k8s/README.md so anyone can rebuild the cluster from scratch. The cluster is treated as disposable; nothing of value lives only inside it.
Left Loki out deliberately. Running the full metrics stack already pushed my 8GB laptop to its limit, and adding Loki plus Promtail (which tails and indexes all container logs on every node) would have reinvited the same resource exhaustion I had just fixed. The core observability competency was already demonstrated: metrics collection, scrape configuration via ServiceMonitor, and dashboards. Loki is another data source in Grafana rather than a fundamentally new skill. Logging is instead covered on the EC2 path via CloudWatch (planned Phase 6.5), on infrastructure that is not competing with the laptop. Scoping it out with a documented reason is a more honest engineering decision than cramming in something that half-works.