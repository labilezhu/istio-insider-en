cp -r -l /home/labile/istio-insider/docs/source/* /home/labile/istio-insider-en/docs/source/

find `pwd` -name "*.md"  > /home/labile/istio-insider-en/docs/source/o.sh

## Replace o.sh:
# /home/labile/istio-insider/docs/source/(.+) -> rm /home/labile/istio-insider-en/docs/source/$1;cp $0 /home/labile/istio-insider-en/docs/source/$1