#!/bin/bash
set -x
##1 Make GSMA process start entry in  audit table 
source . /root/.bash_profile
var=""
serverName=$HOSTNAME
echo "$(date +%F_%H-%M-%S): server name = $serverName"
commonConfigurationFile=$commonConfigurationFilePath
GSMAConfigurationFile=$GSMAConfigurationFilePath
source $GSMAConfigurationFile
source $commonConfigurationFile

dbDecryptPassword=$(java -jar  ${APP_HOME}/encryption_utility/PasswordDecryptor-0.1.jar dbEncyptPassword)
#dbDecryptPassword=app123
if [  ! -e "$GSMAConfigurationFile"  ] || [  ! -e "$commonConfigurationFile"  ] 
     then
	   echo "$(date +%F_%H-%M-%S): file not found (once NMS tool finalisze we will explore raising alarm -f from this script) ,now script is term -finated."
	   exit 1;
fi	   

echo "database flag $databaseFlag"
echo "---++++-$databaseFlag >username==$dbUsername , password=$dbDecryptPassword , port===$dbPort , IP=$dbIp , db name=--$dbServiceOrcl"
echo "**** sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl}"

if [ $databaseFlag == "Oracle" ]
     then
     echo "Oracle block"
	 tacFileURL=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
	 set heading OFF;	
	select value from app.sys_param where tag='tacFileURL';
EOF
`
	 tacFileURLUsername=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;
	 select value from app.sys_param where tag='tacFileURLUsername';
EOF
`
	 tacFileURLPassword=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;
	 select value from app.sys_param where tag='tacFileURLPassword';
EOF
`
	   echo "tacFileURL==$tacFileURL , tacFileURLUsername==$tacFileURLUsername ,tacFileURLPassword=$tacFileURLPassword"
elif [ $databaseFlag == "Mysql" ]
     then
	 echo "Mysql block"	
     tacFileURL=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.sys_param where tag='tacFileURL'")
     tacFileURLUsername=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.sys_param where tag='tacFileURLUsername'")
     tacFileURLPassword=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.sys_param where tag='tacFileURLPassword'")
	 echo "tacFileURL==$tacFileURL , tacFileURLUsername==$tacFileURLUsername ,tacFileURLPassword=$tacFileURLPassword"
fi
#2 read configuration value of file  download url from MySQL database table system_configuration_db
#gsmaTacFileURL=$(mysql $dbName -u$dbUsername  -p$${dbDecryptPassword} -se "select value from system_configuration_db where tag='gsmaTacFileURL'")


if [ $tacFileURL -eq $var ] || [ $tacFileURLUsername -eq $var ] || [ $tacFileURLPassword -eq $var ];
		then
			echo "$(date +%F_%H-%M-%S): Unable to establish connection with database, alert is raising for this issue. , (once NMS tool finalisze we will explore raising alarm -f from this script) ,now script is term -finated."
			
	if [ $databaseFlag == "Oracle" ]
     then
     echo "Oracle block"
	curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1001\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1001"
	   
	   
elif [ $databaseFlag == "Mysql" ]
     then
	 echo "Mysql block"	
     curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1001\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1001"
fi			
exit 2;
fi
echo "---$(date +%F)"

if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  fileProcessStatusCode=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
    select status_code from aud.modules_audit_trail where feature_name IN ('GSMA Data Processor' , 'GSMA Download Database') and  to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and ROWNUM <=1 order by id desc;
EOF
`
	  echo "fileProcessStatusCode==$fileProcessStatusCode"
elif [ $databaseFlag == "Mysql" ]
	then
	 echo "Mysql block"		 
	fileProcessStatusCode=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select status_code from aud.modules_audit_trail where created_on LIKE '%$(date +%F)%' and feature_name IN ('GSMA Data Processor' , 'GSMA Download Database')  and status_code=200  limit 1")
 echo "fileProcessStatusCode==$fileProcessStatusCode"
 fi
