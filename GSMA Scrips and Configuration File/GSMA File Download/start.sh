#!/bin/bash
set -x
module_name="gsma_tac"
main_module="" #keep it empty "" if there is no main module 
log_level="DEBUG" # INFO, DEBUG, ERROR

########### DO NOT CHANGE ANY CODE OR TEXT AFTER THIS LINE #########


. ~/.bash_profile

build="${module_name}.jar"

status=`ps -ef | grep "jar $build" | grep java`

echo $status

if [ "${status}" != "" ]  ## Process is currently running
then
  echo "${module_name} already started..."

else  ## No process running

  if [ "${main_module}" == "" ]
  then
     build_path="${APP_HOME}/${module_name}_module"
     log_path="${LOG_HOME}/${module_name}_module"
  else
     if [ "${main_module}" == "utility" ] || [ "${main_module}" == "api_service" ] || [ "${main_module}" == "gui" ]
     then
       build_path="${APP_HOME}/${main_module}/${module_name}"
       log_path="${LOG_HOME}/${main_module}/${module_name}"
     else
       build_path="${APP_HOME}/${main_module}_module/${module_name}"
       log_path="${LOG_HOME}/${main_module}_module/${module_name}"
     fi
  fi


  ## Starting process
  
  info_log_file=${log_path}/${module_name}_script_`date '+%Y%m%d'`.log
  error_log_file=${log_path}/${module_name}_script_`date '+%Y%m%d'`.error

  cd ${build_path}/script

  echo "Starting ${module_name} module process ..."
  ./script.sh ${log_level} ${log_path} ${build} 1>>${info_log_file} 2>>${error_log_file}  

  
  echo "Process ${module_name} is completed !!!"

  exit 0

fi
