# scripts and services to work with llama-swap and  sleep a headless ubuntu computer at idle

## scripts

**bin/safe-sleep** terminate any process is using AMD GPU before putting the computer into `hybrid-sleep`

**bin/gpu-fan-guard** simple script to adjust fan speed of 7900xtx

**bin/gpu-power-monitor.sh** script to monitor power consumption of AMD GPU (7900xtx), if the gpu power consumption
is below the threshold for a period of time, execute the given command by TRIGGER_COMMAND. The timer will be reset
whenever power consumption goes higher than the threshold or any keyboard activity in console.

> check the power consumption to determine if the gpu is currently running real job
> use environment varialbe "POWER_THRESHOLD" to control the threshold of power 
> consumption for GPU busy status, default: 100.


**bin/keep-awake** run any command and prevent computer going to asleep by gpu-power-monitor service.

## services

**service/gpu-fan-guard.service** systemd service to change speed of AMD GPU

> copy to /etc/systemd/system/gpu-fan-guard.service
> run `systemctl reload-daemon` and `systemctl enable gpu-fan-guard.service`, `systemctl start gpu-fan-guard.service`

**service/gpu-power-monitor.service** monitor gpu power consumption and run a command

> copy to /etc/systemd/system/gpu-power-monitor.service
> run `systemctl reload-daemon` and `systemctl enable gpu-power-monitor.service`, `systemctl start gpu-gpu-power.service`


## safe-sleep helper

**profile.d/gpu-activity.sh** monitor keyboard activities in ssh sessions to reset idle timer.

> copy to /etc/profile.d/gpu-activity.sh
> and add following lines in ~/.bashrc or ~/.profile

```
# load keyboard command monitor
if [[ $- == *i* && -n ${SSH_CONNECTION:-} ]] &&
   [[ -r /etc/profile.d/gpu-activity.sh ]] &&
   [[ -z ${_GPU_ACTIVITY_HOOK_LOADED:-} ]]; then
    export _GPU_ACTIVITY_HOOK_LOADED=1
    source /etc/profile.d/gpu-activity.sh
fi

``` 
