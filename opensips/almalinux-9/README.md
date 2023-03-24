# OpenSIPS Docker Image

**This image is compiled:**  
- with Almalinux 9 (Default docker image)  
- with all opensips modules, except modules that don't have native package in distros based on RedHat 9  
- with opensips-cli  
- with mountpoint in /etc/opensips  
- without entrypoint (You can to be customize your entrypoint)  


**Modules ignored because don't have native support in distros based on RedHat 9**  
- aaa_diameter  
- cachedb_cassandra  
- cachedb_couchbase  
- db_oracle  
- mmgeoip  
- osp  
- sngtc  


**About opensips**  
- /etc/opensips is clean  
- command 'opensips' have /etc/opensips/opensips.cfg as default file  
- Username: opensips / UID: 506  
- Groupname: opensips / GID: 506  
- Directories /etc/opensips and /run/opensips have permission to opensips:opensips and mode 0755  
- Docs in /usr/share/doc/opensips, include a opensips.cfg default  



**More info:**  
https://www.opensips.org  
https://www.almalinux.org  
https://hub.docker.com/r/rodrigovian/opensips  
[https://github.com/rodrigovian/docker-images/opensips/almalinux-9](https://github.com/rodrigovian/docker-images/tree/main/opensips/almalinux-9)  