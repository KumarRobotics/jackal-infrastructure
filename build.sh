docker build -t llm_planning -f Dockerfile --build-arg ssh_prv_key="$(cat ~/.ssh/id_github)" --rm --build-arg ssh_pub_key="$(cat ~/.ssh/id_github.pub)"  .  
