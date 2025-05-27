#!/bin/bash

# Ensure required tools
for tool in openssl figlet lolcat neofetch; do
    if ! command -v $tool &>/dev/null; then
        echo "❌ $tool not installed. Please install it."
        exit 1
    fi
done

# Fancy CLI Branding
clear
figlet "SSL Scanner" | lolcat
neofetch --off
echo -e "\n🔐 Multi-Domain SSL Certificate Analyzer\n" | lolcat

# Initialize CSV and HTML
CSV_FILE="ssl_report.csv"
HTML_FILE="ssl_report.html"
echo "Domain,Type,Issuer,Subject,Valid From,Valid To,Expires In,Root CA,Intermediate CA(s)" > "$CSV_FILE"

# Start HTML
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html><html><head><title>SSL Report</title>
<style>
body { font-family: Arial; background: #111; color: #eee; }
h1 { color: #0f0; text-align: center; }
table { width: 100%; border-collapse: collapse; margin-top: 20px; }
th, td { border: 1px solid #555; padding: 8px; }
th { background-color: #222; color: #0ff; }
tr:nth-child(even) { background-color: #333; }
tr:hover { background-color: #444; }
</style></head><body>
<h1>SSL Certificate Report</h1><table>
<tr><th>Domain</th><th>Type</th><th>Issuer</th><th>Subject</th><th>Valid From</th><th>Valid To</th><th>Expires In</th><th>Root CA</th><th>Intermediate CA(s)</th></tr>
EOF

while true; do
  echo -n "🌐 Enter a domain to analyze (or type 'done' to finish): "
  read DOMAIN
  [[ "$DOMAIN" == "done" ]] && break
  [[ -z "$DOMAIN" ]] && continue

  echo -e "\n🔎 Analyzing $DOMAIN...\n" | lolcat
  CERT_RAW=$(echo | openssl s_client -servername $DOMAIN -connect ${DOMAIN}:443 2>/dev/null)
  if [[ -z "$CERT_RAW" ]]; then
    echo "❌ Failed to fetch certificate for $DOMAIN"
    continue
  fi

  FULL_CHAIN=$(echo "$CERT_RAW" | openssl x509 -text -noout 2>/dev/null)
  CHAIN=$(echo "$CERT_RAW" | openssl x509 -text -noout -certopt no_header,no_version,no_serial,no_signame,no_validity,no_subject,no_issuer 2>/dev/null)

  # Save cert chain
  ISSUER=$(echo "$CERT_RAW" | openssl x509 -noout -issuer | cut -d'=' -f2-)
  SUBJECT=$(echo "$CERT_RAW" | openssl x509 -noout -subject | cut -d'=' -f2-)
  START=$(echo "$CERT_RAW" | openssl x509 -noout -startdate | cut -d'=' -f2)
  END=$(echo "$CERT_RAW" | openssl x509 -noout -enddate | cut -d'=' -f2)
  START_EPOCH=$(date -d "$START" +%s)
  END_EPOCH=$(date -d "$END" +%s)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))

  # Type detection
  if echo "$SUBJECT" | grep -q "Organization"; then
    if echo "$ISSUER" | grep -qiE 'symantec|digicert|globalsign|entrust'; then
      TYPE="EV"
    else
      TYPE="OV"
    fi
  else
    TYPE="DV"
  fi

  # Warning if expiring
  WARN=""
  [[ "$DAYS_LEFT" -lt 30 ]] && WARN="⚠️"

  # Get root & intermediate CAs
  echo "$CERT_RAW" | awk '/-----BEGIN/,/-----END/' > fullchain.pem
  ROOT_CA=$(openssl x509 -in fullchain.pem -noout -issuer | tail -n1 | cut -d'=' -f2-)
  INTER_CA=$(openssl crl2pkcs7 -nocrl -certfile fullchain.pem | openssl pkcs7 -print_certs -noout | grep 'subject=' | sed 's/subject= //g' | tail -n +2 | paste -sd ";")

  # Save CSV
  echo "$DOMAIN,$TYPE,$ISSUER,$SUBJECT,$START,$END,$DAYS_LEFT $WARN,$ROOT_CA,\"$INTER_CA\"" >> "$CSV_FILE"

  # Save HTML row
  echo "<tr><td>$DOMAIN</td><td>$TYPE</td><td>$ISSUER</td><td>$SUBJECT</td><td>$START</td><td>$END</td><td>$DAYS_LEFT days $WARN</td><td>$ROOT_CA</td><td>${INTER_CA//;/<br>}</td></tr>" >> "$HTML_FILE"

done

# Finalize HTML
echo "</table></body></html>" >> "$HTML_FILE"

echo -e "\n✅ All Done!"
echo -e "📄 CSV saved to: $CSV_FILE"
echo -e "🌐 HTML report saved to: $HTML_FILE\n"

read -p "🖥️ Open HTML report in browser? (y/n): " open_choice
[[ "$open_choice" =~ ^[Yy]$ ]] && xdg-open "$HTML_FILE"

