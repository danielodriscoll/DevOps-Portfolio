# What I Learned

## Phase 1: FastAPI app + Docker

- A `.dockerignore` matters even this early → it keeps the venv, caches and local files out of the image so it stays small and doesn't ship anything I don't want in there.
- The container listens on port 80 internally, so I map it with `-p 8080:80` when running locally to avoid clashing with other things.

## Phase 2: CI/CD

- A lot of failed runs were things I could have checked locally first. Running commands like `ruff check .` and `pytest` before pushing saves the push and wait cycle.
- Trivy shows what CVEs are in an image. Learned the difference between fixable and unfixable ones, and that severity doesn't always mean real risk. Learned to work around unfixable errors.
- `.gitignore` won't hide sensitive info on a Docker image, use a `.dockerignore` file.

## Phase 3: Kubernetes deployment (kind + Helm)

- `kind` runs a real Kubernetes cluster inside Docker; `kubectl` is how you talk to it. Rolling out a new image version (via `kubectl set image` or an updated Deployment) scales pods up by one then removes an old one, keeping the app available throughout, and rollouts are tagged so you can revert.
- Can check pod logs which helps with tracking and debugging issues
- Ran into this error:

  ```
  Error: INSTALLATION FAILED: Unable to continue with install: Service "fastapi-app" in namespace "default" exists and cannot be imported into the current release: invalid ownership metadata; label validation error: missing key "app.kubernetes.io/managed-by": must be set to "Helm"; annotation validation error: missing key "meta.helm.sh/release-name": must be set to "fastapi-app"; annotation validation error: missing key "meta.helm.sh/release-namespace": must be set to "default"
  ```

  Helm refused to install because Service fastapi-app already existed from earlier raw kubectl apply and lacked Helm's ownership labels — fixed by `kubectl delete -f k8s/raw/` before running `helm install`, letting Helm create everything fresh with proper ownership metadata." . The way I understand it it objects created using yaml file sin kubernetes cluster an dalready existed, so when i went to recreate them using Helm, I got error.