echo  "$(date +%F): file process status code= $fileProcessStatusCode"
if [ $fileProcessStatusCode -eq 200 ];
		then
			echo "$(date +%F_%H-%M-%S): GSMA file download and File process is already completed today  going to stop this process."
			exit 0;
fi
executionstartTime=$(date +%s.%N)
if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  gsmaFileProcessIntialMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
     select value from app.msg_cfg where tag='gsmaFileProcessIntial';
EOF
`
	  `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
	insert into aud.modules_audit_trail (status_code,status,error_message,feature_name,info,count,action,server_name,execution_time,module_name,count2,failure_count)  values( 201,'$gsmaFileProcessIntialMsg','NA','GSMA Download Database' ,'NA' , 0 ,'Download','$serverName',0,'GSMA TAC - Download Manager',0,0);
  commit;
EOF
`
elif [ $databaseFlag == "Mysql" ]
	then
	 echo "Mysql block"
gsmaFileProcessIntialMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileProcessIntial'")
mysql -h$dbIp -P$dbPort -u$dbUsername  -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		insert into aud.modules_audit_trail (status_code,status,error_message,feature_name,info,count,action,server_name,execution_time,module_name,count2,failure_count)  values( 201,'$gsmaFileProcessIntialMsg' ,'NA','GSMA Download Database' ,'NA' , 0 ,'Download','$serverName',0,'GSMA TAC – Download Manager',0,0);  
EOFMYSQL
fi
if [ ! -e "$fileDownloadPrcoessPath" ]; 
		then
		echo "$(date +%F_%H-%M-%S): $(date +%F)$fileDownloadPrcoessPath  not exists. process term -finated"
		
		if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1002\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1002"
elif [ $databaseFlag == "Mysql" ]
	then
	 echo "Mysql block"
     curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1002\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1002"
fi
exit 3;
fi
echo "$(date +%F_%H-%M-%S) - file download started " 	
cd $fileDownloadPrcoessPath 

#3 removeing old  DeviceDatabase.zip file
rm -f DeviceDatabase.zip
#4 Downloading  DeviceDatabase.zip file
curl -LXPOST $tacFileURL -d "username=$tacFileURLUsername&password=$tacFileURLPassword" -o DeviceDatabase.zip


#5 Check file Size 
if [ $(stat -c%s DeviceDatabase.zip) -lt $fileSize ];
		then
		echo "$(date +%F_%H-%M-%S) - file is less than 40 mb ,process is term -finated  "
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  gsmaIncompleteFileDownloadMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
	 select value from app.msg_cfg where tag='gsmaIncompleteFileDownload';
EOF
`
	   `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaIncompleteFileDownloadMsg',feature_name='GSMA Download Database',info='NA',count=0,action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0',modified_on=SYSTIMESTAMP where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')'and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`
  curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1003\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1003"
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
	 gsmaIncompleteFileDownloadMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaIncompleteFileDownload'")
		mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaIncompleteFileDownloadMsg',feature_name='GSMA Download Database',info='NA',count=0,action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL
		curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1003\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1003"
fi	 		
exit 1
fi
#6 Unzip downloaded device database zip file
unzip -o DeviceDatabase.zip
if [ ! -e "DeviceDatabase.jsonl" ]; 
		then
		echo "$(date +%F_%H-%M-%S) : file unziping failed process is terminated."
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		
				if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  gsmaFileUnzippingFailedMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
     select value from app.msg_cfg where tag='gsmaFileUnzippingFailed';
