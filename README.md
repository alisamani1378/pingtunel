# اسکریپت نصب خودکار PingTunnel

این مخزن شامل اسکریپت و فایل‌های لازم برای راه‌اندازی سریع و هوشمند تانل ICMP با استفاده از PingTunnel است. این سیستم برای ایجاد ارتباط بین سرورهای داخل و خارج از ایران طراحی شده و مشکل فیلترینگ گیت‌هاب برای سرورهای داخلی را با استفاده از یک سرور آینه حل می‌کند.

---

## معماری و روش کار

- **منبع اصلی (گیت‌هاب):** این مخزن به عنوان منبع اصلی فایل‌های `setup.sh` و `pingtunnel` عمل می‌کند.
- **سرورهای خارج:** به صورت مستقیم از گیت‌هاب فایل‌ها را دانلود و نصب می‌کنند.
- **سرور آینه (در ایران):** یکی از سرورهای ایران شما نقش یک "آینه" یا "کش" را بازی می‌کند تا فایل‌ها را به دیگر سرورهای ایرانی سرویس دهد.
- **سرورهای داخل:** به جای گیت‌هاب، به سرور آینه شما متصل شده و فرآیند نصب را از آنجا انجام می‌دهند.

---

## ۱. پیش‌نیازها و آماده‌سازی

قبل از استفاده از دستورات نصب، مراحل زیر **باید** انجام شوند:

### ۱.۱. قرار دادن فایل‌ها در گیت‌هاب
مطمئن شوید که دو فایل زیر در همین مخزن گیت‌هاب شما (`alisamani1378/pingtunel`) آپلود شده‌اند:
- **`pingtunnel`**: فایل باینری کامپایل‌شده‌ی PingTunnel برای معماری لینوکس (معمولاً amd64).
- **`setup.sh`**: اسکریپت نصب هوشمند که کد آن در انتهای همین راهنما موجود است.

### ۱.۲. راه‌اندازی سرور آینه در ایران (مرحله کلیدی)
روی **یکی** از سرورهای داخل ایران خود، مراحل زیر را برای ساخت یک وب‌سرور ساده جهت میزبانی فایل‌ها انجام دهید:

1.  فایل‌های `pingtunnel` و `setup.sh` را از همین گیت‌هاب دانلود کرده و در یک پوشه قرار دهید:
    ```sh
    mkdir /root/mirror-files
    cd /root/mirror-files
    # فایل‌ها را در این پوشه قرار دهید
    ```

2.  در همین پوشه (`/root/mirror-files`)، یک وب‌سرور ساده پایتون را برای میزبانی فایل‌ها روی پورت `8000` اجرا کنید:
    ```sh
    #
    python3 -m http.server 8000 &
    ```

3.  فایروال را برای دسترسی به این وب‌سرور باز کنید:
    ```sh
    sudo ufw allow 8000/tcp
    ```
**تمام!** سرور آینه شما آماده است تا به دیگر سرورهای ایرانی سرویس‌دهی کند.

---

## ۲. دستورات نصب

کافیست دستور مربوط به موقعیت سرور خود را کپی و در ترمینال اجرا کنید.

### ۲.۱. برای سرورهای خارج از ایران
این دستور فایل‌ها را مستقیماً از مخزن گیت‌هاب شما دانلود و اجرا می‌کند:
```bash
bash <(curl -Ls [https://raw.githubusercontent.com/alisamani1378/pingtunel/main/setup.sh](https://raw.githubusercontent.com/alisamani1378/pingtunel/main/setup.sh)) [https://raw.githubusercontent.com/alisamani1378/pingtunel/main](https://raw.githubusercontent.com/alisamani1378/pingtunel/main)
```

### ۲.۲. برای سرورهای داخل ایران
این دستور فایل‌ها را از **سرور آینه ایرانی** که در مرحله قبل ساختید، دانلود و اجرا می‌کند:
```bash
bash <(curl -Ls http://<IRAN_MIRROR_IP>:8000/setup.sh) http://<IRAN_MIRROR_IP>:8000
```
**نکته مهم:** به جای `<IRAN_MIRROR_IP>` آی‌پی عمومی سرور آینه خود در ایران را قرار دهید.

---

## ۳. راهنمای پس از اجرا

پس از اجرای دستور نصب، اسکریپت به صورت تعاملی شما را راهنمایی می‌کند:

1.  یک منو نمایش داده می‌شود که باید نوع نصب را انتخاب کنید:
    - **گزینه `1` (سرور خارج):** برای نصب PingTunnel به عنوان سرور مرکزی. این گزینه نیازی به ورودی دیگری ندارد.
    - **گزینه `2` (کلاینت ایران):** برای نصب PingTunnel به عنوان کلاینت.

