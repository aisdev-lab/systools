# scripts and services to work with llama-swap and  sleep a headless ubuntu computer at idle

## scripts

** bin/safe-sleep: ** terminate any process is using AMD GPU before putting the computer into `hybrid-sleep`

** bin/gpu-fan-guard ** simple script to adjust fan speed of 7900xtx

** bin/gpu-power-monitor.sh ** script to monitor power consumption of AMD GPU (7900xtx), if the gpu power consumption
is below the threshold for a period of time, execute the given command by TRIGGER_COMMAND. The timer will be reset
whenever power consumption goes higher than the threshold or any keyboard activity in console.

> check the power consumption to determine if the gpu is currently running real job
> use environment varialbe "POWER_THRESHOLD" to control the threshold of power 
> consumption for GPU busy status, default: 100.


** bin/keep-awake ** run any command and prevent computer going to asleep by gpu-power-monitor service.

## services

** service/gpu-fan-guard.service ** systemd service to change speed of AMD GPU

** service/gpu-power-monitor.service ** monitor gpu power consumption and run a command

## safe-sleep helper

** profile.d/gpu-activity.sh ** monitor keyboard activities in ssh sessions to reset idle timer.
