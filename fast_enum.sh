#!/bin/bash

# Vérifie qu'une adresse IP ou un domaine a été passé en paramètre
if [ -z "$1" ]; then
  echo "Utilisation : $0 <IP ou domaine cible>"
  exit 1
fi

TARGET=$1
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="enum_results_$TARGET_$DATE"
mkdir -p "$OUTPUT_DIR"

echo "Cible : $TARGET"
echo "Dossier de sortie : $OUTPUT_DIR"
echo

# 1. WHOIS - Informations de registre
echo "[*] Récupération des informations WHOIS..."
whois $TARGET > "$OUTPUT_DIR/whois.txt"

# 2. Nmap - Scan des ports (scan rapide)
echo "[*] Scan des ports avec Nmap (Top 1000 ports)..."
nmap -Pn -T4 --top-ports=1000 $TARGET -oN "$OUTPUT_DIR/nmap_top1000.txt"

# 3. Nmap - Scan de tous les ports
echo "[*] Scan de tous les ports ouverts avec Nmap..."
nmap -Pn -T4 -p- $TARGET -oN "$OUTPUT_DIR/nmap_all_ports.txt"

# 4. Nmap - Détection des services et versions
echo "[*] Détection des services et versions des ports ouverts..."
nmap -Pn -T4 -sV -sC -p- $TARGET -oN "$OUTPUT_DIR/nmap_service_version.txt"

# 5. WhatWeb - Analyse des technologies web
echo "[*] Analyse des technologies web avec WhatWeb..."
whatweb -a 3 $TARGET > "$OUTPUT_DIR/whatweb.txt"

# 6. DIG - Récupération des enregistrements DNS
echo "[*] Récupération des enregistrements DNS avec DIG..."
dig $TARGET ANY +noall +answer > "$OUTPUT_DIR/dns_records.txt"

# 7. Nslookup - Recherche de sous-domaines (communs)
echo "[*] Recherche de sous-domaines courants avec Nslookup..."
for sub in www mail ftp ns; do
  nslookup "$sub.$TARGET" >> "$OUTPUT_DIR/subdomains.txt"
done

# 8. Nmap - Scan UDP des ports critiques
echo "[*] Scan UDP pour les services communs (TFTP, DNS, SNMP)..."
sudo nmap -Pn -sU --top-ports=20 $TARGET -oN "$OUTPUT_DIR/nmap_udp_scan.txt"

# 9. Enumération SMB (si le port 445 est ouvert)
if grep -q "445/tcp open" "$OUTPUT_DIR/nmap_all_ports.txt"; then
  echo "[*] Énumération SMB (port 445 ouvert)..."
  smbclient -L //$TARGET -N > "$OUTPUT_DIR/smb_enum.txt" 2>&1
else
  echo "[*] Port 445 (SMB) non détecté comme ouvert, saut de l'énumération SMB."
fi

# 10. Enumération HTTP (si le port 80 ou 443 est ouvert)
if grep -q "80/tcp open" "$OUTPUT_DIR/nmap_all_ports.txt" || grep -q "443/tcp open" "$OUTPUT_DIR/nmap_all_ports.txt"; then
  echo "[*] Énumération HTTP en cours..."
  nikto -h $TARGET > "$OUTPUT_DIR/nikto_scan.txt"
else
  echo "[*] Ports HTTP non détectés comme ouverts, saut de l'énumération HTTP."
fi

echo "Énumération terminée. Résultats stockés dans le dossier $OUTPUT_DIR"
