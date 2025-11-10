#!/bin/bash
# NÁZOV: deploy_k8s.sh
# ÚČEL: Automatizácia inštalácie Kubernetes clusteru (1 Master, 3 Worker) pomocou Kubespray.

# --- KONFIGURÁCIA ---
K8S_IPS=("10.0.0.161" "10.0.0.162" "10.0.0.163" "10.0.0.164")
ANSIBLE_USER="ubuntu"  # Tvoj SSH uzivatel na vzdialenych VM
KUBESPRAY_DIR="kubespray"
INVENTORY_NAME="my-k8s-cluster"

echo "--- START: Automatizovane nasadenie Kubernetes ---"

# 1. INSTALACIA A PRIPRAVA ZÁKLADNÝCH NÁSTROJOV
echo "1.1: Instalacia Git a Python3 Venv."
sudo apt update
sudo apt install -y git python3-pip python3-venv

echo "1.2: Generovanie SSH kľúča (ak neexistuje)."
# Skontroluje a vygeneruje kľúč len ak neexistuje
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
    echo "SSH kľúč vygenerovaný."
fi

echo "--- DÔLEŽITÉ PRERUŠENIE: PREREQUISITES ---"
echo "Prosím, vykonaj nasledujúce KROKY RUČNE (pre VŠETKY 4 VM):"
echo "A. Skopíruj verejný kľúč na všetky VM:"
for ip in "${K8S_IPS[@]}"; do
    echo "   ssh-copy-id ${ANSIBLE_USER}@${ip}"
done
echo "B. Nastav sudo bez hesla (NOPASSWD) na všetkých VM pre užívateľa ${ANSIBLE_USER} (cez 'sudo visudo')."
echo "example: run command on remote VM : sudo visudo"
echo "add record: ${ANSIBLE_USER} ALL=(ALL) NOPASSWD: ALL"
echo "Stlačte [ENTER] pre pokračovanie po dokončení ručných krokov."
read -r


# 2. PRIPRAVA KUBESPRAY
echo "2.1: Klonovanie Kubespray (ak ešte neexistuje)."
if [ ! -d "$KUBESPRAY_DIR" ]; then
    git clone https://github.com/kubernetes-sigs/kubespray.git
else
    echo "Kubespray adresár už existuje, preskakujem klonovanie."
fi
cd "$KUBESPRAY_DIR" || exit

echo "2.2: Vytvorenie a aktivácia Virtuálneho Prostredia (venv)."
python3 -m venv venv
source venv/bin/activate

echo "2.3: Instalacia Kubespray Python závislostí."
pip install -r requirements.txt

# 3. PRIPRAVA INVENTÁRA
echo "3.1: Vytvorenie vlastného inventára a kopírovanie súborov."
cp -r inventory/sample "inventory/$INVENTORY_NAME"

echo "3.2: Ručná editácia inventory.ini pre 1 Master / 3 Worker topológiu."
INVENTORY_FILE="inventory/${INVENTORY_NAME}/inventory.ini"

# Zápis obsahu INI inventára
cat << EOF > "$INVENTORY_FILE"
[kube_control_plane]
node1 ansible_host=${K8S_IPS[0]}

[etcd:children]
kube_control_plane

[kube_node]
node1 ansible_host=${K8S_IPS[0]}
node2 ansible_host=${K8S_IPS[1]}
node3 ansible_host=${K8S_IPS[2]}
node4 ansible_host=${K8S_IPS[3]}
EOF
echo "Inventár $INVENTORY_FILE bol upravený."

echo "3.3: Konfigurácia Ansible užívateľa v group_vars."
GROUP_VARS_FILE="inventory/${INVENTORY_NAME}/group_vars/all/all.yml"
# Zabezpecenie, ze all.yml existuje, ak ho Kubespray pri kopii neobsahoval
touch "$GROUP_VARS_FILE"
echo "ansible_user: \"$ANSIBLE_USER\"" >> "$GROUP_VARS_FILE"

# 4. PREREQUISITY NA NODEOCH (PING FIX + ZÁKLADNÉ NÁSTROJE)
echo "4.1: Spustenie playbooku pre instalaciu chybajucich nastrojov (ping, net-tools, curl, vim atd.)."
cat << EOF > fix_tools.yml
---
- hosts: kube_node
  become: yes
  tasks:
    - name: Ensure common utility and network tools are installed (ping fix)
      ansible.builtin.apt:
        name:
          - iputils-ping
          - net-tools
          - tcpdump
          - dnsutils
          - curl
          - wget
          - vim
          - nano
        state: present
        update_cache: yes
EOF

ansible-playbook -i "$INVENTORY_FILE" --become --become-user=root fix_tools.yml

# 5. SPUSTENIE HLAVNEJ INŠTALÁCIE
echo "5.1: Spustenie hlavnej Kubespray instalacie (cluster.yml). TOTO BUDE TRVAŤ 10-20 MINÚT!"
ansible-playbook -i "$INVENTORY_FILE" --become --become-user=root cluster.yml

# 6. DOKONČENIE A POKYNY
echo "--- NASADENIE DOKONČENÉ ---"

echo "6.1: Skopírovanie kubeconfig súboru na prístup z tohto servera."
MASTER_IP="${K8S_IPS[0]}"
KUBECONFIG_PATH="$HOME/.kube/config"

mkdir -p "$HOME/.kube"
scp ${ANSIBLE_USER}@${MASTER_IP}:/home/${ANSIBLE_USER}/.kube/config "$KUBECONFIG_PATH"

echo "6.2: Finalizácia a Overenie."
echo "Kubernetes cluster bol nainštalovaný."
echo "Pre prístup k clusteru použi:"
echo "export KUBECONFIG=$KUBECONFIG_PATH"
echo "kubectl get nodes"

echo "Nezabudni: Kedykoľvek skončíš, použi príkaz 'deactivate' na opustenie (venv)."
