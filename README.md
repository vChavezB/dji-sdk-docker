# DJI SDK Docker

I am starting a work with a dji drone and  decided to build a docker container.

It was not that trivial, since I had to search in the github issues what version of ffmpeg is used. In addition there is no info  about dependency versions.
This really becomes a headache when mantaining software so I decided to sit a day and look for all dependencies, and build from source. 

This allows to develop dji drone sdk apps independent of linux distro or system. Also for pipelines :) 

So feel free to use this as a template to build docker containers with the ffmpeg dependency and dji osdk and psdk.

Feedback and problems can be addressed in this repo through github issues or PRs.

# License

GPL v3.0

