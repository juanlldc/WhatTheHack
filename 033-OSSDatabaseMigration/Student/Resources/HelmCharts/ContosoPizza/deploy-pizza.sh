status="Running"

# Install the Kubernetes Resources
helm upgrade --install wth-mysql ../MySQL57 --set infrastructure.password=OCPHack8

# Install the Kubernetes Resources
helm upgrade --install wth-postgresql ../PostgreSQL116 --set infrastructure.password=OCPHack8

for ((i = 0 ; i < 30 ; i++)); do
    pgStatus=$(kubectl -n postgresql get pods --no-headers -o custom-columns=":status.phase")


    if [ "$pgStatus" != "$status" ]; then
        sleep 10
    else   
        break
    fi
done

# Get the postgres pod name
pgPodName=$(kubectl -n postgresql get pods --no-headers -o custom-columns=":metadata.name")

#Copy pg.sql to the postgresql pod
kubectl -n postgresql cp ./pg.sql $pgPodName:/tmp/pg.sql

# Use this to connect to the database server
kubectl -n postgresql exec deploy/postgres -it -- /usr/bin/psql -U postgres -f /tmp/pg.sql

while ! kubectl -n mysql exec deploy/mysql -it -- /usr/bin/mysqladmin --user=root --password=OCPHack8 ping --silent &> /dev/null ; do
    echo "Waiting for MySQL to be ready"
    sleep 2
done

# Use this to connect to the database server
while ! kubectl -n mysql exec deploy/mysql -it -- /usr/bin/mysql -u root -pOCPHack8 <./mysql.sql &> /dev/null ; do
    echo "Waiting to be able to login to MySQL"
    sleep 2
done 

postgresClusterIP=$(kubectl -n postgresql get svc -o jsonpath="{.items[0].spec.clusterIP}")
mysqlClusterIP=$(kubectl -n mysql get svc -o jsonpath="{.items[0].spec.clusterIP}")

sed "s/XXX.XXX.XXX.XXX/$postgresClusterIP/" ./values-postgresql-orig.yaml >temp_postgresql.yaml && mv temp_postgresql.yaml ./values-postgresql.yaml
sed "s/XXX.XXX.XXX.XXX/$mysqlClusterIP/" ./values-mysql-orig.yaml >temp_mysql.yaml && mv temp_mysql.yaml ./values-mysql.yaml

helm upgrade --install mysql-contosopizza . -f ./values.yaml -f ./values-mysql.yaml 

helm upgrade --install postgres-contosopizza . -f ./values.yaml -f ./values-postgresql.yaml

for ((i = 0 ; i < 30 ; i++)); do
    appStatus=$(kubectl -n contosoappmysql get svc -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
    if [[ $appStatus =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo $appStatus
        break
    else
        echo "Waiting for load balancer IP address for contosoappmysql"
        sleep 30
    fi
done

for ((i = 0 ; i < 30 ; i++)); do
    appStatus=$(kubectl -n contosoapppostgres get svc -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
    if [[ $appStatus =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo $appStatus
        break
    else
        echo "Waiting for load balancer IP address for contosoapppostgres"
        sleep 30
    fi
done

postgresAppIP=$(kubectl -n contosoapppostgres get svc -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
mysqlAppIP=$(kubectl -n contosoappmysql get svc -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")

echo "Pizzeria app on MySQL is ready at http://$mysqlAppIP:8081/pizzeria"
echo "Pizzeria app on PostgreSQL is ready at http://$postgresAppIP:8082/pizzeria"
