#!/bin/bash
#set -x
##1 Make GSMA process start entry in  audit table 
#source . /root/.bash_profile
source ~/.bash_profile
. ${APP_HOME}/gsma_tac_module/GSMAFileDownload/configuration.txt
var=""
serverName=$HOSTNAME
module_name=gsma_tac
echo "$(date +%F_%H-%M-%S): server name = $serverName"
commonConfigurationFile=$commonConfigurationFilePath
#GSMAConfigurationFile=$GSMAConfigurationFilePath2
#source $GSMAConfigurationFile
source $commonConfigurationFile
get_value() {
    key=$1
    grep "^$key=" "$commonConfigurationFile" | cut -d'=' -f2
}


executionstartTime=$(date +%s.%N)
dbDecryptPassword=$(java -jar  ${APP_HOME}/encryption_utility/PasswordDecryptor-0.1.jar dbEncyptPassword)

#Checking configuration files are import or not
echo "common $commonConfigurationFile"
if [  ! -e "$commonConfigurationFile"  ] 
     then
	   echo "$(date +%F_%H-%M-%S): file not found (once NMS tool finalisze we will explore raising alarm  from this script) ,now script is terminated."
		raise_alert "alert1010"
	  exit 1;
fi	

#Going to check  proccess status(Already completed for current date  or not) 
if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  fileProcessStatusCode=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
    select status_code from aud.modules_audit_trail where feature_name IN ('$feature_name_process' , '$feature_name_download') and  to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and ROWNUM <=1 order by id desc;
EOF
`
elif [ $databaseFlag == "Mysql" ]
	then
	 echo "Mysql block"		 
	fileProcessStatusCode=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select status_code from aud.modules_audit_trail where created_on LIKE '%$(date +%F)%' and feature_name IN ('$feature_name_process' , '$feature_name_download')  and status_code=200  limit 1")
fi
echo  "$(date +%F): file process status code= $fileProcessStatusCode"
if [ "$fileProcessStatusCode" = "200" ];
		then
			echo "$(date +%F_%H-%M-%S): GSMA file download and File process is already completed today  going to stop this process."
			exit 0;
fi

# File process is compelted or not block is end here 
#All Common function defination starts here
# Function to fetch configured value from sys param table start here 
fetch_configured_value(){
local tag=$1;
if [ $databaseFlag == "Mysql" ]
then
value=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.sys_param where tag='$tag'")
elif [ $databaseFlag == "Oracle" ]
then
value=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
	 set heading OFF;	
	select value from app.sys_param where tag='$tag';
EOF
`
fi
echo "$value"
}
# Function to fetch configured value from sys param table ends here 
# Function for update modules audit table 
update_module_audit_table(){
local statusCode=$1;
local status=$2;
local errorMessage=$3
local info=$4
local count=$5
local executionTime=$6
local count2=$7
local FailureCount=$8
if [ $databaseFlag == "Mysql" ]
then
mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
     update aud.modules_audit_trail set status_code='$statusCode',status='$status',error_message='$errorMessage',feature_name='$feature_name_download',info='$info',count='$count',action='Download',server_name='$serverName',execution_time='$executionTime',module_name='$module_name_download' ,count2='$count2', Failure_count='$FailureCount' ,modified_on=CURRENT_TIMESTAMP where module_name='$module_name_download' and feature_name='$feature_name_download' order by id desc limit 1;
EOFMYSQL
 elif [ $databaseFlag == "Oracle" ]
then
`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='$statusCode',status='$status',error_message='$errorMessage',feature_name='$feature_name_download',info='$info',count='$count',action='Download',server_name='$serverName',execution_time='$executionTime',module_name='$module_name_download' ,count2='$count2', Failure_count='$FailureCount' ,modified_on=SYSTIMESTAMP where module_name='$module_name_download' and feature_name='$feature_name_download'  and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`
fi
}
# Update modules audit table function ends here

#Function for Raising Alert starts here
alertUrl=$(get_value "eirs.alert.url");
filecopyUrl=$(get_value "eirs.filecopy.url");

