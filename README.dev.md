Singularity is far from stable yet. If you get it to bad state and it keeps quiting on start it is necessary to remove invalid data in zookeeper.

`
/usr/share/zookeeper/bin/zkCli.sh
[zk: localhost:2181(CONNECTED) 0] rmr /singularity
[zk: localhost:2181(CONNECTED) 0] quit
`