# Deb2Pisi (Lazarus Edition)
Debian (.deb) paketlerini Pisi Linux (.pisi) formatına dönüştüren, akıllı dosya filtreleme ve bağımlılık çeviri motoruna sahip yardımcı araç.

## Özellikler
- 🚀 **Akıllı Filtreleme:** Olmayan `conffiles` dosyalarını otomatik ayıklar, `pspec.xml` hatalarını engeller.
- 📦 **Header & Lib Desteği:** `/usr/include` ve derin kütüphane yollarını (`/*/*`) otomatik kapsar.
- 🛠 **Lazarus & FPC:** Hızlı, hafif ve Pisi Linux üzerinde yerli geliştirme.
- 🔄 **Bağımlılık Çevirisi:** Debian bağımlılıklarını Pisi karşılıklarına (glibc, libext2fs vb.) dönüştürür.

GitHub'daki README.md dosyasına şu "Sistem Gereksinimleri" tablosunu eklemek profesyonel duracaktır:

AraçPaket Adı           (Pisi Linux)                   Kullanım Amacı
ar                        binutils                .deb paketlerini parçalamak
sha1sum                  coreutils                 Arşiv doğrulama (SHA1)
tar / xz / zstd        tar, xz, zstd               Veri arşivlerini açmak
pisi-build                 pisi                    Yeni paketi inşa etmek
Lazarus / FPC         lazarus,fpc,fpcsrc           Kaynak koddan derlemek için
