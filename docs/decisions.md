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
