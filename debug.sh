docker system prune -a --volumes -f
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -aq)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q)
sudo rm -rf forgejo/
clear
echo "All Docker containers, images, volumes, and networks have been removed."