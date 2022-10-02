
cd $HOME/istio-insider-en

git add . && git commit -m "bak" && git push home54

ssh pi@192.168.1.54 << 'EOF'
cd /home/pi/GIT/istio-insider-en.git
git push --set-upstream github main
EOF