2.  اگر گزینه `2` را انتخاب کنید، اسکریپت:
    - از شما آی‌پی سرور خارج را می‌پرسد.
    - اتصال به آن آی‌پی را با `ping` تست می‌کند.
    - در صورت موفقیت، از شما پورت لوکال برای اتصال را می‌پرسد.
    - در نهایت سرویس را تنظیم و اجرا می‌کند.

---
<details>
<summary>
<b>کد اسکریپت setup.sh (برای مشاهده کلیک کنید)</b>
</summary>

```bash
#!/bin/bash

# --- Step 1: Argument and Prerequisite Checks ---

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with root privileges or using sudo."
  exit 1
fi

# Check if a Base URL was provided as an argument
if [ -z "$1" ]; then
  echo "ERROR: A base URL for downloading files must be provided as the first argument."
  echo "Usage: bash <(curl...) <http://your-base-url>"
  exit 1
fi

BASE_URL="$1"

# --- Step 2: Download the necessary binary ---

echo "Downloading the 'pingtunnel' binary from <span class="math-inline">\{BASE\_URL\}/pingtunnel\.\.\."
\# Create a temporary directory for the download
mkdir \-p /tmp/pt\_setup
cd /tmp/pt\_setup
\# Use curl to download\. Exit if it fails\.
if \! curl \-Lso pingtunnel "</span>{BASE_URL}/pingtunnel"; then
    echo "FATAL: Failed to download 'pingtunnel' from the source. Please check the URL and your network."
    exit 1
fi
echo "Download successful."

chmod +x ./pingtunnel
mv ./pingtunnel /root/pingtunnel
echo "Moved 'pingtunnel' binary to /root/pingtunnel"

# --- Step 3: Interactive Setup with a Numbered Menu ---

echo ""
echo "لطفا نوع نصب را انتخاب کنید:"
echo "   1) راه اندازی به عنوان سرور خارج (Server / Kharej)"
echo "   2) راه اندازی به عنوان کلاینت ایران (Client / Iran)"
echo ""
read -p "عدد مورد نظر را وارد کنید [1-2]: " choice

case "$choice" in
    1)
        # --- Server Setup Logic ---
        echo "Configuring as PingTunnel Server..."
        cat > /etc/systemd/system/pingtunnel-server.service << EOL
[Unit]
Description=Pingtunnel Server Service
After=network.target

[Service]
ExecStart=/root/pingtunnel -type server -key Alis1378
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOL
        echo "Server service file created."
        systemctl daemon-reload
        systemctl enable pingtunnel-server
        systemctl start pingtunnel-server
        echo "PingTunnel server service has been started and enabled."
        echo "To check the status, run: systemctl status pingtunnel-server"
        ;;

    2)
        # --- Client Setup Logic with PING CHECK ---
        echo "Configuring as PingTunnel Client..."
        read -p "Enter the public IP of your OUTSIDE server: " SERVER_IP

        # --- PING CHECK ---
        echo ""
        echo "--> Testing connectivity to ${SERVER_IP} with 4 pings..."
        if ping -c 4 -W 5 ${SERVER_IP}; then
            echo "--> Ping successful. Proceeding with installation..."
            echo ""
        else
            echo ""
            echo "--> FATAL: Could not ping the server at ${SERVER_IP}."
            echo "--> Please check the IP address, network connectivity, and firewalls, then try again."
            rm -rf /tmp/pt_setup
            exit 1
        fi
        # --- END OF PING CHECK ---
        
        read -p "Enter a local port for this client to listen on (e.g., 5688): " LOCAL_PORT
        if [ -z "<span class="math-inline">LOCAL\_PORT" \]; then
echo "Error\: Local port was not entered\. Aborting\."
exit 1
fi
cat \> /etc/systemd/system/pingtunnel\-client\.service << EOL
\[Unit\]
Description\=Pingtunnel Client Service
After\=network\.target
\[Service\]
ExecStart\=/root/pingtunnel \-type client \-l \:</span>{LOCAL_PORT} -s ${SERVER_IP} -t <span class="math-inline">\{SERVER\_IP\}\:443 \-tcp 1 \-key Alis1378
Restart\=always
RestartSec\=5
User\=root
\[Install\]
WantedBy\=multi\-user\.target
EOL
echo "Client service file created\."
systemctl daemon\-reload
systemctl enable pingtunnel\-client
systemctl start pingtunnel\-client
echo "PingTunnel client service has been started and enabled\."
echo "To use, set your application's SOCKS5 proxy to\: 127\.0\.0\.1\:</span>{LOCAL_PORT}"
        echo "To check the status, run: systemctl status pingtunnel-client"
        ;;

    *)
        # --- Invalid Input ---
        echo "ورودی نامعتبر است. لطفا اسکریپت را مجددا اجرا کرده و عدد 1 یا 2 را وارد کنید."
        rm -rf /tmp/pt_setup
        exit 1
        ;;
esac

# Cleanup temporary files
rm -rf /tmp/pt_setup
echo "Setup finished and temporary files removed."
```
</details>