raise_alert(){
local alertId=$1;
local alertMsg=$2;
 curl -X POST "$alertUrl" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"$alertId\", \"alertMessage\": \"$alertMsg\", \"alertProcess\": \"\", \"description\": \"\", \"featureName\": \"\", \"ip\": \"\", \"priority\": \"\", \"remarks\": \"\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"\", \"userId\": 0}"
}
#Function for Raising Alert ends here
#Function starts for File Copy 
file_copy(){
curl -X POST "$filecopyUrl" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"appName\": \"\", \"destination\": [ { \"destFilePath\": \"$gsmaFileDownloadPath\", \"destServerName\": \"$destServerName\" } ], \"remarks\": \"\", \"serverName\": \"$serverName\", \"sourceFileName\": \"DeviceDatabase.jsonl_ProcessedFile\", \"sourceFilePath\": \"$gsmaFileDownloadPath\", \"sourceServerName\": \"\", \"txnId\": \"\"}"
}

#Function ends here for File Copy 
#All Common function defination ends here



# process starts from here going to make an entry in audit table 
if [ $databaseFlag == "Oracle" ]
then
     `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
	insert into aud.modules_audit_trail (status_code,status,error_message,feature_name,info,count,action,server_name,execution_time,module_name,count2,Failure_count)  values( 201,'$gsmaFileProcessInitial','NA','$feature_name_download' ,'NA' , 0 ,'Download','$serverName',0,'$module_name_download',0,0);
  commit;
EOF
`
elif [ $databaseFlag == "Mysql" ]
	then	 
mysql -h$dbIp -P$dbPort -u$dbUsername  -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		insert into aud.modules_audit_trail (status_code,status,error_message,feature_name,info,count,action,server_name,execution_time,module_name,count2,Failure_count)  values( 201,'$gsmaFileProcessInitial' ,'NA','$feature_name_download' ,'NA' , 0 ,'Download','$serverName',0,'$module_name_download',0,0);  
EOFMYSQL
fi

#2 read configuration value for  download GSMA File sys_param table 
tacFileURL=$(fetch_configured_value "tacFileURL")
tacFileURLUsername=$(fetch_configured_value "tacFileURLUsername");
tacFileURLPassword=$(fetch_configured_value "tacFileURLPassword");
if [ "$tacFileURL" = "$var" ] || [ "$tacFileURLUsername" = "$var" ] || [ "$tacFileURLPassword" = "$var" ];
		then
			echo "$(date +%F_%H-%M-%S): Credential is not correct for Download GSMA File , alert is raising for this issue. , (once NMS tool finalisze we will explore raising alarm  from this script) ,now script is terminated."
			# Raising Alert
			raise_alert "alert1001"
			executionFinishTime=$(date +%s.%N);
		    ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		    secondDivision=1000
		    finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
			finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
			# Updating Modules audit table 
			update_module_audit_table 501 "Fail" "$gsmaDownloadUrlDetail" 0 0 "$finalExecutionTime" 0 0	
exit 2;
fi


# Check configuration file download path or process path is configured or not 

if [[ ! -e "$gsmaFileDownloadPath" || ! -e "$processLogPath" || ! -e "$fileProcessModulePath" ]]; 
		then
		if [ ! -e "$gsmaFileDownloadPath" ]; then
		alertMessage=$file_path_alert;
		elif [ -e "$processLogPath" ]; then
		alertMessage=$log_path_alert;
		elif [ -e "$fileProcessModulePath" ]; then
		alertMessage=$process_path_alert;
		fi
		echo "$(date +%F_%H-%M-%S):configuration value $alertMessage Not found"
		# Raising Alert
		raise_alert "alert1005"	"$alertMessage"
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
		# Updating Modules audit table 
		update_module_audit_table 501 "Fail" "$gsmaFileProcessPathNotFound" 0 0 "$finalExecutionTime" 0 0	
exit 3;
fi
#Going to start Download GSMA file
echo "$(date +%F_%H-%M-%S) - file download started " 	
cd $gsmaFileDownloadPath 
#3 removing old  DeviceDatabase.zip file
rm -f DeviceDatabase.zip
#4 Downloading  DeviceDatabase.zip file
curl -LXPOST $tacFileURL -d "username=$tacFileURLUsername&password=$tacFileURLPassword" -o DeviceDatabase.zip

