#!/bin/sh

declare -A controller_map=(["controller01"]="192.168.2.11" ["controller02"]="192.168.2.12" ["controller03"]="192.168.2.13" );

controller_name=(${!controller_map[@]});
controller_list_space=${!controller_map[@]};


sh_name=galera_exec.sh
source_sh=$(echo `pwd`)/sh/$sh_name
target_sh=/root/tools/t_sh/

virtual_ip=192.168.2.201
local_nic='eno16777736'

source_cfg=$(echo `pwd`)/sh/conf/haproxy.cfg.base
target_cfg=$(echo `pwd`)/sh/conf/haproxy.cfg.galera

##### generate haproxy.cfg
cp $source_cfg $target_cfg
echo "listen galera_cluster" >>$target_cfg
echo "    bind $virtual_ip:3306" >>$target_cfg
echo "    balance source" >>$target_cfg
echo "    option mysql-check user haproxy_check" >>$target_cfg
for ((i=0; i<${#controller_map[@]}; i+=1));
  do
        name=${controller_name[$i]};
        ip=${controller_map[$name]};
        echo "-------------$name------------"
        if [ $i -eq 0 ]; then
                   echo $i
           echo "    server $name $ip:3306 inter 2000 rise 2 fall 5" >>$target_cfg
       else
           echo "    server $name $ip:3306 backup inter 2000 rise 2 fall 5" >>$target_cfg
       fi
  done;
##### scp 
for ((i=0; i<${#controller_map[@]}; i+=1));
  do
	name=${controller_name[$i]};
	ip=${controller_map[$name]};
	echo "-------------$name------------"
	scp $target_cfg root@$ip:/etc/haproxy/haproxy.cfg
	ssh root@$ip mkdir -p $target_sh
        scp $source_sh root@$ip:$target_sh
        ssh root@$ip chmod -R +x $target_sh
        ssh root@$ip $target_sh/$sh_name $local_nic
  done;

#### controller01
galera_new_cluster

#### config galera

for ((i=0; i<${#controller_map[@]}; i+=1));
  do
        name=${controller_name[$i]};
        ip=${controller_map[$name]};
        echo "-------------$name------------"
        if [ $i -eq 0 ]; then
          mysql_secure_installation
       else
         ssh root@$ip systemctl start mariadb
         #ssh root@$ip mysql_secure_installation 
       fi
  done;
#### check 
mysql -uroot -p123456 -e "use mysql;INSERT INTO user(Host, User) VALUES('"$virtual_ip"', 'haproxy_check');FLUSH PRIVILEGES;"
mysql -uroot -p -h $virtual_ip -e "SHOW STATUS LIKE 'wsrep_cluster_size';"