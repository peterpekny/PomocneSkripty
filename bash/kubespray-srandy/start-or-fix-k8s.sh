#!/bin/bash
# NÁZOV: fix_k8s_start.sh
# ÚČEL: Zotavenie Kubernetes clusteru po nečistom reštarte pomocou Kubespray scale.yml

KUBESPRAY_DIR="$HOME/kubespray"
INVENTORY_FILE="$KUBESPRAY_DIR/inventory/my-k8s-cluster/inventory.ini"
KUBECONFIG_PATH="$HOME/.kube/config"

echo "--- START: Kontrola a zotavenie Kubernetes ---"

# 1. Kontrola aktívneho venv a navigacia
if [ -d "$KUBESPRAY_DIR/venv" ]; then
    source "$KUBESPRAY_DIR/venv/bin/activate"
    echo "1.1: Virtuálne prostredie (venv) aktivované."
else
    echo "CHYBA: Virtuálne prostredie nenájdené. Uistite sa, že ste v správnom adresári."
    exit 1
fi

# 2. Kontrola stavu
echo "2.1: Cakanie 60 sekund na spustenie Kubeletov a Control Plane..."
sleep 60

echo "2.2: Overenie stavu uzlov."
export KUBECONFIG="$KUBECONFIG_PATH"
# Kontrola, ci je niektory uzol "NotReady"
if kubectl get nodes 2>/dev/null | grep -q "NotReady"; then
    echo "--- ZISTENY PROBLEM: Niektory uzol je 'NotReady'. Spustam zotavenie. ---"
    REPAIR_NEEDED=true
else
    echo "--- VSETKO JE OK: Vsetky uzly su 'Ready'. Zotavenie nie je nutne. ---"
    REPAIR_NEEDED=false
fi

# 3. Zotavenie, ak je potrebné
if [ "$REPAIR_NEEDED" = true ]; then
    echo "3.1: Spustenie playbooku scale.yml na opravu Control Plane a CNI."
    ansible-playbook -i "$INVENTORY_FILE" --become --become-user=root scale.yml

    echo "3.2: Finalna kontrola stavu."
    sleep 30
    kubectl get nodes
fi

# 4. Ukoncenie
deactivate
echo "--- KONIEC: Proces ukonceny. ---"