#5 Check file Size 
if [ $(stat -c%s DeviceDatabase.zip) -lt $fileSize ];
		then
		echo "$(date +%F_%H-%M-%S) - file is less than 40 mb ,process is terminated  "
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
		# Raising Alert
		raise_alert "alert1003"
		# Updating Modules audit table 
		update_module_audit_table 501 "Fail" "$gsmaIncompleteFileDownload" 0 0 "$finalExecutionTime" 0 0	
exit 1
fi
#6 Unzip downloaded device database zip file
unzip -o DeviceDatabase.zip
if [ ! -e "DeviceDatabase.jsonl" ]; 
		then
		echo "$(date +%F_%H-%M-%S) : file unziping Failed process is terminated."
		# Raising Alert
		raise_alert "alert1004"
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
		#Updating Modules audit table 
		update_module_audit_table 501 "Fail" "$gsmaFileUnzippingFailed" 0 0 "$finalExecutionTime" 0 0	
		exit 1
fi
#7 Compare new file(DeviceDatabase.jsonl) data with  existing file (DeviceDatabase.jsonl_ProcessedFile) if found, else process with new file 
processedFile="$(find  -maxdepth 1 -name 'DeviceDatabase.jsonl_ProcessedFile' -type f -printf "%f")"
if [ "$processedFile" == "DeviceDatabase.jsonl_ProcessedFile" ];
		then
		echo "$(date +%F_%H-%M-%S) :- DeviceDatabase.jsonl_ProcessedFile file comparision starting."
        diff  DeviceDatabase.jsonl_ProcessedFile DeviceDatabase.jsonl|grep ">"|cut -c 3- > DeviceDeltaDatabase.jsonl
        echo "$(date +%F_%H-%M-%S) :- file comparision finish and result save to DeviceDeltaDatabase.jsonl file ,going to start file process code "
else
		echo "$(date +%F_%H-%M-%S) : copying DeviceDatabase.jsonl to DeviceDeltaDatabase.jsonl"
        cd $gsmaFileDownloadPath
	    cp DeviceDatabase.jsonl DeviceDeltaDatabase.jsonl
        echo "$(date +%F_%H-%M-%S) : copy finished "
fi  

#Cheking DeviceDeltaDatabase.jsonl file is empty or not
filename='DeviceDatabase.jsonl'
totalGSMATACcount=$(cat ${filename} | wc -l)
    echo "Total number of record count in DeviceDatabase.jsonl is $totalGSMATACcount"
if [ -s DeviceDeltaDatabase.jsonl ]
then
     echo "$(date +%F_%H-%M-%S) : File is not empty process will continue"
else
     echo "$(date +%F_%H-%M-%S) : File is empty going to stop this process here."
	    executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
		#Updating Modules audit table 
		update_module_audit_table 200 "$gsmaDeltaFileBlank" "NA" "NA" 0 "$finalExecutionTime" 0 0		
exit
fi
#8 start java process
cd $fileProcessModulePath
#java -Dlog4j.configuration=file:./log4j.properties -jar GsmaTacUpdate-0.1.jar -Dspring.config.location=:./conf.properties  1> $processLogPath/GSMAFileProcessLOG_$(date +%Y%m%d%H%M%S).log		
java -Dlog4j.configurationFile=file:./log4j2.xml -Dmodule.name=${module_name} -Dspring.config.location=:./configuration.properties -jar gsma_tac-0.1.jar 1>/dev/null 2>${LOG_HOME}/${module_name}.error


#9 Check java process status in modules_audit_trail table  & Move processed DeviceDatabase.jsonl_yyyymmdd to backup folder and update latest DeviceDatabase.jsonl_ProcessedFile if status is 200 (success)
cd $gsmaFileDownloadPath 
if [ $databaseFlag == "Oracle" ]
then
     fileProcessUtiltyStatusCode=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;
    select status_code from aud.modules_audit_trail where  to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and feature_name IN ('$feature_name_process')  and status_code=200;
