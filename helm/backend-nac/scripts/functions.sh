#!/bin/bash

function cmd_nacsite()
{	
	DPL_NAME_LIST=$($KUBECTL get deployments -A | grep -E " (nac|nac6)-(.*)" | grep -v "\-dkns" | awk '{print $1 ":" $2}')
	printf "SiteName         Total Nodes    Active Devices    Total Sensors    Active Sensors   Public IP        Last Login\n"
	for ITEM in ${DPL_NAME_LIST} ; do
		NS=$(echo $ITEM | awk -F':' '{print $1}')
		DPL_NAME=$(echo $ITEM | awk -F':' '{print $2}')
		SITENAME=${DPL_NAME#*-}
		PODNAME=$($KUBECTL get pod -l tenant=${DPL_NAME#*-} -n $NS -o jsonpath="{.items[0].metadata.name}")
		[ $? != 0 ] && continue
		SDATA=$($KUBECTL exec $PODNAME -n $NS -- bash -c 'export MYSQL_PWD=$(cat /disk/.dbpass); \
			mysql -A -h $DB_HOST -u $DB_USER $DB_NAME -B --disable-column-names -e "SELECT \
				(SELECT COUNT(*) FROM NODELIST), \
				(SELECT CONCAT(COUNT(*), \" \", IFNULL(SUM(NL_ACTIVE), 0)) FROM NODELIST WHERE NL_GENIDEV=2), \
				(SELECT COUNT(DISTINCT(NL_DEVID)) AS CNT FROM vwDEVLIST_VALID WHERE NL_ACTIVE=1 AND DL_TYPE=0), \
				(SELECT ADM_LASTLOGIN AS LASTLOGIN FROM ADMIN WHERE ADM_ROLEID != \"operator\" ORDER BY ADM_LASTLOGIN DESC LIMIT 1) \
			"' 2> /dev/null)
		PUBLIC_IP=$($KUBECTL exec -n $NS $PODNAME -- bash -c 'curl -s http://checkip.amazonaws.com' 2> /dev/null)
		NODES=$(echo $SDATA | awk '{print $1}')
		TS=$(echo $SDATA | awk '{print $2}')
		AS=$(echo $SDATA | awk '{print $3}')
		LIC=$(echo $SDATA | awk '{print $4}')
		LLDATE=$(echo $SDATA | awk '{print $5}')
		printf "%-16s %-14d %-17d %-16d %-16d %-16s %-10s\n" $SITENAME $NODES $LIC $TS $AS $PUBLIC_IP $LLDATE
	done
}

function cmd_nacsite-json()
{	
	cmd_nacsite | grep -v "^SiteName" | awk '{print "{ \
			\"sitename\": \"" $1 "\", \
			\"total_nodes\": \"" $2 "\", \
			\"active_devices\": \"" $3 "\", \
			\"total_sensors\": \"" $4 "\", \
			\"active_sensors\": \"" $5 "\", \
			\"public_ip\": \"" $6 "\", \
			\"last_login\": \"" $7 "\" \
		}"}' | jq -s '{"sites": .}'
}

function cmd_nac-cve-manager()
{
	# Elasticsearch 시스템별로 1개의 CVE 관리 tenant를 설정한다.

	declare -A STATLIST
	declare -A DBHOSTLIST
	declare -A DBPASSLIST
	declare -A TARGETLIST
	declare -A CURRENTLIST
	declare -A NSLIST

	DPL_NAME_LIST=$($KUBECTL get deployments -A | grep -E " (nac|nac6)-(.*)" | grep -v "\-dkns" | awk '{print $1 ":" $2}')
	for ITEM in ${DPL_NAME_LIST} ; do
		NS=$(echo $ITEM | awk -F':' '{print $1}')
		DPL_NAME=$(echo $ITEM | awk -F':' '{print $2}')
		PRODUCT=$(echo $DPL_NAME | awk -F'-' '{print $1}')
		SITENAME=${DPL_NAME#*-}

		TCONFIG=$($KUBECTL get configmap -n $NS ${PRODUCT}-${SITENAME}-config -o json 2> /dev/null)
		TENANT_LOG_HOST=$(echo $TCONFIG | jq -r '.data.LOG_HOST' 2> /dev/null)

		[ "${STATLIST[$TENANT_LOG_HOST]}" = "on" ] && continue

		TENANT_DB_HOST=$(echo $TCONFIG | jq -r '.data.DB_HOST' 2> /dev/null)

		if [ "$TENANT_DB_HOST" = "dbserver" ] || [ "$TENANT_DB_HOST" = "dbserver.default" ] ; then
			if [ "$MYSQL_NAC_PASS" = "" ] ; then
				MYSQL_NAC_PASS=$($KUBECTL get secret mysql-nac-pass -o json | jq -r .data.password | base64 -d)
				TENANT_DB_PASS=$MYSQL_NAC_PASS
			fi
		elif [ "$TENANT_DB_HOST" = "dbserver-nac6" ] || [ "$TENANT_DB_HOST" = "dbserver-nac6.default" ] ; then
			if [ "$MYSQL_NAC6_PASS" = "" ] ; then
				MYSQL_NAC6_PASS=$($KUBECTL get secret mysql-nac6-pass -o json | jq -r .data.password | base64 -d)
				TENANT_DB_PASS=$MYSQL_NAC6_PASS
			fi
		else
			echo "ERROR: Unkonwn DB server $TENANT_DB_HOST"
		fi

		STATUS=$(MYSQL_PWD=${TENANT_DB_PASS} mysql -N -h $TENANT_DB_HOST -u root $SITENAME \
					-e "SELECT CONF_VALUE FROM CONF WHERE CONF_CATGRY='Advance' AND CONF_KEY='UPDATEGENIANDATA'")
		if [ $? != 0 ] ; then
			echo "DB connection failed. make sure running in ctlsrv pod"
			return
		fi
		if [ "$STATUS" = "on" ] ; then
			STATLIST[$TENANT_LOG_HOST]=""
			[ "${CURRENTLIST[$TENANT_LOG_HOST]}" != "" ] && CURRENTLIST[$TENANT_LOG_HOST]+=","
			CURRENTLIST[$TENANT_LOG_HOST]+="$SITENAME"
		else
			STATLIST[$TENANT_LOG_HOST]=$SITENAME
			DBHOSTLIST[$TENANT_LOG_HOST]=$TENANT_DB_HOST
			DBPASSLIST[$TENANT_LOG_HOST]=$TENANT_DB_PASS
			NSLIST[$TENANT_LOG_HOST]=$NS
		fi
	done

	for SERVER in "${!STATLIST[@]}" ; do
		if [ "${STATLIST[$SERVER]}" = "" ] ; then
			echo "$SERVER already has CVE manager (${CURRENTLIST[$SERVER]})"
		else
			echo "$SERVER setup CVE manager to (${STATLIST[$SERVER]})"
			MYSQL_PWD=${DBPASSLIST[$SERVER]} mysql -N -h ${DBHOSTLIST[$SERVER]} -u root ${STATLIST[$SERVER]} \
				-e "UPDATE CONF SET CONF_VALUE='on' WHERE CONF_CATGRY='Advance' AND CONF_KEY='UPDATEGENIANDATA'"
			# Send SIGUSR2 to reload CONF cache
			PODNAME=$($KUBECTL get pod -n ${NSLIST[$SERVER]} -l tenant=${STATLIST[$SERVER]} -o jsonpath="{.items[0].metadata.name}")
			$KUBECTL exec -n ${NSLIST[$SERVER]} $PODNAME -- bash -c 'pkill -SIGUSR2 centerd'
		fi
	done
}
