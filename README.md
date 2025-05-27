# SSL Certificate Analyzer 🔐

A Bash script that fetches and analyzes SSL certificates for multiple domains.

✨ Features:
- Fancy CLI using figlet/lolcat
- Supports multiple domain inputs
- Outputs to both CSV and HTML reports
- Detects DV / OV / EV types
- Shows full certificate chain (Root / Intermediate / Leaf)
- Expiration warning if < 30 days

## Usage

```bash
chmod +x ssl_cert_report_fancy.sh
./ssl_cert_report_fancy.sh

Enter domain names one-by-one when prompted. Results saved in:
- `ssl_report.csv`
- `ssl_report.html`

Happy Hacking 💻🔍