EOF
`
elif [ $databaseFlag == "Mysql" ]
then
	fileProcessUtiltyStatusCode=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select status_code from aud.modules_audit_trail where created_on LIKE '%$(date +%F)%' and feature_name IN ('$feature_name_process')  and status_code=200");
fi
echo "$(date +%F_%H-%M-%S) : status code of java file process   = $fileProcessUtiltyStatusCode";
if [ "$fileProcessUtiltyStatusCode" = "200" ];
		then
			rm -f DeviceDatabase.jsonl_ProcessedFile
			cp 	DeviceDatabase.jsonl DeviceDatabase.jsonl_ProcessedFile
			echo "going to call Copy API"
			file_copy
			echo "$(date +%F_%H-%M-%S) : Copied file DeviceDatabase.jsonl to DeviceDatabase.jsonl_ProcessedFile "
			mv  DeviceDatabase.jsonl $fileBackupPath/DeviceDatabase.jsonl_$(date +%Y%m%d)
			gzip $fileBackupPath/DeviceDatabase.jsonl_$(date +%Y%m%d)
			mv  DeviceDeltaDatabase.jsonl $deltaFileBackupPath/DeviceDeltaDatabase.jsonl_$(date +%Y%m%d)
			cd $deltaFileBackupPath
			gzip $deltaFileBackupPath/DeviceDeltaDatabase.jsonl_$(date +%Y%m%d)
			echo "$(date +%F_%H-%M-%S) : Moved file DeviceDatabase.jsonl to $fileBackupPath folder and moved file DeviceDeltaDatabase.jsonl to $deltaFileBackupPath folder ";
			cd $gsmaFileDownloadPath
			rm -f  DeviceDatabase.zip
else 
		echo "$(date +%F_%H-%M-%S) : 200 status  not found , File process utility not complete successfully. "
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")
		# Raising Alert
		raise_alert "alert1007"
		# Updating Modules audit table 
		update_module_audit_table 501 "Fail" "$gsmaFileProcessNotComplete" 0 0 "$finalExecutionTime" 0 0
exit 1
fi
#10 sucess entry in audit table 
	    executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`  
		finalExecutionTime=$(printf "%.0f" "$finalExecutionTime")		
if [ $databaseFlag == "Oracle" ]
then
 updatedCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select count(*) from gsma_tac_detail where   to_char(modified_on,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and action='update';
EOF
`
insertCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select count(*) from gsma_tac_detail where   to_char(modified_on,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and action='insert'
EOF
`
totalCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
    select count(*) from gsma_tac_detail;
EOF
`
Failure_count=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select Failure_count from aud.modules_audit_trail where module_name='$module_name_download' and feature_name='$feature_name_download' and ROWNUM <=1 order by id desc
EOF
`

elif [ $databaseFlag == "Mysql" ]
then
updatedCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_detail where  modified_on LIKE '%$(date +%F)%' and action='update'");
insertCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_detail where  modified_on LIKE '%$(date +%F)%' and action='insert'");
totalCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_detail");
Failure_count=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select Failure_count from aud.modules_audit_trail where module_name='$module_name_download' and feature_name='$feature_name_download' order by id desc limit 1");

fi
		echo "$(date +%F_%H-%M-%S) : total number of record Failed=$Failure_count"
		echo "$(date +%F_%H-%M-%S) : total number of record updated=$updatedCount"
		echo "$(date +%F_%H-%M-%S) : total number of record inserted=$insertCount"
		echo "$(date +%F_%H-%M-%S) : total number of record =$totalCount"
		# Updating Modules audit table  for succeess 
		update_module_audit_table 200 "$gsmaFileDownloadCompletedMsg" "NA" "" $totalGSMATACcount  "$finalExecutionTime" 0 $Failure_count
if [ $databaseFlag == "Oracle" ]
then
`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set info='DeviceDatabase.jsonl_$(date +%Y%m%d)' where module_name='$module_name_process' and feature_name='$feature_name_process'  and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`
 elif [ $databaseFlag == "Mysql" ]
then
mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set info='DeviceDatabase.jsonl_$(date +%Y%m%d)' where module_name='$module_name_process' and feature_name='$feature_name_process' order by id desc limit 1;
EOFMYSQL
fi
echo "$(date +%F_%H-%M-%S) : File download proccess completed successfully."
exit 0;