EOF
`
	  
      `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileUnzippingFailedMsg',feature_name='GSMA Download Database',info='NA',count=0,action='Download',server_name='$serverName',modified_on=SYSTIMESTAMP,execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0' where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`	  
curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1004\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1004"
	   
  	
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
			
		gsmaFileUnzippingFailedMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileUnzippingFailed'")
		mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileUnzippingFailedMsg',feature_name='GSMA Download Database',info='NA',count=0,action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL
		curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1004\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1004"
fi	
exit 1
fi
#7 Compare new file(DeviceDatabase.jsonl) data to existing file (DeviceDatabase.jsonl_ProcessedFile) if found else process with new file 
processedFile="$(find  -maxdepth 1 -name 'DeviceDatabase.jsonl_ProcessedFile' -type f -printf "%f")"
if [ "$processedFile" == "DeviceDatabase.jsonl_ProcessedFile" ];
		then
		echo "$(date +%F_%H-%M-%S) :- DeviceDatabase.jsonl_ProcessedFile file comparision starting."
        diff  DeviceDatabase.jsonl_ProcessedFile DeviceDatabase.jsonl|grep ">"|cut -c 3- > DeviceDeltaDatabase.jsonl
        echo "$(date +%F_%H-%M-%S) :- file comparision finish and result save to DeviceDeltaDatabase.jsonl file ,going to start file process code "
else
		echo "$(date +%F_%H-%M-%S) : copying DeviceDatabase.jsonl to DeviceDeltaDatabase.jsonl"
        cd $fileDownloadPrcoessPath
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
	
				if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  gsmaDeltaFileBlankMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;  
     select value from app.msg_cfg where tag='gsmaDeltaFileBlank';
EOF
`
	    gsmaCompareFileEmptyMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF; 
     select value from app.msg_cfg where tag='gsmaCompareFileEmpty';
EOF
`
   `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='200',status='$gsmaDeltaFileBlankMsg',error_message='',feature_name='GSMA Download Database',info='$gsmaCompareFileEmptyMsg',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0',modified_on=SYSTIMESTAMP where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`	
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
		gsmaDeltaFileBlankMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaDeltaFileBlank'")
	 gsmaCompareFileEmptyMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaCompareFileEmpty'")
		mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set status_code='200',status='$gsmaDeltaFileBlankMsg',error_message='',feature_name='GSMA Download Database',info='$gsmaCompareFileEmptyMsg',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL
fi	

	
exit
fi

#8 start java process
if [ ! -e "$fileProcessModulePath" ]; 
		then
		echo "$(date +%F_%H-%M-%S) : $fileProcessModulePath  not exists. process term -finated"
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		
				if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	  gsmaFileProcessPathNotFoundMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF; 
     select value from app.msg_cfg where tag='gsmaFileProcessPathNotFound';
EOF
`
   `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessPathNotFoundMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0',modified_on=SYSTIMESTAMP where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`	
curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1005\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1005"
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
		gsmaFileProcessPathNotFoundMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileProcessPathNotFound'")
		mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessPathNotFoundMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL
		curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1005\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1005"
fi	


		
exit 3;
fi

if [ ! -e "$processLogFile" ]; 
		then
		echo "$(date +%F_%H-%M-%S) : $processLogFile log path  not exists. process term -finated"
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		

				if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
    gsmaFileProcessLogPathNotFoundMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
    select value from app.msg_cfg where tag='gsmaFileProcessLogPathNotFond';
EOF
`
   `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessLogPathNotFoundMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0',modified_on=SYSTIMESTAMP where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`	
 curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1006\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1006"
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
		 gsmaFileProcessLogPathNotFoundMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileProcessLogPathNotFond'")
	mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessLogPathNotFoundMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL

		curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1006\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1006"
fi	
exit 3; 
fi

cd $fileProcessModulePath
java -Dlog4j.configuration=file:./log4j.properties -jar GsmaTacUpdate-0.1.jar -Dspring.config.location=:./conf.properties  1> $processLogFile/GSMAFileProcessLOG_$(date +%Y%m%d).log		

#9 Check java process status in modules_audit_trail table  & Move processed DeviceDatabase.jsonl_yyyymmdd to backup folder and update latest DeviceDatabase.jsonl_ProcessedFile if status is 200 (success)

