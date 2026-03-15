# Deb2Pisi (Lazarus Edition)
Debian (.deb) paketlerini Pisi Linux (.pisi) paketine  dönüştüren  yardımcı araç.

## Özellikler
- 📦 **Header & Lib Desteği:** `/usr/include` ve derin kütüphane yollarını (`/*/*`) otomatik kapsar.
- 🛠 **Lazarus & FPC:** Hızlı, hafif ve Pisi Linux üzerinde yerli geliştirme.
- 🔄 **Bağımlılık Çevirisi:** Debian bağımlılıklarını Pisi karşılıklarına (glibc, libext2fs vb.) dönüştürür.
- 🔄 **Eksikler:** config ve conffiles desteği yok.



BAĞIMLILIKLAR

AraçPaket Adı           (Pisi Linux)                   Kullanım Amacı
--------------        ----------------            -----------------------------
ar                        binutils                .deb paketlerini parçalamak
sha1sum                  coreutils                   Arşiv doğrulama (SHA1)
tar / xz / zstd        tar, xz, zstd                 Veri arşivlerini açmak
pisi-build                 pisi                      Yeni paketi inşa etmek
Lazarus / FPC         lazarus,fpclaz,fpcsrc        Kaynak koddan derlemek için..
