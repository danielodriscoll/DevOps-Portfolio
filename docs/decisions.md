Phase 1:

Phase 2:
I found that i can use cache 'pip' on fresh vm, so the the next time the pipline is called, it's much quicker and efficent in loading previous requirements.txt

Learned how to set rules, stopped branches from merging to main on GitHub unless they pass the worflow checks -> LINT, TEST, BUILD
Also useful to avoid deleting my work and force pushing to main

I notoced the vulnerability scan of an image comes after it's pushed to a registery? I think it would make more sense to ensure an image is safe before pushing, hence I chnaged the workflow to: LINT TEST DOCKER, where Docker job will build, scan and then push image to registery, push only happens on main branch

I noticed I'm pushing a lot of commits where there's an issue that I could of checked locally e.g. checking ruff command that it works locally before seeing it brak on the worfklow, saves much more time, in future test run: commands locally first ruff

Trivy vulnerability check is good practice to see what need to be addressed in my image if anything, learned it's very important for .dockerignore file to avoid pushing an image with useless and sensitive data