cd $fileDownloadPrcoessPath 

				if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
	 echo "$(date +'%d-%m-%Y')--"
  fileProcessUtiltyStatusCode=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;
    select status_code from aud.modules_audit_trail where  to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and feature_name IN ('GSMA Data Processor')  and status_code=200;
EOF
`
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
	fileProcessUtiltyStatusCode=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select status_code from aud.modules_audit_trail where created_on LIKE '%$(date +%F)%' and feature_name IN ('GSMA Data Processor')  and status_code=200");
fi
echo "$(date +%F_%H-%M-%S) : fileProcessUtiltyStatusCode  = $fileProcessUtiltyStatusCode";
if [ $fileProcessUtiltyStatusCode -eq 200 ];
		then
			rm -f DeviceDatabase.jsonl_ProcessedFile
			cp 	DeviceDatabase.jsonl DeviceDatabase.jsonl_ProcessedFile
		echo "going to call Copy API"
		curl -X POST "$fileCpyAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"appName\": \"string\", \"destination\": [ { \"destFilePath\": \"$fileDownloadPrcoessPath\", \"destServerName\": \"$destServerName\" } ], \"remarks\": \"string\", \"serverName\": \"$serverName\", \"sourceFileName\": \"DeviceDatabase.jsonl_ProcessedFile\", \"sourceFilePath\": \"$fileDownloadPrcoessPath\", \"sourceServerName\": \"string\", \"txnId\": \"string\"}"
		
			echo "$(date +%F_%H-%M-%S) : Copied file DeviceDatabase.jsonl to DeviceDatabase.jsonl_ProcessedFile "
			mv  DeviceDatabase.jsonl $fileBackupPath/DeviceDatabase.jsonl_$(date +%Y%m%d)
			gzip $fileBackupPath/DeviceDatabase.jsonl_$(date +%Y%m%d)
			mv  DeviceDeltaDatabase.jsonl $deltaFileBackupPath/DeviceDeltaDatabase.jsonl_$(date +%Y%m%d)
			cd $deltaFileBackupPath
			gzip $deltaFileBackupPath/DeviceDeltaDatabase.jsonl_$(date +%Y%m%d)
			echo "$(date +%F_%H-%M-%S) : Moved file DeviceDatabase.jsonl to $fileBackupPath folder and moved file DeviceDeltaDatabase.jsonl to $deltaFileBackupPath folder ";
			cd $fileDownloadPrcoessPath
			rm -f  DeviceDatabase.zip
			
else 
		echo "$(date +%F_%H-%M-%S) : 200 status  not found , File process utility not complete successfully. "
		executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
		
						if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"

	   
	    gsmaFileProcessNotCompleteMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
     set heading OFF;
    select value from app.msg_cfg where tag='gsmaFileProcessNotComplete';
EOF
`
	   
	   `sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessNotCompleteMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='0' ,modified_on=SYSTIMESTAMP where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database'  and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`
 curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1007\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1007"

	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
	 gsmaFileProcessNotCompleteMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileProcessNotComplete'")
 		mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
	
		update aud.modules_audit_trail set status_code='501',status='FAIL',error_message='$gsmaFileProcessNotCompleteMsg',feature_name='GSMA Download Database',info='NA',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='0' ,modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
EOFMYSQL
curl -X POST "$alertAPIURL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"alertId\": \"alert1007\", \"alertMessage\": \"\", \"alertProcess\": \"\", \"description\": \"string\", \"featureName\": \"\", \"ip\": \"string\", \"priority\": \"string\", \"remarks\": \"string\", \"serverName\": \"$serverName\", \"status\": 0, \"txnId\": \"string\", \"userId\": 0}"
	   echo "alertId =alert1007"
fi
echo "$(date +%F_%H-%M-%S) : alertMessage=$alertMessage , alertId=$alertMessage"
exit 1
fi