- Came accross an issue with RedHat's Yaml support extension on VScode. It doesn't recognise some of the syntax that Helm uses on a YAML file. It highlighted red syntax error when there actually was no error, e.g the dash on `name: {{ .Values.appName }}-deployment` . Fixed it by just makig it a textfile named as .yaml file (don't select yaml as language on vscode or extension kicks in)
- So now with the autoscaler or HPA.yaml in place, kubernetes needs a way to track currnet pods and cpu information to know wheteher to upgrade or downgrade pods around our average of 70% CPU, so we need an add on called metrics-server which will ask kubelet in each pod how much cpu and memory is being used.
- Metrics-server doesnt recognise the any pod in my current cluster as it requires TLS certificate that is signed, kubelets certificates are self signed which it doenst recognise. this is a safety feature of metricsserver. To diagnose the issue I `kubectl describe pods -n kube-system -l k8s-app=metrics-server` to get a log of teh error, its a server 500 error when the readinees action (helath check of othe rpods) fails, so just because wer eon kind and ar enot as srict with security we can pass an arugment to tell metricserver to ignor eth eneed for certifictaes:

  ```
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
  ```

- When the HPA is active it overrides the replica count set in the Deployment/values → I set 3, it scaled down to my configured minimum of 2 based on real CPU usage.
- so now using `kubectl get hpa`, it sshowing my cpu usage from teh taret i set of 70% very useful, maybe I can use it fo rmetrics endpoint later on and dsiaply on dahsboards?
- Used 'hey' to simulate 10 concurrent users hammering the FastAPI app through the Gateway for 60 seconds, generating enough CPU load to push the HorizontalPodAutoscaler past its 70% target, confirming it automatically scaled from 2 to 4 replicas under load, then scaled back down after a cooldown period (approx 5 minutes) once traffic stopped. Note: used forward port argument to point laptop port at Gateway port to run hey command and do the load test.
- So writing the CI jobs for Helm linter and Kubeconform (kubernetes syntax) I ran into a small issue. Helm syntax is not registered as offcial Kubernetes syntax so we use `helm template` to resolve all the values placeholders `{{ }}`. We ouput this to a file and run that by kubeconform.
- Ran kubeconform locally but had an error with HTTProute and Gateway Schemas. This happened because kubeconfrom is for core kubernetes types, to get around this we use `-schema-location` to point to a custome resource definition for API gateway and HTTProute on the community driven datreeio/CRDs-catalog. How do I ensure these comunity repos are safe and ensure security when auto downlaodingd CRDS?
- Finsihed two workflows, tagged a new version fo rmy main repo and it failed  atrivy scan. I realised my `requirements.txt` contains devops tooling unrelated to the fastapi app being deployed and shipped to cloud. Like it doesnt not need ansible and pytest in it when being shipped. This is why my images were taking awhile to be built and scanned so spotted a security and bloating issue with trivy!
- Issue with trivy flagging high CVE's, after debugging it' snot to do with my app or its dependencies or even my requirements. It was the python:3.14-slim image used in th edocker file has underlying dependencies e.g. setuptools that are outdated. So trivy caught issues that I didn't really think were associated with me and my build. Fix is to update setuptools with `RUN pip install --no-cache-dir --upgrade pip setuptools wheel` in docker file. Why not just update everything to latest version? - could be riskyy and break code or unexpected beahvior.
- Learned the practical shape of vulnerability management: you don't fix it once. Some findings are unfixable (awaiting upstream), some aren't real risk in context, and the goal is to patch what you cleanly can, minimise attack surface, and document the rest.

## Phase 4: AWS infrastructure with Terraform

- I learned that it's good practice to verify company software uisng keys. You download public key locally froM hashicorp, then when your downlaoading or installing software e.g. Terraform, you downlaod it ensureing the signature from matches our Hashicorp key using `signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg]`
- New AWS accounts (post-July 2025) are on a credit-based Free plan → $100 in credits at signup, up to $200 with onboarding tasks, six-month lifespan. Different from the old 12-month free tier that most tutorials still describe. The upside: the Free plan can't surprise-bill; if credits run out the account just stops.
- State is Terraform's *memory* of what it has built. It downloads state at the start of each run, compares against my `.tf` code, and computes the minimal diff. That's what makes Terraform declarative rather than imperative: I describe the desired end state, and it figures out what to change (in-place update, replace, destroy) with `~` and `-/+` symbols in the plan.
- Inline comments in `.gitignore` broke the pattern match and nearly leaked my IP → moved them to separate lines.
- Hit and fixed a real-world issue, my home broadband IP changes dynamically, so SSH failed until I updated `terraform.tfvars` and re-applied, which demonstrated Terraform's value: one line changed, one firewall rule updated in place, no resources recreated. Successfully SSH'd into the live server (learning that a cloud instance has both a public IP for internet access and a private IP for AWS-internal networking, and that the first-connection fingerprint prompt is SSH's trust-on-first-use identity check).
- An EC2 instance has two IPs at once: a public one (how the internet reaches it) and a private one (AWS-internal networking). SSH connects via the public IP; the shell prompt shows the private one as the machine's internal hostname. Together with my own IP (in the firewall rule), there were three IPs in play during a single SSH session.
- After pushing new commit, the terraform jobs failed. Firstly due to incorrect foramtting, my public ssh key that get attached to the ec2 is obtained with `file()` from my local machine, but the ci piplien uses a new ubuntu VM which cant see outside the project folder. Solution woul dbe to add the ssh key as a variable into hidden `terraform.tfvars` and declare it in my `variables.tf` and call it in the `main.tf`.
- Note: issue, uploaded new tag which triggers image to be built which contains docker

## Phase 5: Ansible configuration management

- From my understanding AWS IAM User is for long term credentials and logins by users and apps, roles are short term permissions with specific access (usually aws services), policies are the restrictions on what users/roles can access in JSON format.
- Note when adding a role to EC2 it require a wrapper, in this case we have an IAM instance that gets attached to ec2 as an object. Attaching instance require delete and recreate of EC2 (be careful in future, its ok fo rmy project because I destroy anyway)
- Ran into permission error, the user policies attached to my local laptop under terraform-user do not have necessary permissions:

  ```
  terraform-user is not authorized to perform: iam:CreateRole on resource:
  /terraform-user is not authorized to perform: secretsmanager:CreateSecret
  ```

  This is a good example of least privilege access working corrcetly, stopped my terraform-user from perfoming these actions, must update it's policies.
- Big error I made, `git add` and commit from within my ansible folder only pushed changes in that folder, not th entire devops-portfolio, so terraform and decision changes didnt upload. `add .` is currnet repo, `git -A` is entire repo. I used `git restore` which removed my progress. I got my work back using vscode command palatte - local history find entity and restore.
- Running `ansible-inventory --list` was failing due to a default secuirty feature where this command will only allow and read an ansible directory that is not writable to everyone which mine was not so it failed. Fixed it with `chmod 755` on that directory, allowing only the owner full permissions and not the groups or others. This avoids malicios edits to .cfg file that Ansible could run. Good practice also on Linux to follow least privilege access rule so that if an attacker get access to a service the blast radius of what they can do is minimised.
- My ISP keeps changing my ip throughout development, most be a secuirty feature, so it keeps breaking the ip in TFvars file.
- This phase seems to be a real test to see if I like solving issue around connecting these tools. This ANsible phase has proven tricky so far. Ansible playbook failed on trying to install requests module as rpm from the linux image being used already contained it. It then broke authenticating to GHCR due to an expired token. This was the security detup of 30 days for a token that I setup in earlier phases working correctly.
- Made a silly mmistake, adjusted the Dockerfile to be multistage build to fix the setuptools error, howeveer I forgot to buil dthe images an dtets th econtaienr myself, turns out theres an issues that I spotted now when pulling that image with Ansible and trying to run it. The issue is the fastapi executable in the bin folder is not getting copied across to the second datge of the build so error running the script using:

  ```dockerfile
  CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]
  ```

  So fastapi is the middleman which uses uvicorn under the hood, uvicorn is also in bin folder but also site-packages folder which does get copied across so will work

## Phase 6: Observability (Prometheus, Grafana)

- App already has `/metrics` endpoint which we need prometheus to scrape data from in order to monitor.
- Installed the kube-prometheus-stack Helm chart using Helm commands into a dedicated namespace called "monitoring" this chart comes bundled with Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, and the Prometheus Operator in one
- Grafana comes with pre-built dashboards for Kubernetes internals (nodes, pods, cluster) but nothing for my app until Prometheus starts scraping via the ServiceMonitor.
- So I readjusted my `/metrics` endpoint in my app/ , the fastapi-instrumentor package can use the Instrumentor Class to implement a middleware that allows prometheueus to automatically create a `/metrics` endpoint in order to track app metrics.
- Hit a real bug surfaced only by the pipeline: my Phase 1 `/metrics` was a hand-rolled placeholder returning JSON, so Prometheus rejected it with "unsupported Content-Type". Fixed by wiring in the instrumentator properly (`Instrumentator().instrument(app).expose(app)`), which serves real Prometheus-format text.
- When rebuilding the image, came across error: `ERROR: failed to build: failed to solve: error getting credentials - err: exit status 1`, my docker config file picked up broken Windows helper reference since docker runs on windows. to fix it on WSL `echo '{}' > ~/.docker/config.json` TO EMPTY THE CONFIG.
- New pods wouldn't rollout new v0.6.0 tag because the ghcr.io image repo was set to private during Phase 5 and the kind cluster has no pull secret Old pods stayed up safely because Kubernetes refuses to kill working pods until new ones are healthy, in order to complete rollout i must give GHCR permissions to my cluster
- Diagnosed with `kubectl describe pod -l app=fastapi-app` → "unauthorized" error on image pull.
- Noticed something interesting when fixing rollout, after applying new token, 3 pods were rolled out when hpa is set to min 2 , max 4. I thought why 3 pods? `get hpa -w` said unknown/70% cpu which is the target I set, further investigations with `kubectl get pods -n kube-system | grep metrics-server` showed metrics-server pod was down?
- I have metrics server pod down with CrashLoopBackOff meaning kubernetes keeps restarting it but it crashes?
- Diagnosing the problem more with `kubetcl get deployment metrics-server -n kube-system` we get:
  - READY 0/1 which means Deployment wants 1 pod healthy, has 0
  - AVAILABLE 0 means no healthy pod available
  - UP-TO-DATE 1 means Kubernetes has created the current version which tells me whatever we did create isn't working
- describing th epod itself with: `kubectl describe pod -n kube-system -l k8s-app=metrics-server`. I got information in the log sthat the conatiner was pulled sucessfully and running, but metrics-server responded with an error when kubelet asked are you ready: `Readiness probe failed: HTTP probe failed with statuscode: 500`. Continues to see if it's alive but dies: `Liveness probe failed: Get "https://10.244.0.10:10250/livez": context deadline exceeded`
- To get root cause of why metrics-server was failling and retuning 500, I tried fetching the logs the conatiner with: `kubectl logs -n kube-system -l k8s-app=metrics-server --previous --tail=100`, but it returned nothing.
- using `kubectl get pods -n kube-system | grep metrics-server`, I can see the pod crashed 25 seconds ago which tells me its still restarting over and over with error each time, so when i chekc the logs , a new pod is constantly being made or restarted with new id.
- Trying to dig deeper into th eissue i foun dthis to b ete hmost readbale for reading console logs: `docker exec devops-portfolio-cluster-control-plane journalctl -u kubelet --no-pager --since "10 minutes ago" | less -S`. Here I found metrics-server, nginx-gateway , scheduler etc all thes epods were failing?
- I realised that the default kube-prometheus-stack is built for real multi-node clusters, not a laptop, so out of the box it scraped ~15 targets, evaluated hundreds of recording/alert rules constantly, and pulled heavy kubelet metrics I didn't need, which pegged all 8 CPUs (823%/800% in Docker) and froze the machine. I diagnosed it as resource exhaustion rather than a config bug from the kubelet logs (iptables ChainExists taking 3.7s, housekeeping took too long) and the fact that many unrelated components were failing at once, not just one.
