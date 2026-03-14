#!/bin/bash

echo "--- deb2pisi Kurulum Betiği Başlatılıyor ---"

# 1. Derleme Adımı
echo "[1/3] Proje derleniyor..."
lazbuild deb2pisi.lpi

if [ $? -eq 0 ]; then
    echo "Derleme başarılı."
else
    echo "Hata: Derleme başarısız oldu. Lazarus/FPC kurulu mu?"
    exit 1
fi

# 2. Sisteme Kopyalama
echo "[2/3] Program /usr/bin dizinine kopyalanıyor..."
sudo cp deb2pisi /usr/bin/deb2pisi
sudo chmod +x /usr/bin/deb2pisi

# 3. Masaüstü Dosyası Oluşturma (Opsiyonel ama şık durur)
echo "[3/3] Menü kısayolu oluşturuluyor..."
cat <<EOF > deb2pisi.desktop
[Desktop Entry]
Name=deb2pisi
Comment=Debian paketlerini Pisi formatına dönüştürür
Exec=/usr/bin/deb2pisi
Icon=/usr/share/pixmaps/deb2pisi.res
Terminal=false
Type=Application
Categories=Development;System;
EOF

sudo mv deb2pisi.desktop /usr/share/applications/
echo "--- Kurulum Tamamlandı! ---"
echo "Terminalden 'deb2pisi' yazarak veya menüden çalıştırabilirsiniz."