#10 sucess entry in audit table 
	executionFinishTime=$(date +%s.%N);
		ExecutionTime=$(echo "$executionFinishTime - $executionstartTime" | bc)
		secondDivision=1000
		finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
				
        
							if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
 updatedCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select count(*) from gsma_tac_details where   to_char(modified_on,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and action='update';
EOF
`
	   
	    insertCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select count(*) from gsma_tac_details where   to_char(modified_on,'DD-MM-YYYY')='$(date +'%d-%m-%Y')' and action='insert'
EOF
`
	   
	    totalCount=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF;
    select count(*) from gsma_tac_details;
EOF
`
	    failure_count=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select failure_count from aud.modules_audit_trail where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' and ROWNUM <=1 order by id desc
EOF
`

 gsmaFileDownloadCompletedMsg=`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
      set heading OFF; 
   select value from app.msg_cfg where tag='gsmaFileDownloadCompleted';
EOF
`

	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
	updatedCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_details where  modified_on LIKE '%$(date +%F)%' and action='update'");
		insertCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_details where  modified_on LIKE '%$(date +%F)%' and action='insert'");
		totalCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select count(*) from gsma_tac_details");
		failure_count=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbDecryptPassword} -se "select failure_count from aud.modules_audit_trail where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1");
		gsmaFileDownloadCompletedMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbDecryptPassword} -se "select value from app.msg_cfg where tag='gsmaFileDownloadCompleted'");
fi
		
		
		#failure_count=wc -l < /u02/eirsdata/GSMAMODULE/ErrorFile/errorFile.txt_$(date +%F);
		echo "$(date +%F_%H-%M-%S) : total number of record failed=$failure_count"
		echo "$(date +%F_%H-%M-%S) : total number of record updated=$updatedCount"
		echo "$(date +%F_%H-%M-%S) : total number of record inserted=$insertCount"
		echo "$(date +%F_%H-%M-%S) : total number of record =$totalCount"
		
		
		
		if [ $databaseFlag == "Oracle" ]
then
     echo "Oracle block"
`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update  aud.modules_audit_trail set status_code='200',status='$gsmaFileDownloadCompletedMsg',error_message='NA',feature_name='GSMA Download Database',info='',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC - Download Manager' ,count2='0', failure_count='$failure_count' ,modified_on=SYSTIMESTAMP  where module_name='GSMA TAC - Download Manager' and feature_name='GSMA Download Database' and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`

`sqlplus -s ${dbUsername}/${dbDecryptPassword}@//${dbIp}:${dbPort}/${dbServiceOrcl} << EOF
    SET AUTOCOMMIT ON 
		update aud.modules_audit_trail set info='DeviceDatabase.jsonl_$(date +%Y%m%d)' where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Data Processor'   and to_char(CREATED_ON,'DD-MM-YYYY')='$(date +'%d-%m-%Y')';
  commit;
EOF
`
	 elif [ $databaseFlag == "Mysql" ]
then
	 echo "Mysql block"
	mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbDecryptPassword} $auddbName <<EOFMYSQL
		
		update  aud.modules_audit_trail set status_code='200',status='$gsmaFileDownloadCompletedMsg',error_message='NA',feature_name='GSMA Download Database',info='',count='$totalGSMATACcount',action='Download',server_name='$serverName',execution_time='$finalExecutionTime',module_name='GSMA TAC – Download Manager' ,count2='0', failure_count='$failure_count' ,modified_on=CURRENT_TIMESTAMP where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Download Database' order by id desc limit 1;
		
		update aud.modules_audit_trail set info='DeviceDatabase.jsonl_$(date +%Y%m%d)' where module_name='GSMA TAC – Download Manager' and feature_name='GSMA Data Processor' order by id desc limit 1;
		
EOFMYSQL
fi

echo "$(date +%F_%H-%M-%S) : File download proccess completed successfully."
exit 0;

