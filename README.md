# Infrastructure for running mapping and planning on jackal

# Building 

## Step 1
Dockerfile assumes the following structure in the `./data` folder

```sh
tree ./data
data/
├── groundingdino_swint_ogc.pth
├── GroundingDINO_SwinT_OGC.py
└── huggingface
    └── hub
        ├── models--bert-base-uncasee
        |   | <huggingface llava model>
        ├── models--llava-hf--vip-llava-7b-hf
        |   | <huggingface llava model>
        └── version.txt
```

The Grounding Dino and Bert models can be found in this github [release](https://github.com/ZacRavichandran/open-vocab-vision-ros/releases/tag/data_v1). The Llava model is too large to host there. If you don't have a local version you can copy over, the model will be downloaded at runtime. If you need to do that, I reccomend saving the model to host, and then rebuilding the docker file, as downloading Llava can take a long time. 

## Step 2
To build the image, you'll need access to the following repos. They will be cloned during the build.

### existing repos
- [GrondingDino](https://github.com/ZacRavichandran/GroundingDino)
- [jackal](https://github.com/ZacRavichandran/jackal)
- [groundgrid](https://github.com/ZacRavichandran/groundgrid)

### custom 
- [jackal-infrastructure](https://github.com/ZacRavichandran/jackal-infrastructure)
- [llm-planning](https://github.com/ZacRavichandran/llm-planning)
- [open-vocab-vision-ros](https://github.com/ZacRavichandran/open-vocab-vision-ros)


## Step 3 
The build script assumes a github key (currently `id_github`), change this for your needs

The build the image
```sh
sh build.sh
```

# Running

## Launching 

The following will run the autonomy stack on the jackal

1. Jackal autonomy
```sh
roslaunch infrastructure_jackal jackal_autonomy.launch
```

2. vision
```sh
roslaunch open_vocab_vision_ros vison.launch
```

3. planning 
```sh
roslaunch llm_planning_ros planner.launch
```

[`planner.launch`]() doesn't not load a prior map. Replace with your needs. 

*Warning* This records a lot of data. 

4. [optional] recording
```sh
rosrun infrastructure_jackal record_jackal_data.sh
```

## 
```
rossservice call /llm_planning_ros/task "task: 'YOUR TASK'" 
```
